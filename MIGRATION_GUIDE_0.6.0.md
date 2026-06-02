# Migration Guide: RxNet Plus 0.5.x → 0.6.0

Welcome to RxNet Plus 0.6.0! This version introduces a revolutionary pluggable adapter architecture that decouples RxNet from specific HTTP client libraries, giving you the flexibility to choose the implementation that best fits your needs.

## 📋 Table of Contents

- [What's New](#whats-new)
- [Breaking Changes](#breaking-changes)
- [Migration Steps](#migration-steps)
- [New Features](#new-features)
- [Adapter Selection Guide](#adapter-selection-guide)
- [Interceptor Changes](#interceptor-changes)
- [CancelToken Improvements](#canceltoken-improvements)
- [Common Migration Scenarios](#common-migration-scenarios)
- [FAQ](#faq)

---

## 🎉 What's New

### 1. Pluggable Adapter Architecture

RxNet Plus 0.6.0 introduces a revolutionary adapter system that completely decouples the framework from specific HTTP client libraries:

#### Available Adapters

- **DioAdapter** (Default): Full-featured adapter using Dio
  - Complete HTTP functionality
  - Advanced interceptor support
  - True request cancellation
  - File upload/download with progress
  - Best for production applications

- **HttpAdapter**: Lightweight adapter using the standard `http` package
  - Minimal dependencies
  - Smaller package size
  - Basic HTTP functionality
  - Best for simple applications or when package size matters

- **MockAdapter**: Testing adapter for unit and integration tests
  - No network calls
  - Configurable mock responses
  - Simulate errors and delays
  - Best for testing without real network

- **Custom Adapters**: Create your own by implementing `NetworkAdapter` interface
  - Integrate any HTTP client library
  - Full control over request/response handling
  - Best for special requirements

### 2. Unified Interceptor System

New `AdapterInterceptor` interface that works across all adapters:

```dart
abstract class AdapterInterceptor {
  void onRequest(AdapterRequest request, RequestInterceptorHandler handler);
  void onResponse(AdapterResponse response, ResponseInterceptorHandler handler);
  void onError(AdapterException error, ErrorInterceptorHandler handler);
}
```

**Benefits:**
- Write interceptors once, use with any adapter
- No dependency on Dio-specific types
- Interceptors execute BEFORE the underlying HTTP client (preserves all request information)
- Support for request modification, early response, and error handling

### 3. Improved CancelToken

New standalone `CancelToken` class independent of Dio:

```dart
final cancelToken = CancelToken();

// Cancel with optional reason
cancelToken.cancel('User cancelled');

// Check if cancelled
if (cancelToken.isCancelled) {
  print('Reason: ${cancelToken.cancelReason}');
}

// Register callback
cancelToken.whenCancel((reason) {
  print('Request cancelled: $reason');
});
```

**Note:** DioAdapter provides true cancellation (aborts HTTP connection), while HttpAdapter provides pseudo-cancellation (marks as cancelled but request continues).

### 4. Enum Type Optimization

All enum values now use uppercase for better Dart 3.0+ compliance:

```dart
// ✅ 0.6.0 (Uppercase)
HttpMethod.GET, HttpMethod.POST
ResponseType.JSON, ResponseType.STREAM

// ❌ 0.5.x (Lowercase - still works but deprecated)
HttpMethod.get, HttpMethod.post
ResponseType.json, ResponseType.stream
```

### Key Benefits

✅ **Flexibility**: Choose the HTTP client that best fits your needs
✅ **Testability**: Use MockAdapter for easy unit testing without network calls
✅ **Extensibility**: Create custom adapters for special requirements
✅ **Backward Compatible**: Existing code works without changes (100% compatible!)
✅ **Better Architecture**: Clean separation between framework and HTTP implementation
✅ **Improved Interceptors**: Unified system that preserves all request information

---

## 🚨 Breaking Changes

### None! 🎊

**RxNet Plus 0.6.0 is 100% backward compatible with 0.5.x**

All existing code will continue to work without any modifications. The adapter architecture is implemented internally, and DioAdapter is used by default.

---

## 🔄 Migration Steps

### Step 1: Update Dependencies

Update your `pubspec.yaml`:

```yaml
dependencies:
  rxnet_plus: ^0.6.0  # Update from ^0.5.0
```

Run:
```bash
flutter pub get
```

### Step 2: No Code Changes Required! ✨

Your existing code will work as-is:

```dart
// This code works in both 0.5.x and 0.6.0
await RxNet.init(
  baseUrl: "https://api.example.com",
  baseCacheMode: CacheMode.REQUEST_FAILED_READ_CACHE,
  interceptors: [RxNetLogInterceptor()],
);

final response = await RxNet.get()
    .setPath('/users/123')
    .request();
```

### Step 3: (Optional) Explore New Features

If you want to use the new adapter features, see the [New Features](#new-features) section below.

---

## 🆕 New Features

### 1. Explicit Adapter Selection

You can now explicitly choose which adapter to use:

#### Using DioAdapter (Default)

```dart
import 'package:rxnet_plus/adapters/dio_adapter.dart';

final adapter = DioAdapter();
await RxNet.init(
  baseUrl: 'https://api.example.com',
  adapter: adapter,  // Explicitly specify adapter
);
```

#### Using HttpAdapter (Lightweight)

```dart
import 'package:rxnet_plus/adapters/http_adapter.dart';

final adapter = HttpAdapter();
await RxNet.init(
  baseUrl: 'https://api.example.com',
  adapter: adapter,
);
```

#### Using MockAdapter (Testing)

```dart
import 'package:rxnet_plus/adapters/mock_adapter.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_response.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_request.dart';

void main() {
  test('should fetch user data', () async {
    final mockAdapter = MockAdapter();
    
    // Configure mock response
    mockAdapter.setMockResponse(
      '/users/123',
      AdapterResponse(
        statusCode: 200,
        data: {'id': 123, 'name': 'John'},
        headers: {},
        request: AdapterRequest(
          baseUrl: 'https://api.example.com',
          path: '/users/123',
          method: HttpMethod.get,
        ),
      ),
    );
    
    await RxNet.init(
      baseUrl: 'https://api.example.com',
      adapter: mockAdapter,
    );
    
    final result = await RxNet.get()
        .setPath('/users/123')
        .request();
    
    expect(result.isSuccess, true);
    expect(result.value['name'], 'John');
  });
}
```

### 2. Multiple Network Instances with Different Adapters

```dart
// Instance 1: Using DioAdapter for main API
final mainApi = RxNet.create();
await mainApi.initNet(
  baseUrl: "https://api.example.com",
  adapter: DioAdapter(),
);

// Instance 2: Using HttpAdapter for lightweight requests
final lightApi = RxNet.create();
await lightApi.initNet(
  baseUrl: "https://cdn.example.com",
  adapter: HttpAdapter(),
);

// Use different instances
final userData = await mainApi.getRequest()
    .setPath('/users/123')
    .request();

final imageData = await lightApi.getRequest()
    .setPath('/images/avatar.jpg')
    .request();
```

### 3. Custom Adapters

Create your own adapter for special requirements:

```dart
import 'package:rxnet_plus/src/adapter/network_adapter.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_request.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_response.dart';

class MyCustomAdapter implements NetworkAdapter {
  @override
  String get name => 'MyCustomAdapter';
  
  @override
  String get version => '1.0.0';
  
  @override
  Future<AdapterResponse> request(AdapterRequest request) async {
    // Implement your custom HTTP logic
    // ...
  }
  
  // Implement other required methods...
}

// Use your custom adapter
await RxNet.init(
  baseUrl: 'https://api.example.com',
  adapter: MyCustomAdapter(),
);
```

---

## 📊 Adapter Selection Guide

### When to Use DioAdapter (Default)

✅ **Use DioAdapter when:**
- You need full-featured HTTP client capabilities
- You want the best performance and features
- You're building a production application
- You need advanced features like interceptors, cancellation, etc.

**Requirements:**
```yaml
dependencies:
  dio: ^5.8.0+1
```

### When to Use HttpAdapter

✅ **Use HttpAdapter when:**
- You want to minimize dependencies
- You only need basic HTTP functionality
- Package size is a concern
- You're building a simple application

**Requirements:**
```yaml
dependencies:
  http: ^1.2.0
```

### When to Use MockAdapter

✅ **Use MockAdapter when:**
- You're writing unit tests
- You're writing integration tests
- You want to test without network calls
- You need to simulate specific scenarios

**Requirements:** None (no external dependencies)

### Comparison Table

| Feature | DioAdapter | HttpAdapter | MockAdapter |
|---------|------------|-------------|-------------|
| Package size | Larger | Smaller | Minimal |
| Features | Full-featured | Basic | Testing only |
| Performance | Excellent | Good | N/A |
| Interceptors | ✅ Yes | ✅ Yes | ✅ Yes |
| File upload/download | ✅ Yes | ✅ Yes | ✅ Simulated |
| Progress callbacks | ✅ Yes | ✅ Yes | ✅ Simulated |
| Request cancellation | ✅ Yes | ✅ Yes | ✅ Simulated |
| Advanced features | ✅ Extensive | ⚠️ Limited | ❌ No |
| Testing support | ✅ Yes | ✅ Yes | ✅ Excellent |

---

## 🔧 Interceptor Changes

### New AdapterInterceptor System

0.6.0 introduces a unified `AdapterInterceptor` interface that works across all adapters:

#### Old Way (0.5.x - Dio-specific)

```dart
import 'package:dio/dio.dart';

class MyInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Dio-specific code
    options.headers['Authorization'] = 'Bearer token';
    handler.next(options);
  }
}

await RxNet.init(
  baseUrl: "https://api.example.com",
  interceptors: [MyInterceptor()],  // Dio Interceptor
);
```

#### New Way (0.6.0 - Adapter-agnostic)

```dart
import 'package:rxnet_plus/src/adapter/interceptor/adapter_interceptor.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_request.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_response.dart';

class MyInterceptor implements AdapterInterceptor {
  @override
  void onRequest(AdapterRequest request, RequestInterceptorHandler handler) {
    // Works with any adapter!
    final modifiedRequest = request.copyWith(
      headers: {...request.headers, 'Authorization': 'Bearer token'},
    );
    handler.next(modifiedRequest);
  }
  
  @override
  void onResponse(AdapterResponse response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }
  
  @override
  void onError(AdapterException error, ErrorInterceptorHandler handler) {
    handler.next(error);
  }
}

await RxNet.init(
  baseUrl: "https://api.example.com",
  interceptors: [MyInterceptor()],  // AdapterInterceptor
);
```

### Built-in Interceptor Update

**Old:** `RxNetLogInterceptor` (Dio-specific)
**New:** `RxNetLogAdapterInterceptor` (works with all adapters)

```dart
// ✅ 0.6.0 - Recommended
import 'package:rxnet_plus/net/interceptor/rxnet_log_adapter_interceptor.dart';

await RxNet.init(
  baseUrl: "https://api.example.com",
  interceptors: [RxNetLogAdapterInterceptor()],
);

// ⚠️ 0.5.x - Still works with DioAdapter but deprecated
import 'package:dio/dio.dart';

await RxNet.init(
  baseUrl: "https://api.example.com",
  interceptors: [LogInterceptor()],  // Dio's LogInterceptor
);
```

### Interceptor Execution Flow (Important!)

In 0.6.0, interceptors execute **BEFORE** the underlying HTTP client:

```
User Request
    ↓
BuildRequest creates AdapterRequest (with all parameters)
    ↓
DioAdapter.request() receives AdapterRequest
    ↓
✅ Execute AdapterInterceptors (can access bodyParams, pathParams, etc.)
    ↓
Convert to Dio RequestOptions
    ↓
Call Dio.request()
    ↓
Convert Dio Response to AdapterResponse
    ↓
✅ Execute Response Interceptors
    ↓
Return to User
```

**Benefits:**
- Interceptors can access complete request information (bodyParams, pathParams, etc.)
- No information loss during conversion
- Interceptors can modify requests before they're sent
- Works consistently across all adapters

### Interceptor Handler Methods

```dart
class MyInterceptor implements AdapterInterceptor {
  @override
  void onRequest(AdapterRequest request, RequestInterceptorHandler handler) {
    // Option 1: Continue with original request
    handler.next(request);
    
    // Option 2: Modify request and continue
    final modified = request.copyWith(headers: {...});
    handler.next(modified);
    
    // Option 3: Return response directly (skip actual request)
    handler.resolve(AdapterResponse(...));
    
    // Option 4: Reject with error
    handler.reject(AdapterException(...));
  }
  
  @override
  void onResponse(AdapterResponse response, ResponseInterceptorHandler handler) {
    // Option 1: Continue with original response
    handler.next(response);
    
    // Option 2: Modify response
    final modified = response.copyWith(data: {...});
    handler.next(modified);
    
    // Option 3: Reject with error
    handler.reject(AdapterException(...));
  }
  
  @override
  void onError(AdapterException error, ErrorInterceptorHandler handler) {
    // Option 1: Continue with error
    handler.next(error);
    
    // Option 2: Modify error
    final modified = error.copyWith(message: 'Custom message');
    handler.next(modified);
    
    // Option 3: Resolve with response (convert error to success)
    handler.resolve(AdapterResponse(...));
  }
}
```

---

## 🎯 CancelToken Improvements

### New Standalone CancelToken

0.6.0 introduces a new `CancelToken` class that's independent of Dio:

#### Old Way (0.5.x)

```dart
import 'package:dio/dio.dart';

final cancelToken = CancelToken();  // Dio's CancelToken

RxNet.get()
  .setPath('/users')
  .setCancelToken(cancelToken)
  .request();

cancelToken.cancel();  // Cancel request
```

#### New Way (0.6.0)

```dart
import 'package:rxnet_plus/src/adapter/cancel_token.dart';

final cancelToken = CancelToken();  // RxNet's CancelToken

RxNet.get()
  .setPath('/users')
  .setCancelToken(cancelToken)
  .request();

// Cancel with optional reason
cancelToken.cancel('User cancelled');

// Check if cancelled
if (cancelToken.isCancelled) {
  print('Cancelled: ${cancelToken.cancelReason}');
}

// Register callback
cancelToken.whenCancel((reason) {
  print('Request was cancelled: $reason');
});
```

### Cancellation Behavior by Adapter

**Important:** Cancellation behavior differs between adapters:

| Adapter | Cancellation Type | HTTP Connection | Bandwidth |
|---------|------------------|-----------------|-----------|
| **DioAdapter** | ✅ True | Aborted immediately | Saved |
| **HttpAdapter** | ⚠️ Pseudo | Continues running | Wasted |
| **MockAdapter** | ✅ True | N/A (no network) | N/A |

**DioAdapter (Recommended for cancellation):**
```dart
final adapter = DioAdapter();
await RxNet.init(baseUrl: "...", adapter: adapter);

final cancelToken = CancelToken();
RxNet.get()
  .setPath('/large-file')
  .setCancelToken(cancelToken)
  .download(savePath: '/path/to/file');

// ✅ Truly aborts the HTTP connection
cancelToken.cancel();
```

**HttpAdapter (Limited cancellation):**
```dart
final adapter = HttpAdapter();
await RxNet.init(baseUrl: "...", adapter: adapter);

final cancelToken = CancelToken();
RxNet.get()
  .setPath('/large-file')
  .setCancelToken(cancelToken)
  .download(savePath: '/path/to/file');

// ⚠️ Marks as cancelled but HTTP request continues
cancelToken.cancel();
```

**Recommendation:** Use DioAdapter for scenarios requiring true cancellation (large files, long-running requests).

---

## 🔄 Common Migration Scenarios

### Scenario 1: No Changes Needed

**Before (0.5.x):**
```dart
await RxNet.init(
  baseUrl: "https://api.example.com",
  interceptors: [RxNetLogInterceptor()],
);

final response = await RxNet.get()
    .setPath('/users')
    .request();
```

**After (0.6.0):**
```dart
// Same code works! No changes needed
await RxNet.init(
  baseUrl: "https://api.example.com",
  interceptors: [RxNetLogInterceptor()],
);

final response = await RxNet.get()
    .setPath('/users')
    .request();
```

### Scenario 2: Switching to HttpAdapter

**Before (0.5.x):**
```dart
await RxNet.init(
  baseUrl: "https://api.example.com",
);
```

**After (0.6.0):**
```dart
import 'package:rxnet_plus/adapters/http_adapter.dart';

await RxNet.init(
  baseUrl: "https://api.example.com",
  adapter: HttpAdapter(),  // Add this line
);
```

### Scenario 3: Adding Unit Tests

**Before (0.5.x):**
```dart
// Difficult to test without real network calls
test('should fetch user data', () async {
  // Had to make real network requests or mock Dio
});
```

**After (0.6.0):**
```dart
import 'package:rxnet_plus/adapters/mock_adapter.dart';

test('should fetch user data', () async {
  final mockAdapter = MockAdapter();
  mockAdapter.setMockResponse(
    '/users/123',
    AdapterResponse(
      statusCode: 200,
      data: {'id': 123, 'name': 'John'},
      headers: {},
      request: AdapterRequest(
        baseUrl: 'https://api.example.com',
        path: '/users/123',
        method: HttpMethod.get,
      ),
    ),
  );
  
  await RxNet.init(
    baseUrl: 'https://api.example.com',
    adapter: mockAdapter,
  );
  
  final result = await RxNet.get()
      .setPath('/users/123')
      .request();
  
  expect(result.isSuccess, true);
  expect(result.value['name'], 'John');
});
```

---

## ❓ FAQ

### Q: Do I need to change my existing code?

**A:** No! RxNet Plus 0.6.0 is 100% backward compatible. Your existing code will work without any changes.

### Q: What adapter is used by default?

**A:** DioAdapter is used by default, maintaining the same behavior as 0.5.x.

### Q: Can I use multiple adapters in the same app?

**A:** Yes! You can create multiple RxNet instances with different adapters:

```dart
final mainApi = RxNet.create();
await mainApi.initNet(baseUrl: "...", adapter: DioAdapter());

final testApi = RxNet.create();
await testApi.initNet(baseUrl: "...", adapter: MockAdapter());
```

### Q: Will switching adapters affect my cache?

**A:** No, the cache system is adapter-independent. Your cached data will work with any adapter.

### Q: Can I switch adapters at runtime?

**A:** You need to reinitialize RxNet with a new adapter. It's recommended to choose an adapter at app startup.

### Q: Do interceptors work with all adapters?

**A:** Yes! The interceptor system is adapter-independent and works with all adapters.

### Q: What if I want to use a different HTTP client?

**A:** You can create a custom adapter by implementing the `NetworkAdapter` interface. See the [Custom Adapter Guide](lib/adapters/README.md#creating-a-custom-adapter) for details.

### Q: Is there any performance difference between adapters?

**A:** DioAdapter generally offers the best performance and features. HttpAdapter is slightly lighter but with fewer features. The difference is minimal for most applications.

### Q: Can I still access the underlying Dio instance?

**A:** Yes, if you're using DioAdapter:

```dart
final adapter = DioAdapter();
await RxNet.init(baseUrl: "...", adapter: adapter);

// Access the Dio instance
final dio = adapter.dio;
```

### Q: What about certificate validation?

**A:** Certificate validation works the same way:

```dart

1.DioAdapter example:

final adapter = DioAdapter();
adapter.dio.httpClientAdapter = IOHttpClientAdapter(
  createHttpClient: () {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      // Your validation logic
      return true;
    };
    return client;
  },
);

2.HttpAdapter example:
    
IOClient createPinnedClient() {
final HttpClient httpClient = HttpClient();
httpClient.badCertificateCallback =
(X509Certificate cert, String host, int port) {
    // // 获取证书 DER
    // final der = cert.der;
    // final sha256 = sha256Convert(der);
    // const trustedFingerprint = "YOUR_SHA256_FINGERPRINT";
    // return sha256 == trustedFingerprint;
    return true;
  };
  return IOClient(httpClient);
}

final adapter = HttpAdapter(client: createPinnedClient());

await RxNet.init(baseUrl: "...", adapter: adapter);
```

---

## 📚 Additional Resources

- [Adapter Usage Guide](lib/adapters/README.md)
- [DioAdapter Documentation](lib/adapters/dio_adapter.dart)
- [HttpAdapter Documentation](lib/adapters/http_adapter.dart)
- [MockAdapter Documentation](lib/adapters/mock_adapter.dart)
- [Custom Adapter Tutorial](docs/custom_adapter_guide.md)
- [API Documentation](https://pub.dev/documentation/rxnet_plus/latest/)

---

## 🆘 Need Help?

If you encounter any issues during migration:

1. Check the [FAQ](#faq) section above
2. Review the [Adapter Usage Guide](lib/adapters/README.md)
3. Open an issue on [GitHub](https://github.com/ZhengZaiHong/rxnet/issues)
4. Check existing issues for similar problems

---

## 🎯 Summary

**Key Takeaways:**

✅ **No breaking changes** - Your existing code works as-is
✅ **New flexibility** - Choose the adapter that fits your needs
✅ **Better testing** - Use MockAdapter for easy unit tests
✅ **Extensible** - Create custom adapters when needed
✅ **Same great features** - All caching, interceptors, and features still work

**Recommended Actions:**

1. Update to 0.6.0 (no code changes needed)
2. Explore MockAdapter for better unit tests
3. Consider HttpAdapter if package size is a concern
4. Read the adapter documentation to understand new capabilities

Welcome to RxNet Plus 0.6.0! 🚀
