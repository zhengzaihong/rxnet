import 'dart:async';
import 'package:rxnet_plus/src/adapter/cancel_token.dart';
import 'package:rxnet_plus/src/adapter/exceptions/adapter_exception.dart';
import '../fun/fun_apply.dart';
import '../type/sources_type.dart';
import 'zip_request.dart';
import 'zip_request_error.dart';
import 'zip_results.dart';
import 'request_state.dart';

/// 创建一个内部成功回调函数来完成Completer。
/// Creates an internal success callback that completes the Completer.
Success<T> createInternalSuccess<T>(
  ZipRequest<T> zipRequest,
  Completer<T> completer,
) {
  return (T data, SourcesType source) {
    // Complete the Completer if not already completed
    if (!completer.isCompleted) {
      completer.complete(data);
    }
  };
}

/// Creates an internal failure callback that completes the Completer with error.
/// Captures stack trace for better error debugging.
Failure createInternalFailure<T>(
  ZipRequest<T> zipRequest,
  Completer<T> completer,
  int index,
) {
  return (dynamic error) {
    // Complete the Completer with error if not already completed
    if (!completer.isCompleted) {
      // Capture stack trace if available
      final stackTrace = error is Error ? error.stackTrace : StackTrace.current;
      
      completer.completeError(
        ZipRequestError(
          index: index,
          tag: zipRequest.tag,
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  };
}

/// Creates an internal completed callback (currently no-op).
/// Kept for future extensibility.
Completed createInternalCompleted<T>(
  ZipRequest<T> zipRequest,
) {
  return () {
    // No-op: Reserved for future use
  };
}

/// Invokes a request method with internal callbacks and user parameters merged.
/// Internal callbacks take precedence over user parameters.
void invokeRequest<T>(
  ZipRequest<T> zipRequest,
  Success<T> internalSuccess,
  Failure internalFailure,
  Completed internalCompleted,
) {
  // If params are provided, use Function.apply
  if (zipRequest.params != null) {
    // Merge user parameters with internal callbacks
    final namedArgs = <Symbol, dynamic>{
      #success: internalSuccess,
      #failure: internalFailure,
      #completed: internalCompleted,
    };
    
    // Add user parameters (internal callbacks take precedence)
    zipRequest.params!.forEach((key, value) {
      // Only add if not already present (callbacks have priority)
      if (!namedArgs.containsKey(key)) {
        namedArgs[key] = value;
      }
    });
    
    // Invoke the request method
    Function.apply(zipRequest.request, [], namedArgs);
  } else {
    // No params, invoke as a closure with named parameters
    // Use Function.apply for consistent behavior
    Function.apply(zipRequest.request, [], {
      #success: internalSuccess,
      #failure: internalFailure,
      #completed: internalCompleted,
    });
  }
}

/// Validates the request list and builds the tag-to-index map.
/// 
/// Throws ArgumentError if:
/// - Request list is empty
/// - Duplicate tags are found
Map<String, int> _validateAndBuildTagMap(List<ZipRequest> requests) {
  // Validate non-empty request list
  if (requests.isEmpty) {
    throw ArgumentError('Request list cannot be empty');
  }
  
  // Build tag-to-index map and check for duplicates
  final tagIndexMap = <String, int>{};
  
  for (var i = 0; i < requests.length; i++) {
    final tag = requests[i].tag;
    if (tag != null) {
      if (tagIndexMap.containsKey(tag)) {
        throw ArgumentError('Duplicate tag found: "$tag"');
      }
      tagIndexMap[tag] = i;
    }
  }
  
  return tagIndexMap;
}

/// Creates RequestState instances for each request.
/// 
/// Uses a factory function to maintain type safety for each request.
/// Although stored in a non-generic list, individual RequestState instances
/// preserve their generic type parameter T.
List<RequestState> _initializeRequestStates(List<ZipRequest> requests) {
  final states = <RequestState>[];
  
  for (var i = 0; i < requests.length; i++) {
    // Use factory function to create properly typed RequestState
    states.add(_createTypedRequestState(requests[i], i));
  }
  
  return states;
}

/// Helper function to create a typed RequestState instance.
/// This preserves type safety by matching the generic type of ZipRequest<T>.
RequestState _createTypedRequestState<T>(ZipRequest<T> request, int index) {
  return RequestState<T>(
    request: request,
    completer: Completer<T>(),
    index: index,
  );
}

/// Registers cancellation callback with CancelToken.
/// When cancelled, all pending Completers are completed with cancellation error.
void _registerCancellation(
  CancelToken? cancelToken,
  List<RequestState> states,
) {
  if (cancelToken == null) return;
  
  cancelToken.whenCancel((reason) {
    for (final state in states) {
      if (!state.isCompleted) {
        state.completer.completeError(
          AdapterException(
            type: AdapterExceptionType.cancel,
            message: reason ?? 'Request cancelled',
          ),
        );
      }
    }
  });
}

/// Executes all requests in parallel by creating internal callbacks
/// and invoking request methods.
void _executeRequests(List<RequestState> states) {
  for (final state in states) {
    // Create internal callbacks
    final internalSuccess = createInternalSuccess(
      state.request,
      state.completer,
    );
    
    final internalFailure = createInternalFailure(
      state.request,
      state.completer,
      state.index,
    );
    
    final internalCompleted = createInternalCompleted(
      state.request,
    );
    
    // Invoke the request method
    invokeRequest(
      state.request,
      internalSuccess,
      internalFailure,
      internalCompleted,
    );
  }
}

/// Waits for all requests to complete with eager error mode.
/// Throws immediately on first error.
/// 
Future<List<dynamic>> _waitWithEagerError(List<RequestState> states) async {
  // Use Future.wait with eagerError: true
  final results = await Future.wait(
    states.map((s) => s.completer.future),
    eagerError: true,
  );
  
  return results;
}

/// Waits for all requests to complete with partial success mode.
/// Collects both results and errors.
/// 
/// Uses Future.wait with error wrapping to truly wait for all futures 
/// concurrently, rather than sequentially awaiting each one.
Future<(List<dynamic>, Map<int, dynamic>)> _waitWithPartialSuccess(
  List<RequestState> states,
) async {
  // Transform each future to never throw, capturing success/failure state
  // This allows Future.wait to complete all requests concurrently
  final settledFutures = states.asMap().entries.map((entry) {
    final index = entry.key;
    final state = entry.value;
    
    // Wrap future to capture both success and error cases
    return state.completer.future
        .then<(int, bool, dynamic, dynamic)>(
          (value) => (index, true, value, null),
        )
        .catchError((error) => (index, false, null, error));
  });
  
  final settled = await Future.wait(settledFutures);
  
  // Separate successful results from errors
  final results = List<dynamic>.filled(states.length, null);
  final errors = <int, dynamic>{};
  
  for (final (index, success, value, error) in settled) {
    if (success) {
      results[index] = value;
    } else {
      errors[index] = error;
    }
  }
  
  return (results, errors);
}

/// Main function to execute multiple callback-based requests concurrently.
/// 
/// Returns a Future that completes when all requests finish.
/// Total execution time equals the longest individual request.
/// 
/// Parameters:
/// - [requests]: List of ZipRequest instances to execute
/// - [eagerError]: If true, fail immediately on first error (default: true)
/// - [cancelToken]: Optional token to cancel all requests
/// - [timeout]: Optional timeout duration for all requests (not per-request timeout)
/// 
/// Returns: ZipResults containing all results
/// 
/// Example:
/// ```dart
/// final results = await zipRequest([
///   ZipRequest<UserInfo>(request: getUserAsync, tag: 'user'),
///   ZipRequest<List<Product>>(request: getProductsAsync, tag: 'products'),
/// ], timeout: Duration(seconds: 30));
/// 
/// final user = results.getRequestByTag<UserInfo>('user');
/// final products = results.getRequestByTag<List<Product>>('products');
/// ```
Future<ZipResults> zipRequest(
  List<ZipRequest> requests, {
  bool eagerError = true,
  CancelToken? cancelToken,
  Duration? timeout,
}) async {
  //  Validation Phase
  final tagIndexMap = _validateAndBuildTagMap(requests);
  
  //  Initialization Phase
  final states = _initializeRequestStates(requests);
  _registerCancellation(cancelToken, states);
  
  //  Execution Phase
  _executeRequests(states);
  
  // Waiting Phase
  Future<ZipResults> executeFuture() async {
    if (eagerError) {
      // Eager error mode: throw on first error
      final results = await _waitWithEagerError(states);
      
      // Result Aggregation Phase
      return ZipResults(results, tagIndexMap);
    } else {
      // Partial success mode: collect all results and errors
      final (results, errors) = await _waitWithPartialSuccess(states);
      
      // Result Aggregation Phase
      return ZipResults(results, tagIndexMap, errors);
    }
  }
  
  // Apply timeout if specified
  if (timeout != null) {
    return executeFuture().timeout(
      timeout,
      onTimeout: () {
        // Cancel all pending requests on timeout
        for (final state in states) {
          if (!state.isCompleted) {
            state.completer.completeError(
              TimeoutException(
                'ZipRequest timed out after ${timeout.inSeconds} seconds',
                timeout,
              ),
            );
          }
        }
        throw TimeoutException(
          'ZipRequest timed out after ${timeout.inSeconds} seconds',
          timeout,
        );
      },
    );
  }
  
  return executeFuture();
}
