## 0.7.0

### New Features

- **RxNetConfig Configuration Class** - Clean, type-safe configuration with Builder pattern
  - `RxNetConfig` replaces long parameter lists with a structured config object
  - Builder pattern: `RxNetConfig.builder().baseUrl('...').cacheMode(...).build()`
  - `copyWith()` for immutable config modifications
  - 100% backward compatible - old `initNet()` parameters still work

- **Cache Eviction Policies** - Automatic cache size management
  - `cacheMaxSize` - Maximum number of cache entries (0 = unlimited)
  - `CacheEvictionPolicy.lru` - Least Recently Used eviction
  - `CacheEvictionPolicy.lfu` - Least Frequently Used eviction
  - `CacheEvictionPolicy.fifo` - First In First Out eviction
  - `CacheMetadata` tracks createdAt, lastAccessedAt, accessCount per entry
  - Automatic eviction on every cache write when size exceeds limit

- **RetryPolicy** - Advanced retry strategies beyond fixed interval
  - `RetryStrategy.fixed` - Fixed interval (default, backward compatible)
  - `RetryStrategy.exponentialBackoff` - Delay doubles each attempt
  - `RetryStrategy.exponentialBackoffWithJitter` - Exponential + random jitter
  - `maxInterval` cap to prevent excessive delays
  - Factory methods: `RetryPolicy.fixed()`, `RetryPolicy.exponentialBackoff()`, `RetryPolicy.exponentialBackoffWithJitter()`

- **AdapterBaseOptions** - Adapter-agnostic global request defaults
  - Set connectTimeout, receiveTimeout, sendTimeout globally
  - Set default headers, contentType, responseType
  - Configurable followRedirects, maxRedirects, persistentConnection
  - Applied via `RxNetConfig(adapterBaseOptions: ...)` or Builder

- **TokenRefreshInterceptor** - Automatic token refresh on auth errors
  - Detects 401/403 responses and triggers token refresh
  - Concurrent refresh deduplication (only one refresh call at a time)
  - Customizable `isUnauthorized` callback
  - `onRequestUpdated` callback to inject new token into request
  - Lifecycle callbacks: `onTokenRefreshing`, `onTokenRefreshed`, `onTokenRefreshFailed`

- **DeduplicateInterceptor** - Request deduplication within time window
  - Prevents duplicate requests with same path within configurable window
  - Automatically allows requests after window expires

- **ThrottleInterceptor** - Request rate limiting
  - Rejects requests within throttle window after the first pass-through
  - Configurable throttle duration

- **Cache Clearing by Prefix/Pattern** - Granular cache management
  - `cacheManager.clearByPrefix(prefix)` - Clear all entries matching prefix
  - `cacheManager.clearByPattern(pattern)` - Clear all entries matching regex

- **RxResult Improvements** - Safer result handling
  - `RxResult.success(value)` factory - Guaranteed non-null value
  - `requiredValue` getter - Throws StateError if error or null

### Improved

- **BuildRequest Cache Integration** - Cache operations now use `RxNetCache` directly
  - Cache reads/writes go through `RxNetCache.saveNetworkCache()` / `readNetworkCache()`
  - Eviction policies enforced automatically on cache writes

### Changed

- **Database Metadata Store** - `RxNetDataBase` now supports metadata storage
  - `putMetadata()` / `getMetadata()` / `deleteMetadata()` / `getAllMetadata()` / `cleanMetadata()`
  - Separate Sembast store for cache metadata (eviction tracking)

### Migration Guide

**100% backward compatible** - No code changes required. New features are opt-in.

**New: RxNetConfig (recommended)**

Before:
```dart
await RxNet.init(
  baseUrl: "https://api.example.com",
  cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
  cacheInvalidationTime: 60000,
  interceptors: [RxNetLogAdapterInterceptor()],
);
```

After:
```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
  cacheInvalidationTime: 60000,
  interceptors: [RxNetLogAdapterInterceptor()],
  cacheMaxSize: 500,
  cacheEvictionPolicy: CacheEvictionPolicy.lru,
  adapterBaseOptions: AdapterBaseOptions(
    connectTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
  ),
));
```

**New: RetryPolicy**

Before:
```dart
RxNet.get()
  .setPath("/api/data")
  .setRetryCount(3, interval: Duration(seconds: 2))
  .request();
```

After:
```dart
RxNet.get()
  .setPath("/api/data")
  .setRetryPolicy(RetryPolicy.exponentialBackoff(
    maxRetries: 3,
    baseInterval: Duration(seconds: 1),
    maxInterval: Duration(seconds: 10),
  ))
  .request();
```

---

## 0.6.2

### Fixed
- **ZipRequest Code Quality** - Improved implementation and maintainability

### Changed
- **ZipRequest API Simplification** - Breaking change with clear migration path

## 0.6.1

### New Features
- **Concurrent Callback Requests** - Execute multiple callback-based requests in parallel
- **Sembast Database** - Replaced Hive with pure Dart database solution

### Fixed
- **Breakpoint Download Fixes** - Works correctly with all adapters
- **HttpAdapter Improvements** - Multipart upload, stream responses, progress tracking
- **URL Path Normalization** - Fixed multiple slashes in request URLs
- **Web Platform Support** - Fixed adapters on Web platform

## 0.6.0

### Added
- **Pluggable Adapter Architecture** - DioAdapter, HttpAdapter, MockAdapter
- **Unified Interceptor System** - Adapter-agnostic AdapterInterceptor interface
- **Custom Adapter Support** - Implement NetworkAdapter interface

## 0.5.0

- **Parameter type separation** - Path, query, and body parameters
- **RESTful automatic detection** - No manual settings required
- **API semantic improvement** - More intuitive method names
- **Low-level reconstruction** - Updated BuildRequest

## 0.4.x

- Generic request support with type conversion
- RESTFul @path style request support
- Overall architecture redesign
