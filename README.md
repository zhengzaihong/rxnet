# RxNet

[![pub package](https://img.shields.io/pub/v/rxnet_plus.svg)](https://pub.dev/packages/rxnet_plus)
[![GitHub stars](https://img.shields.io/github/stars/ZhengZaiHong/rxnet.svg?style=social)](https://github.com/ZhengZaiHong/rxnet)
[![license](https://img.shields.io/github/license/ZhengZaiHong/rxnet)](LICENSE)

Language: English | [简体中文](README-ZH.md)

RxNet: Extremely Easy-to-Use, Powerful, Native-Style Flutter Network Communication Framework

RxNet is a cross-platform network request tool specially built for Flutter. It conforms to native development habits, can be started with almost zero learning cost, and supports rich function combinations to help you build high-performance, maintainable applications.

---
[instructions for use document](docs/USAGE_GUIDE.md)

## 0.7.0 Update - Config, Cache Eviction, Retry Policies & More

RxNet 0.7.0 introduces structured configuration, advanced cache management, intelligent retry strategies, and built-in interceptors.

**New in 0.7.0:**

- **RxNetConfig** - Clean configuration class with Builder pattern, replacing long parameter lists
- **Cache Eviction** - LRU / LFU / FIFO policies with configurable `cacheMaxSize`
- **RetryPolicy** - Exponential backoff, jitter strategies beyond fixed interval
- **AdapterBaseOptions** - Adapter-agnostic global request defaults (timeout, headers, etc.)
- **TokenRefreshInterceptor** - Automatic token refresh on 401/403 with concurrent deduplication
- **DeduplicateInterceptor** - Prevents duplicate requests within configurable time window
- **ThrottleInterceptor** - Request rate limiting with configurable window
- **RxResult.success()** - Guaranteed non-null value factory + `requiredValue` getter

**100% backward compatible** - All existing code works without changes. New features are opt-in.

### Previous Highlights

- **0.6.x**: Pluggable Adapter Architecture (DioAdapter, HttpAdapter, MockAdapter)
- **0.5.0**: RESTful auto-detection, parameter separation, breakpoint upload/download

## Table of Contents

- [Quick Start](#quick-start)
- [RxNetConfig](#rxnetconfig)
- [Cache Eviction](#cache-eviction)
- [Retry Policy](#retry-policy)
- [AdapterBaseOptions](#adapterbaseoptions)
- [Adapter Selection](#adapter-selection)
- [Request Examples](#request-examples)
- [Built-in Interceptors](#built-in-interceptors)
- [Concurrent Requests](#concurrent-requests)
- [Upload & Download](#upload--download)
- [Certificate Validation](#certificate-validation)
- [Migration from 0.6.x to 0.7.0](#migration-from-06x-to-070)

---

## Quick Start

### Option 1: RxNetConfig (Recommended)

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
  cacheInvalidationTime: 24 * 60 * 60 * 1000,
  cacheMaxSize: 500,
  cacheEvictionPolicy: CacheEvictionPolicy.lru,
  adapterBaseOptions: AdapterBaseOptions(
    connectTimeout: Duration(seconds: 10),
    sendTimeout:  Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
  ),
  interceptors: [
    RxNetLogAdapterInterceptor(),
  ],
));
```

### Option 2: Builder Pattern

```dart
await RxNet.init(config: RxNetConfig.builder()
  .baseUrl("https://api.example.com")
  .cacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
  .cacheInvalidationTime(24 * 60 * 60 * 1000)
  .cacheMaxSize(500)
  .cacheEvictionPolicy(CacheEvictionPolicy.lru)
  .baseOptions(AdapterBaseOptions(
    connectTimeout: Duration(seconds: 10),
    sendTimeout:  Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
    
  ))
  .addInterceptor(RxNetLogAdapterInterceptor())
  .build());
```

---

## RxNetConfig

`RxNetConfig` is the recommended way to configure RxNet. It provides a clean, type-safe configuration object with Builder pattern support.

### All Configuration Options

```dart
final config = RxNetConfig(
  baseUrl: "https://api.example.com",          // Required
  adapter: DioAdapter(),                        // Optional, defaults to DioAdapter
  adapterBaseOptions: AdapterBaseOptions(       // Optional, global request defaults
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
    sendTimeout:  Duration(seconds: 10),
    headers: {'Authorization': 'Bearer token'},
  ),
  cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
  cacheInvalidationTime: 60 * 1000,            // 1 minute
  cacheMaxSize: 500,                           // Max 500 entries
  cacheEvictionPolicy: CacheEvictionPolicy.lru, // LRU eviction
  interceptors: [RxNetLogAdapterInterceptor()],
  cachePath: '/path/to/cache',
  cacheName: 'network_cache',
  databaseName: 'rxnet_cache.db',
  ignoreCacheKeys: ['token'],
  baseUrlEnv: {'dev': 'https://dev.api.com', 'prod': 'https://api.com'},
  baseCheckNet: myCheckNetFunction,
);
```

### copyWith

```dart
final updatedConfig = config.copyWith(
  baseUrl: "https://new-api.example.com",
  cacheMaxSize: 1000,
);
```

---

## Cache Eviction & Hit Rate

### Cache Eviction Policies

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  cacheMaxSize: 200,
  cacheEvictionPolicy: CacheEvictionPolicy.lru,
));
```

| Policy | Behavior |
|--------|----------|
| `CacheEvictionPolicy.none` | No eviction (default, backward compatible) |
| `CacheEvictionPolicy.lru` | Evicts least recently accessed entries |
| `CacheEvictionPolicy.lfu` | Evicts least frequently accessed entries |
| `CacheEvictionPolicy.fifo` | Evicts oldest entries by creation time |

### Cache Hit Rate Statistics

```dart
final hitRate = RxNet.I.cacheManager.hitRate;       // 0.0 ~ 1.0
final hits = RxNet.I.cacheManager.hitCount;
final misses = RxNet.I.cacheManager.missCount;
RxNet.I.cacheManager.resetStats();                   // Reset counters
```

### Programmatic Cache Management

```dart
final cache = RxNet.I.cacheManager;

// Save/read network cache
await cache.saveNetworkCache(path: '/api/data', params: {'page': 1}, responseData: {...});
final data = await cache.readNetworkCache(path: '/api/data', params: {'page': 1});

// Save/read key-value cache
await cache.put('user_token', 'abc123');
final token = await cache.get<String>('user_token');

// Clear cache
await cache.clearAll();
await cache.clearByPrefix('/api/users');
await cache.clearByPattern(r'^/api/v\d+/');

// Query cache
final size = await cache.getCacheSize();
final keys = await cache.getAllKeys();
```

---

## Retry Policy

### Fixed Interval (Default)

```dart
RxNet.get()
  .setPath("/api/data")
  .setRetryCount(3, interval: Duration(seconds: 2))
  .request();
```

### Advanced RetryPolicy

```dart
// Exponential backoff
RxNet.get()
  .setPath("/api/data")
  .setRetryPolicy(RetryPolicy.exponentialBackoff(
    maxRetries: 3,
    baseInterval: Duration(seconds: 1),
    maxInterval: Duration(seconds: 30),
  ))
  .request();

// Exponential backoff with jitter (recommended for distributed systems)
RxNet.get()
  .setPath("/api/data")
  .setRetryPolicy(RetryPolicy.exponentialBackoffWithJitter(
    maxRetries: 5,
    baseInterval: Duration(seconds: 1),
    maxInterval: Duration(seconds: 30),
  ))
  .request();
```

| Strategy | Attempt 1 | Attempt 2 | Attempt 3 | Best For |
|----------|-----------|-----------|-----------|----------|
| `fixed` | 1s | 1s | 1s | Simple cases |
| `exponentialBackoff` | 1s | 2s | 4s | Server overload recovery |
| `exponentialBackoffWithJitter` | ~0.5s | ~1.5s | ~3s | Distributed systems |

---

## AdapterBaseOptions

Set global request defaults that apply to all requests across all adapters:

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  adapterBaseOptions: AdapterBaseOptions(
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
    sendTimeout: Duration(seconds: 30),
    headers: {'Authorization': 'Bearer token'},
    contentType: 'application/json',
    responseType: ResponseType.json,
    followRedirects: true,
    maxRedirects: 5,
    receiveDataWhenStatusError: true,
    persistentConnection: true,
  ),
));
```

Request-level parameters always override global defaults

---

## Adapter Selection

| Adapter | Package | Features | Cancellation | Best For |
|---------|---------|----------|--------------|----------|
| **DioAdapter** | `dio: ^5.8.0+1` | All features, interceptors | True (aborts connection) | Production apps (default) |
| **HttpAdapter** | `http: ^1.2.0` | Basic HTTP, interceptors, multipart, stream | Pseudo (marks cancelled) | Lightweight apps |
| **MockAdapter** | Built-in | Testing, no network | Simulated | Unit/integration tests |

**Default:** DioAdapter is used if no adapter is specified.

### Multiple Instances

```dart
final mainApi = RxNet.create();
await mainApi.initNet(config:RxNetConfig(baseUrl: "https://api.main.com", adapter: DioAdapter()));

final analyticsApi = RxNet.create();
await analyticsApi.initNet(config:RxNetConfig(baseUrl: "https://analytics.example.com", adapter: HttpAdapter()));
```

---

## Request Examples

### Supported Methods

`get`, `post`, `delete`, `put`, `patch`, `head`, `options`

### Cache Modes

```dart
enum CacheMode {
  ONLY_REQUEST,                        // No caching, always network
  ONLY_CACHE,                          // Cache only, no network
  REQUEST_FAILED_READ_CACHE,           // Network first, fallback to cache
  FIRST_USE_CACHE_THEN_REQUEST,        // Cache first, then network
  CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST, // Network only if cache empty/expired
}
```

### 1. Callback Mode

```dart
RxNet.get<WeatherInfo>()
  .setPath('/api/weather/city/{id}')
  .setPathParam("id", "101030100")
  .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
  .setJsonConvert(WeatherInfo.fromJson)
  .setRetryPolicy(RetryPolicy.exponentialBackoff(maxRetries: 3))
  .execute(
    success: (data, source) {
      setState(() { weather = data; });
    },
    failure: (e) {
      setState(() { error = e.toString(); });
    },
    completed: () { /* Always called */ },
  );
```

### 2. async/await Mode

```dart
final result = await RxNet.get<WeatherInfo>()
  .setPath('/api/weather/city/{id}')
  .setPathParam("id", "101030100")
  .setJsonConvert(WeatherInfo.fromJson)
  .request();

if (result.isSuccess) {
  print(result.value);
}
```

### 3. Stream Mode

```dart
StreamSubscription? _subscription;

_subscription = RxNet.get()
  .setPath('/api/weather/city/{id}')
  .setPathParam("id", "101030100")
  .setLoop(true, interval: const Duration(seconds: 5))
  .executeStream()
  .listen((result) {
    if (result.isSuccess) { setState(() { weather = result.value; }); }
  });

// Don't forget to cancel in dispose()
@override
void dispose() { _subscription?.cancel(); super.dispose(); }
```

---

## Built-in Interceptors

### TokenRefreshInterceptor

```dart
TokenRefreshInterceptor(
  tokenProvider: () async { ... },
  isUnauthorized: (error, request) => error.statusCode == 401,
  onRequestUpdated: (request, newToken) {
    return request.copyWith(headers: {...request.headers, 'Authorization': 'Bearer $newToken'});
  },
  onTokenRefreshed: (token) => currentToken = token,
);
```

### DeduplicateInterceptor

```dart
DeduplicateInterceptor(windowDuration: Duration(milliseconds: 500))
```

### ThrottleInterceptor

```dart
ThrottleInterceptor(throttleDuration: Duration(seconds: 1))
```

---

## Concurrent Requests

### For async/await (Recommended)

```dart
final (weather, user) = await (
  RxNet.get<Weather>().setPath('/weather').request(),
  RxNet.get<User>().setPath('/user').request(),
).wait;
```

### For Callback Requests (zipRequest)

```dart
final results = await RxNet.zipRequest([
  ZipRequest<Weather>(request: ..., tag: 'weather'),
  ZipRequest<User>(request: ..., tag: 'user'),
]);
final weather = results.getRequestByTag<Weather>('weather');
```

---

## Upload & Download

```dart
// Download
await RxNet.get().setPath("https://example.com/file.zip")
  .downloadFile(savePath: "${appDocPath}/file.zip");

// Breakpoint Download
RxNet.get().setPath("https://example.com/large-file.zip")
  .breakPointDownload(savePath: "...", onReceiveProgress: (len, total) {});

// Breakpoint Upload
RxNet.post().setPath("/api/upload")
  .breakPointUpload(filePath: "/path/to/file.jpg", onSendProgress: (len, total) {});
```

---


## certificate verification



#### Using DioAdapter (dio package method)
```dart
adapter.dio.httpClientAdapter = IOHttpClientAdapter(
  createHttpClient: () {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) {
      // final der = cert.der;
      // final sha256 = sha256Convert(der);
      // const trustedFingerprint = "YOUR_SHA256_FINGERPRINT";
      // return sha256 == trustedFingerprint;
      return true;
    };
    return client;
  },
);
```

#### Using HttpAdapter (http package method)

```dart
import 'dart:io';
import 'package:http/io_client.dart';

// Create a custom HTTP client with certificate verification
IOClient createPinnedClient() {
  final HttpClient httpClient = HttpClient();
  httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
    // Add your certificate verification logic here
    // For example: verifying certificate fingerprint
    // final der = cert.der;
    // final sha256 = sha256Convert(der);
    // const trustedFingerprint = "YOUR_SHA256_FINGERPRINT";
    // return sha256 == trustedFingerprint;
    return true; // For testing only, please verify the production environment correctly
  };
  return IOClient(httpClient);
}

// Create an HttpAdapter using a custom client
final httpAdapter = HttpAdapter(client: createPinnedClient());

// Initialize RxNet using a configured adapter
await RxNet.init(config:RxNetConfig
  baseUrl: "https://your-api.com",
  adapter: httpAdapter,
));
```

## Migration from 0.6.x to 0.7.0

**Be sure to configure RxNetConfig**

```dart
await RxNet.init(config: RxNetConfig(baseUrl: "...", cacheMode: CacheMode.ONLY_REQUEST));
```

---

## Debug Window

```dart
RxNet.showDebugWindow(context);
```

![Debug Window](https://github.com/ZhengZaiHong/rxnet/blob/master/images/app_logcat.jpg)

## HarmonyOS Support

![HarmonyOS](https://github.com/ZhengZaiHong/rxnet/blob/master/images/HarmonyOS-example.gif)
