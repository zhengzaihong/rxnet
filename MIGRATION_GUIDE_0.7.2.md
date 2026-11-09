# Migration Guide: RxNet Plus 0.7.1 → 0.7.2

0.7.2 is published as a patch version, but it contains **behavior changes**.
Please review this guide before upgrading production applications.

```yaml
dependencies:
  rxnet_plus: ^0.7.2
```

## 1. Debug logging is off by default

`RxNetConfig.isDebug` now defaults to `false`. Logging and sensitive-data
redaction still work, but logs are not emitted unless debug mode is enabled.

```dart
await RxNet.init(
  config: RxNetConfig(
    baseUrl: 'https://api.example.com',
    isDebug: kDebugMode, // enable only in debug builds
  ),
);
```

## 2. `request()` returns the final result

`request()` now waits for the final cache/network/retry result:

- Cache-first modes still perform the network request instead of returning the
  cached value immediately.
- Retries no longer return the first failed attempt.
- `setLoop(true)` keeps returning the first result for `request()`; use
  `executeStream()` for polling.

If you need the cache value immediately, use the stream/callback API:
`executeStream()`.

## 3. Retry policy is stricter

Default retry behavior now:

- POST / PATCH are **not** retried.
- 4xx responses (except 408/429), cancellation and parsing errors are not retried.
- Timeouts, connection errors, 5xx, 408 and 429 are retryable.

To restore retries for non-idempotent methods:

```dart
RxNet.post()
  .setRetryPolicy(RetryPolicy.fixed(
    maxRetries: 2,
    retryOnNonIdempotent: true,
  ));
```

## 4. Cache keys are hashed

Path-based cache keys now always use the first 32 hex chars of SHA-256.
Existing path-based caches become misses once; the first request after upgrade
will populate a new key. User-provided keys passed to `saveCache` are unchanged.

## 5. Interceptors may be asynchronous

`AdapterInterceptor` methods now return `FutureOr<void>` and are awaited by all
built-in adapters. Existing synchronous `void` implementations remain compatible.

```dart
@override
Future<void> onRequest(
  AdapterRequest request,
  RequestInterceptorHandler handler,
) async {
  final token = await tokenStore.read();
  handler.next(request.copyWith(
    headers: {...request.headers, 'Authorization': 'Bearer $token'},
  ));
}
```

## 6. Token refresh now really retries

`TokenRefreshInterceptor` uses `ErrorInterceptorHandler.retry(...)` and resends
the original request. It no longer returns the synthetic response containing
`_tokenRefreshed` / `_retryRequest`.

Remove any application code that inspected those synthetic fields.

## 7. Status validation

`AdapterResponse.successOverride` was added so `AdapterBaseOptions.validateStatus`
decisions survive the adapter boundary. If you relied on `isSuccess` being
always 2xx-only, configure `validateStatus` explicitly when needed.

## 8. Environment and adapter configuration

Two long-standing bugs are fixed:

- `RxNet.init` now uses `config.adapter` (previously the custom adapter was
  ignored).
- `setEnv` / `setDefaultEnv` now update the URL used by actual requests.

If your app worked around either behavior, remove the workaround.

## 9. Lifecycle

`RxNet.dispose()` / `disposeInstance()` now closes the adapter and database and
clears listeners. Repeated initialization with the same config is idempotent;
re-initialization with a different config releases the previous database and
interceptor registrations.

Call it when the application/isolate is shutting down:

```dart
await RxNet.dispose();
```

## 10. Platform exports

`IOClient` and `IOHttpClientAdapter` are exported only on IO platforms. On Web,
`rxnet_lib.dart` exports an empty stub instead. Platform-specific code must not
reference IO-only types unconditionally:

```dart
// example/lib/pinned_client_web.dart
import 'package:http/http.dart' as http;
http.Client createClient() => http.Client();

// example/lib/pinned_client_io.dart
import 'dart:io';
import 'package:http/io_client.dart';
http.Client createClient() => IOClient(HttpClient());
```

## 11. Other API notes

- `ZipRequestError` now implements `Exception`.
- Prefer `RxNetPlatform.isAndroidIosHarmonyOs`; the old
  `isAndroid_IOS_HarmonyOS` getter remains as a deprecated alias.
- Logs redact Authorization, Cookie, token, password and PII fields by default.
  Set `logSensitiveData: true` only for local debugging.

## Verification checklist

- `flutter pub get`
- `flutter analyze`
- `flutter test`
- `flutter build web`
- `flutter build windows` (or your target IO platform)