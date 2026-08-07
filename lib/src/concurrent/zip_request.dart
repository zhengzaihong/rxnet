import '../fun/fun_apply.dart';
/// author:ZhengZaiHong
/// email:1096877329@qq.com
/// date:2026-05-29 9:46
/// describe: 基于回调的请求方法的类型定义
/// Type definition for callback-based request methods.

/// This function type explicitly defines the three callback parameters that
/// RxNet's async methods accept: [success], [failure], and [completed].
///
/// ## Purpose
///
/// Provides IDE autocomplete and type hints when constructing [ZipRequest] closures,
/// making it clear which callbacks are available and their signatures.
///
/// ## Usage Example
///
/// ```dart
/// // IDE will autocomplete {success, failure, completed} parameters
/// ZipRequestFunction<UserInfo> myRequest = ({success, failure, completed}) {
///   getUserAsync(
///     userId: '123',
///     success: success,    // Type: Success<UserInfo>?
///     failure: failure,    // Type: Failure?
///     completed: completed, // Type: Completed?
///   );
/// };
///
/// // Use in ZipRequest
/// ZipRequest<UserInfo>(
///   request: myRequest,
///   tag: 'user',
/// )
/// ```
///
/// ## Parameters
///
/// - [success]: Called when request succeeds with data of type [T]
/// - [failure]: Called when request fails with error information
/// - [completed]: Called when request finishes (success or failure)
///
/// All parameters are optional to support various callback patterns.
typedef ZipRequestFunction<T> = void Function({
  Success<T>? success,
  Failure? failure,
  Completed? completed,
});

/// Wrapper for callback-based request methods with type information.
///
/// [ZipRequest] enables concurrent execution of callback-style network requests
/// by capturing the result type [T] and providing automatic callback injection.
/// It bridges the gap between callback-based APIs and concurrent execution patterns.
///
/// ## Why ZipRequest?
///
/// RxNet's callback-based `execute()` methods cannot be directly composed with
/// `Future.wait()`. [ZipRequest] solves this by:
/// - Wrapping callback methods with type information
/// - Automatically injecting internal callbacks to capture results
/// - Enabling parallel execution via [zipRequest]
/// - Preserving type safety throughout the process
///
/// ## Usage Patterns
///
/// ### Pattern 1: Closure Wrapper (Recommended)
///
/// Most flexible and type-safe. Explicitly pass all parameters:
///
/// ```dart
/// ZipRequest<UserInfo>(
///   request: ({success, failure, completed}) {
///     getUserAsync(
///       userId: '123',
///       phone: '13800138000',
///       success: success,
///       failure: failure,
///       completed: completed,
///     );
///   },
///   tag: 'user',
/// )
/// ```
///
/// ### Pattern 2: withParams Factory (Simplest)
///
/// Concise syntax for simple cases:
///
/// ```dart
/// ZipRequest.withParams<UserInfo>(
///   getUserAsync,
///   {'userId': '123', 'phone': '13800138000'},
///   tag: 'user',
/// )
/// ```
///
/// ### Pattern 3: Symbol Params (Advanced)
///
/// For dynamic invocation scenarios:
///
/// ```dart
/// ZipRequest<UserInfo>(
///   request: getUserAsync,
///   params: {#userId: '123', #phone: '13800138000'},
///   tag: 'user',
/// )
/// ```
///
/// ## Custom Callbacks
///
/// You can provide custom callbacks that will be invoked after internal callbacks:
///
/// ```dart
/// ZipRequest<UserInfo>(
///   request: ({success, failure, completed}) {
///     getUserAsync(
///       userId: '123',
///       success: success,
///       failure: failure,
///       completed: completed,
///     );
///   },
///   tag: 'user',
///   success: (data, source) {
///     print('User loaded from $source');
///   },
///   failure: (error) {
///     print('Failed to load user: $error');
///   },
///   completed: () {
///     print('Request completed');
///   },
/// )
/// ```
///
/// ## Type Safety
///
/// The generic type parameter [T] ensures compile-time type checking:
///
/// ```dart
/// // Correct: Type matches method return type
/// ZipRequest<UserInfo>(request: getUserAsync, tag: 'user')
///
/// // Compile error: Type mismatch
/// ZipRequest<String>(request: getUserAsync, tag: 'user')
/// ```
///
/// See also:
/// - [zipRequest] for executing concurrent requests
/// - [ZipResults] for accessing aggregated results
/// - [withParams] factory for simplified parameter passing
class ZipRequest<T> {
  /// Optional tag for named result access in [ZipResults].
  ///
  /// Tags enable accessing results by name instead of index:
  /// ```dart
  /// final user = results.getRequestByTag<UserInfo>('user');
  /// ```
  ///
  /// Tags must be unique within a single [zipRequest] call.
  final String? tag;
  
  /// The callback-based request method reference or closure.
  ///
  /// This can be either:
  /// - **Method reference**: Direct reference to a callback-based method
  /// - **Closure**: Lambda that wraps the method call with parameters
  ///
  /// The closure pattern is recommended for most cases as it provides
  /// better type safety and clarity.
  ///
  /// ## Type Signature
  ///
  /// When using the closure pattern, the function signature is:
  /// ```dart
  /// void Function({
  ///   Success<T>? success,
  ///   Failure? failure,
  ///   Completed? completed,
  /// })
  /// ```
  ///
  /// ## Example with closure (IDE will autocomplete parameters):
  /// ```dart
  /// request: ({success, failure, completed}) {
  ///   getUserAsync(
  ///     userId: '123',
  ///     success: success,      // Success<UserInfo>?
  ///     failure: failure,      // Failure?
  ///     completed: completed,  // Completed?
  ///   );
  /// }
  /// ```
  ///
  /// ## Callback Parameter Details
  ///
  /// - **success**: `void Function(T data, SourcesType source)`
  ///   - Called when request succeeds
  ///   - `data`: The result data of type [T]
  ///   - `source`: Where data came from (cache, network, etc.)
  ///
  /// - **failure**: `void Function(dynamic error)`
  ///   - Called when request fails
  ///   - `error`: Error information from the failed request
  ///
  /// - **completed**: `void Function()`
  ///   - Called when request finishes (regardless of success/failure)
  ///   - Useful for cleanup or hiding loading indicators
  final ZipRequestFunction<T> request;
  
  /// Optional parameters to pass to the request method.
  ///
  /// Used with the method reference pattern. Keys should be parameter names
  /// as [Symbol]s (e.g., `#userId`, `#phone`), and values are the parameter values.
  ///
  /// **Important**: Internal callbacks (`success`, `failure`, `completed`) are
  /// automatically injected and take precedence over any callbacks in this map.
  ///
  /// Example:
  /// ```dart
  /// ZipRequest<UserInfo>(
  ///   request: getUserAsync,
  ///   params: {
  ///     #userId: '123',
  ///     #phone: '13800138000',
  ///   },
  ///   tag: 'user',
  /// )
  /// ```
  ///
  /// Note: The closure pattern is generally preferred over this approach.
  final Map<Symbol, dynamic>? params;
  
  /// Creates a [ZipRequest] with explicit type parameter [T].
  ///
  /// This is the primary constructor for creating concurrent request wrappers.
  /// The type parameter [T] must match the result type of the wrapped method.
  ///
  /// ## Pattern 1: Closure Wrapper (Recommended)
  ///
  /// Provides full control and type safety:
  ///
  /// ```dart
  /// ZipRequest<UserInfo>(
  ///   request: ({success, failure, completed}) {
  ///     getUserAsync(
  ///       userId: '123',
  ///       phone: '13800138000',
  ///       success: success,
  ///       failure: failure,
  ///       completed: completed,
  ///     );
  ///   },
  ///   tag: 'user',
  /// )
  /// ```
  ///
  /// ## Pattern 2: Method Reference with Params
  ///
  /// Uses [Symbol] keys for parameters:
  ///
  /// ```dart
  /// ZipRequest<UserInfo>(
  ///   request: getUserAsync,
  ///   params: {#userId: '123', #phone: '13800138000'},
  ///   tag: 'user',
  /// )
  /// ```
  ///
  /// ## Adding Custom Logic (Logging, Analytics, etc.)
  ///
  /// To add logging or other side effects, wrap the callbacks in the request closure:
  ///
  /// ```dart
  /// ZipRequest<UserInfo>(
  ///   request: ({success, failure, completed}) {
  ///     getUserAsync(
  ///       userId: '123',
  ///       success: (data, source) {
  ///         // Custom logic: logging, analytics, etc.
  ///         print('User loaded from $source');
  ///         analytics.track('user_loaded');
  ///         
  ///         // Forward to zipRequest's internal handler
  ///         success?.call(data, source);
  ///       },
  ///       failure: (error) {
  ///         print('Failed: $error');
  ///         analytics.trackError(error);
  ///         failure?.call(error);
  ///       },
  ///       completed: () {
  ///         print('Request completed');
  ///         completed?.call();
  ///       },
  ///     );
  ///   },
  ///   tag: 'user',
  /// )
  /// ```
  ///
  /// Parameters:
  /// - [request]: The callback-based method or closure
  /// - [tag]: Optional identifier for named result access
  /// - [params]: Optional parameters (for method reference pattern)
  ///
  /// See also:
  /// - [withParams] for simplified parameter passing
  /// - [from] for type inference from method signature
  ZipRequest({
    required this.request,
    this.tag,
    this.params,
  });
  
  /// Factory method for type inference from method signature.
  ///
  /// This factory is useful when the method signature clearly defines the result type,
  /// allowing Dart to infer the generic type parameter automatically.
  ///
  /// Example:
  /// ```dart
  /// ZipRequest.from(
  ///   ({success, failure, completed}) {
  ///     getUserAsync(
  ///       userId: '123',
  ///       success: success,
  ///       failure: failure,
  ///       completed: completed,
  ///     );
  ///   },
  ///   tag: 'user',
  /// )
  /// ```
  ///
  /// Parameters:
  /// - [request]: Closure that accepts named callback parameters
  /// - [tag]: Optional identifier for named result access
  /// - [params]: Optional parameters (rarely used with this factory)
  ///
  /// Returns: A [ZipRequest<T>] with inferred type parameter.
  static ZipRequest<T> from<T>(
    ZipRequestFunction<T> request, {
    String? tag,
    Map<Symbol, dynamic>? params,
  }) {
    return ZipRequest<T>(
      request: request,
      tag: tag,
      params: params,
    );
  }
  
  /// Convenience factory for creating [ZipRequest] with string-keyed parameters.
  ///
  /// This factory provides the simplest syntax for common cases where you need
  /// to pass parameters to a callback-based method. It automatically wraps the
  /// method call in a closure and converts string keys to [Symbol]s.
  ///
  /// Example:
  /// ```dart
  /// ZipRequest.withParams<UserInfo>(
  ///   getUserAsync,
  ///   {'userId': '123', 'phone': '13800138000'},
  ///   tag: 'user',
  /// )
  /// ```
  ///
  /// This is equivalent to the more verbose closure pattern:
  /// ```dart
  /// ZipRequest<UserInfo>(
  ///   request: ({success, failure, completed}) {
  ///     getUserAsync(
  ///       userId: '123',
  ///       phone: '13800138000',
  ///       success: success,
  ///       failure: failure,
  ///       completed: completed,
  ///     );
  ///   },
  ///   tag: 'user',
  /// )
  /// ```
  ///
  /// Parameters:
  /// - [method]: The callback-based method to wrap
  /// - [params]: Map of parameter names to values (string keys)
  /// - [tag]: Optional identifier for named result access
  ///
  /// Returns: A [ZipRequest<T>] that will invoke [method] with the specified parameters.
  ///
  /// Note: The type parameter [T] must be explicitly specified as it cannot be inferred.
  static ZipRequest<T> withParams<T>(
    Function method,
    Map<String, dynamic> params, {
    String? tag,
  }) {
    return ZipRequest<T>(
      request: ({Success<T>? success, Failure? failure, Completed? completed}) {
        final allParams = <Symbol, dynamic>{};
        
        // Add user parameters
        params.forEach((key, value) {
          allParams[Symbol(key)] = value;
        });
        
        // Add callbacks (these take precedence)
        if (success != null) allParams[#success] = success;
        if (failure != null) allParams[#failure] = failure;
        if (completed != null) allParams[#completed] = completed;
        
        Function.apply(method, [], allParams);
      },
      tag: tag,
    );
  }
}
