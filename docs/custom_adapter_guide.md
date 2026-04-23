# Custom Adapter Guide

This guide will walk you through creating a custom network adapter for RxNet Plus. By the end, you'll understand how to integrate any HTTP client library with RxNet.

## Table of Contents

1. [When to Create a Custom Adapter](#when-to-create-a-custom-adapter)
2. [Understanding the NetworkAdapter Interface](#understanding-the-networkadapter-interface)
3. [Step-by-Step Example: GraphQL Adapter](#step-by-step-example-graphql-adapter)
4. [Implementing Core Methods](#implementing-core-methods)
5. [Implementing Interceptors](#implementing-interceptors)
6. [Error Handling](#error-handling)
7. [Testing Your Adapter](#testing-your-adapter)
8. [Best Practices](#best-practices)
9. [Common Pitfalls](#common-pitfalls)

---

## When to Create a Custom Adapter

Consider creating a custom adapter when:

- ✅ You need to integrate a specialized HTTP client (e.g., GraphQL, gRPC)
- ✅ You have custom networking requirements not met by DioAdapter or HttpAdapter
- ✅ You want to add custom logging, metrics, or monitoring
- ✅ You need to integrate with a proprietary networking library
- ✅ You want to add custom caching or retry logic at the adapter level

**Don't create a custom adapter if:**
- ❌ You just need to add headers or modify requests (use interceptors instead)
- ❌ You want to change caching behavior (use RxNet's built-in cache modes)
- ❌ DioAdapter or HttpAdapter already meet your needs

---

## Understanding the NetworkAdapter Interface

The `NetworkAdapter` interface defines 8 methods you must implement:

```dart
abstract class NetworkAdapter {
  // Core request method
  Future<AdapterResponse> request(AdapterRequest request);
  
  // File operations
  Future<AdapterResponse> download(AdapterRequest request, String savePath, {ProgressCallback? onProgress});
  Future<AdapterResponse> upload(AdapterRequest request, {ProgressCallback? onProgress});
  
  // Request cancellation
  void cancel(CancelToken token);
  
  // Interceptor management
  void addInterceptor(AdapterInterceptor interceptor);
  void removeInterceptor(AdapterInterceptor interceptor);
  
  // Metadata
  String get name;
  String get version;
}
```

---

## Step-by-Step Example: GraphQL Adapter

Let's create a GraphQL adapter that wraps the `graphql_flutter` package.

### Step 1: Create the Adapter Class

```dart
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:rxnet_plus/src/adapter/network_adapter.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_request.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_response.dart';
import 'package:rxnet_plus/src/adapter/interceptor/adapter_interceptor.dart';
import 'package:rxnet_plus/src/adapter/exceptions/adapter_exception.dart';
import 'package:rxnet_plus/src/adapter/cancel_token.dart';

class GraphQLAdapter implements NetworkAdapter {
  final GraphQLClient _client;
  final List<AdapterInterceptor> _interceptors = [];
  final Map<CancelToken, bool> _cancelTokens = {};

  GraphQLAdapter({required String endpoint}) 
      : _client = GraphQLClient(
          link: HttpLink(endpoint),
          cache: GraphQLCache(),
        );

  @override
  String get name => 'GraphQLAdapter';

  @override
  String get version => '1.0.0';
  
  // We'll implement the other methods next...
}
```

### Step 2: Implement the Request Method

```dart
@override
Future<AdapterResponse> request(AdapterRequest request) async {
  // Execute request interceptors
  var modifiedRequest = request;
  for (final interceptor in _interceptors) {
    final handler = RequestInterceptorHandler();
    await interceptor.onRequest(modifiedRequest, handler);
    
    if (handler.resolvedResponse != null) {
      return handler.resolvedResponse!;
    }
    if (handler.rejectedError != null) {
      throw handler.rejectedError!;
    }
    if (handler.modifiedRequest != null) {
      modifiedRequest = handler.modifiedRequest!;
    }
  }

  try {
    // Check if request was cancelled
    if (modifiedRequest.cancelToken != null && 
        _cancelTokens[modifiedRequest.cancelToken] == true) {
      throw AdapterException.cancel(message: 'Request cancelled');
    }

    // Extract GraphQL query from body
    final query = modifiedRequest.bodyParams['query'] as String?;
    final variables = modifiedRequest.bodyParams['variables'] as Map<String, dynamic>?;
    
    if (query == null) {
      throw AdapterException.unknown(
        message: 'GraphQL query is required in bodyParams["query"]',
      );
    }

    // Determine if it's a query or mutation
    final isMutation = modifiedRequest.method == HttpMethod.post;
    
    // Execute GraphQL operation
    final QueryOptions options = isMutation
        ? MutationOptions(document: gql(query), variables: variables ?? {})
        : QueryOptions(document: gql(query), variables: variables ?? {});
    
    final result = isMutation
        ? await _client.mutate(options as MutationOptions)
        : await _client.query(options);

    // Check for errors
    if (result.hasException) {
      throw _convertException(result.exception!);
    }

    // Build response
    final response = AdapterResponse(
      statusCode: 200,
      statusMessage: 'OK',
      data: result.data,
      headers: {},
      request: modifiedRequest,
    );

    // Execute response interceptors
    var modifiedResponse = response;
    for (final interceptor in _interceptors) {
      final handler = ResponseInterceptorHandler();
      await interceptor.onResponse(modifiedResponse, handler);
      
      if (handler.rejectedError != null) {
        throw handler.rejectedError!;
      }
      if (handler.modifiedResponse != null) {
        modifiedResponse = handler.modifiedResponse!;
      }
    }

    return modifiedResponse;
  } catch (e, stackTrace) {
    // Convert to AdapterException if needed
    final exception = e is AdapterException 
        ? e 
        : _convertException(e, stackTrace);

    // Execute error interceptors
    var modifiedException = exception;
    for (final interceptor in _interceptors) {
      final handler = ErrorInterceptorHandler();
      await interceptor.onError(modifiedException, handler);
      
      if (handler.resolvedResponse != null) {
        return handler.resolvedResponse!;
      }
      if (handler.modifiedError != null) {
        modifiedException = handler.modifiedError!;
      }
    }

    throw modifiedException;
  }
}
```

### Step 3: Implement Download and Upload

For GraphQL, file operations typically use mutations with multipart uploads:

```dart
@override
Future<AdapterResponse> download(
  AdapterRequest request,
  String savePath, {
  ProgressCallback? onProgress,
}) async {
  // GraphQL doesn't typically handle file downloads
  // You might want to delegate to an HTTP client or throw an error
  throw AdapterException.unknown(
    message: 'File download not supported by GraphQL adapter. '
        'Use DioAdapter or HttpAdapter for file downloads.',
  );
}

@override
Future<AdapterResponse> upload(
  AdapterRequest request, {
  ProgressCallback? onProgress,
}) async {
  // For file uploads, you'd typically use a multipart mutation
  // This is a simplified example
  try {
    final mutation = request.bodyParams['mutation'] as String?;
    final variables = request.bodyParams['variables'] as Map<String, dynamic>?;
    
    if (mutation == null) {
      throw AdapterException.unknown(
        message: 'GraphQL mutation is required for uploads',
      );
    }

    final options = MutationOptions(
      document: gql(mutation),
      variables: variables ?? {},
    );
    
    final result = await _client.mutate(options);

    if (result.hasException) {
      throw _convertException(result.exception!);
    }

    return AdapterResponse(
      statusCode: 200,
      statusMessage: 'OK',
      data: result.data,
      headers: {},
      request: request,
    );
  } catch (e, stackTrace) {
    throw e is AdapterException ? e : _convertException(e, stackTrace);
  }
}
```

### Step 4: Implement Cancellation

```dart
@override
void cancel(CancelToken token) {
  _cancelTokens[token] = true;
  // Note: graphql_flutter doesn't have built-in cancellation
  // In a real implementation, you might need to track ongoing requests
  // and cancel them manually
}
```

### Step 5: Implement Interceptor Management

```dart
@override
void addInterceptor(AdapterInterceptor interceptor) {
  if (!_interceptors.contains(interceptor)) {
    _interceptors.add(interceptor);
  }
}

@override
void removeInterceptor(AdapterInterceptor interceptor) {
  _interceptors.remove(interceptor);
}
```

### Step 6: Implement Error Conversion

```dart
AdapterException _convertException(dynamic error, [StackTrace? stackTrace]) {
  if (error is OperationException) {
    // Check for network errors
    if (error.linkException != null) {
      final linkException = error.linkException!;
      
      if (linkException is NetworkException) {
        return AdapterException.connectionError(
          message: 'Network error: ${linkException.message}',
          originalError: error,
          stackTrace: stackTrace,
        );
      }
      
      if (linkException is ServerException) {
        return AdapterException.response(
          statusCode: linkException.statusCode ?? 500,
          message: 'Server error: ${linkException.parsedResponse?.errors?.first.message}',
          originalError: error,
          stackTrace: stackTrace,
        );
      }
    }
    
    // Check for GraphQL errors
    if (error.graphqlErrors.isNotEmpty) {
      final firstError = error.graphqlErrors.first;
      return AdapterException.response(
        statusCode: 400,
        message: 'GraphQL error: ${firstError.message}',
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }
  
  return AdapterException.unknown(
    message: error.toString(),
    originalError: error,
    stackTrace: stackTrace,
  );
}
```

---

## Implementing Core Methods

### Request Method Best Practices

1. **Always execute interceptors** in the correct order:
   - Request interceptors (before sending)
   - Response interceptors (after receiving)
   - Error interceptors (on error)

2. **Handle cancellation** by checking the cancel token before and during the request

3. **Convert all exceptions** to `AdapterException` for consistency

4. **Preserve request context** by including the original request in the response

### Download Method Best Practices

1. **Stream the response** to avoid loading large files into memory
2. **Call progress callback** regularly to update UI
3. **Handle partial downloads** for resume support
4. **Validate file path** before starting download

Example:

```dart
@override
Future<AdapterResponse> download(
  AdapterRequest request,
  String savePath, {
  ProgressCallback? onProgress,
}) async {
  final file = File(savePath);
  
  // Ensure directory exists
  await file.parent.create(recursive: true);
  
  // Make request and stream to file
  final response = await _httpClient.send(
    http.Request('GET', Uri.parse(request.buildFullUrl())),
  );
  
  final contentLength = response.contentLength ?? 0;
  int bytesReceived = 0;
  
  final sink = file.openWrite();
  
  try {
    await for (final chunk in response.stream) {
      sink.add(chunk);
      bytesReceived += chunk.length;
      
      // Call progress callback
      if (onProgress != null && contentLength > 0) {
        onProgress(bytesReceived, contentLength);
      }
    }
    
    await sink.flush();
    await sink.close();
    
    return AdapterResponse(
      statusCode: response.statusCode,
      data: savePath,
      headers: _convertHeaders(response.headers),
      request: request,
    );
  } catch (e, stackTrace) {
    await sink.close();
    throw _convertException(e, stackTrace);
  }
}
```

---

## Implementing Interceptors

Interceptors allow users to modify requests, responses, and errors. Your adapter must:

1. **Store interceptors** in a list
2. **Execute them in order** for requests and responses
3. **Handle all handler methods**: `next()`, `reject()`, `resolve()`

Example interceptor execution:

```dart
Future<AdapterResponse> _executeRequestInterceptors(
  AdapterRequest request,
) async {
  var currentRequest = request;
  
  for (final interceptor in _interceptors) {
    final handler = RequestInterceptorHandler();
    await interceptor.onRequest(currentRequest, handler);
    
    // Check if interceptor resolved with a response
    if (handler.resolvedResponse != null) {
      return handler.resolvedResponse!;
    }
    
    // Check if interceptor rejected with an error
    if (handler.rejectedError != null) {
      throw handler.rejectedError!;
    }
    
    // Use modified request if provided
    if (handler.modifiedRequest != null) {
      currentRequest = handler.modifiedRequest!;
    }
  }
  
  return currentRequest;
}
```

---

## Error Handling

### Converting Errors to AdapterException

Always convert library-specific errors to `AdapterException`:

```dart
AdapterException _convertException(dynamic error, [StackTrace? stackTrace]) {
  // Timeout errors
  if (error is TimeoutException) {
    return AdapterException.receiveTimeout(
      message: 'Request timeout: ${error.message}',
      originalError: error,
      stackTrace: stackTrace,
    );
  }
  
  // Network errors
  if (error is SocketException) {
    return AdapterException.connectionError(
      message: 'Connection error: ${error.message}',
      originalError: error,
      stackTrace: stackTrace,
    );
  }
  
  // HTTP errors
  if (error is HttpException) {
    return AdapterException.response(
      statusCode: 500,
      message: 'HTTP error: ${error.message}',
      originalError: error,
      stackTrace: stackTrace,
    );
  }
  
  // Unknown errors
  return AdapterException.unknown(
    message: error.toString(),
    originalError: error,
    stackTrace: stackTrace,
  );
}
```

### Error Types

Use the appropriate `AdapterExceptionType`:

- `connectTimeout`: Connection couldn't be established
- `sendTimeout`: Data couldn't be sent
- `receiveTimeout`: No response received
- `response`: HTTP error (4xx, 5xx)
- `cancel`: Request was cancelled
- `connectionError`: Network unavailable
- `unknown`: Other errors

---

## Testing Your Adapter

### Unit Tests

Test each method independently:

```dart
void main() {
  group('GraphQLAdapter', () {
    late GraphQLAdapter adapter;
    
    setUp(() {
      adapter = GraphQLAdapter(endpoint: 'https://api.example.com/graphql');
    });
    
    test('should execute query successfully', () async {
      final request = AdapterRequest(
        baseUrl: '',
        path: '',
        method: HttpMethod.get,
        bodyParams: {
          'query': '{ user(id: "123") { name email } }',
        },
      );
      
      final response = await adapter.request(request);
      
      expect(response.statusCode, 200);
      expect(response.data, isNotNull);
    });
    
    test('should handle GraphQL errors', () async {
      final request = AdapterRequest(
        baseUrl: '',
        path: '',
        method: HttpMethod.get,
        bodyParams: {
          'query': '{ invalidQuery }',
        },
      );
      
      expect(
        () => adapter.request(request),
        throwsA(isA<AdapterException>()),
      );
    });
    
    test('should execute interceptors', () async {
      var interceptorCalled = false;
      
      adapter.addInterceptor(TestInterceptor(() {
        interceptorCalled = true;
      }));
      
      final request = AdapterRequest(
        baseUrl: '',
        path: '',
        method: HttpMethod.get,
        bodyParams: {'query': '{ test }'},
      );
      
      await adapter.request(request);
      
      expect(interceptorCalled, true);
    });
  });
}
```

### Integration Tests

Test with real network calls:

```dart
test('should work with RxNet', () async {
  final adapter = GraphQLAdapter(
    endpoint: 'https://countries.trevorblades.com/',
  );
  
  final rxNet = RxNet.create();
  await rxNet.initNet(
    baseUrl: '',
    adapter: adapter,
  );
  
  final response = await rxNet.getRequest()
      .setParam('query', '{ countries { code name } }')
      .request();
  
  expect(response.isSuccess, true);
  expect(response.value, isNotNull);
});
```

---

## Best Practices

### 1. Follow the Single Responsibility Principle

Each method should do one thing well. Don't mix concerns.

### 2. Preserve Request Context

Always include the original request in the response:

```dart
return AdapterResponse(
  statusCode: 200,
  data: responseData,
  headers: responseHeaders,
  request: request, // ✅ Include original request
);
```

### 3. Handle All Error Cases

Don't let exceptions escape without converting them to `AdapterException`.

### 4. Support Cancellation

Even if the underlying library doesn't support cancellation, track cancel tokens and check them before making requests.

### 5. Document Your Adapter

Add dartdoc comments explaining:
- What library it wraps
- Any special requirements
- Limitations or unsupported features

Example:

```dart
/// GraphQL adapter for RxNet Plus.
///
/// This adapter wraps the `graphql_flutter` package and allows RxNet
/// to make GraphQL queries and mutations.
///
/// ## Limitations
///
/// - File downloads are not supported (use DioAdapter instead)
/// - Subscriptions are not yet implemented
/// - Cancellation is limited due to graphql_flutter constraints
///
/// ## Usage
///
/// ```dart
/// final adapter = GraphQLAdapter(
///   endpoint: 'https://api.example.com/graphql',
/// );
///
/// await RxNet.init(baseUrl: '', adapter: adapter);
///
/// final response = await RxNet.get()
///     .setParam('query', '{ users { id name } }')
///     .request();
/// ```
class GraphQLAdapter implements NetworkAdapter {
  // ...
}
```

### 6. Provide Configuration Options

Allow users to configure your adapter:

```dart
class GraphQLAdapter implements NetworkAdapter {
  final GraphQLClient _client;
  final Duration defaultTimeout;
  final bool enableCache;
  
  GraphQLAdapter({
    required String endpoint,
    this.defaultTimeout = const Duration(seconds: 30),
    this.enableCache = true,
    Map<String, String>? defaultHeaders,
  }) : _client = GraphQLClient(
    link: HttpLink(
      endpoint,
      defaultHeaders: defaultHeaders,
    ),
    cache: enableCache ? GraphQLCache() : GraphQLCache(store: InMemoryStore()),
  );
}
```

---

## Common Pitfalls

### 1. Forgetting to Execute Interceptors

❌ **Wrong:**
```dart
Future<AdapterResponse> request(AdapterRequest request) async {
  // Directly make request without interceptors
  final response = await _client.get(request.buildFullUrl());
  return _convertResponse(response);
}
```

✅ **Correct:**
```dart
Future<AdapterResponse> request(AdapterRequest request) async {
  // Execute request interceptors first
  var modifiedRequest = await _executeRequestInterceptors(request);
  
  final response = await _client.get(modifiedRequest.buildFullUrl());
  
  // Execute response interceptors
  return await _executeResponseInterceptors(_convertResponse(response));
}
```

### 2. Not Converting Exceptions

❌ **Wrong:**
```dart
Future<AdapterResponse> request(AdapterRequest request) async {
  // Let library exceptions escape
  final response = await _client.get(request.buildFullUrl());
  return _convertResponse(response);
}
```

✅ **Correct:**
```dart
Future<AdapterResponse> request(AdapterRequest request) async {
  try {
    final response = await _client.get(request.buildFullUrl());
    return _convertResponse(response);
  } catch (e, stackTrace) {
    throw _convertException(e, stackTrace);
  }
}
```

### 3. Ignoring Cancel Tokens

❌ **Wrong:**
```dart
void cancel(CancelToken token) {
  // Do nothing
}
```

✅ **Correct:**
```dart
final Map<CancelToken, bool> _cancelTokens = {};

void cancel(CancelToken token) {
  _cancelTokens[token] = true;
  // Also cancel any ongoing requests with this token
}

Future<AdapterResponse> request(AdapterRequest request) async {
  if (request.cancelToken != null && 
      _cancelTokens[request.cancelToken] == true) {
    throw AdapterException.cancel();
  }
  // ... rest of implementation
}
```

### 4. Not Handling Progress Callbacks

❌ **Wrong:**
```dart
Future<AdapterResponse> download(
  AdapterRequest request,
  String savePath, {
  ProgressCallback? onProgress,
}) async {
  // Ignore onProgress callback
  await _client.download(request.buildFullUrl(), savePath);
  return AdapterResponse(/* ... */);
}
```

✅ **Correct:**
```dart
Future<AdapterResponse> download(
  AdapterRequest request,
  String savePath, {
  ProgressCallback? onProgress,
}) async {
  int received = 0;
  final total = await _getContentLength(request);
  
  await _client.download(
    request.buildFullUrl(),
    savePath,
    onReceiveProgress: (count, _) {
      received = count;
      onProgress?.call(received, total);
    },
  );
  
  return AdapterResponse(/* ... */);
}
```

### 5. Mutating Request Objects

❌ **Wrong:**
```dart
Future<AdapterResponse> request(AdapterRequest request) async {
  // Modifying the original request
  request.headers['Authorization'] = 'Bearer token';
  // ...
}
```

✅ **Correct:**
```dart
Future<AdapterResponse> request(AdapterRequest request) async {
  // Create a new request with modifications
  final modifiedRequest = request.copyWith(
    headers: {...request.headers, 'Authorization': 'Bearer token'},
  );
  // ...
}
```

---

## Complete Example

Here's the complete GraphQL adapter implementation:

```dart
// See the full implementation in the examples above
```

---

## Next Steps

1. **Test thoroughly**: Write comprehensive unit and integration tests
2. **Document well**: Add dartdoc comments and usage examples
3. **Share with the community**: Consider publishing your adapter as a package
4. **Get feedback**: Ask others to review your implementation

## Resources

- [NetworkAdapter API Documentation](../lib/src/adapter/network_adapter.dart)
- [DioAdapter Source Code](../lib/src/adapter/implementations/dio_adapter.dart)
- [HttpAdapter Source Code](../lib/src/adapter/implementations/http_adapter.dart)
- [MockAdapter Source Code](../lib/src/adapter/implementations/mock_adapter.dart)

---

**Questions or need help?** Open an issue on GitHub or join our community discussions!
