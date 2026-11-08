import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('BuildRequest.request final-result semantics', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rxnet_request_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('cache-first mode waits for the network result', () async {
      final adapter = MockAdapter();
      final rxNet = RxNet.create();
      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://example.com',
          adapter: adapter,
          cachePath: tempDir.path,
          databaseName: 'request_cache.db',
        ),
      );
      addTearDown(() => rxNet.getDatabase()?.closeInstance());

      // 第一次请求：缓存为空，走网络并写入缓存
      final first = await rxNet
          .getRequest()
          .setPath('/cached')
          .setCacheMode(CacheMode.FIRST_USE_CACHE_THEN_REQUEST)
          .request();
      expect(first.isSuccess, isTrue);
      expect(first.model, SourcesType.net);
      expect(adapter.requestHistory, hasLength(1));

      // 第二次请求：缓存命中后仍必须发起网络请求，并返回网络结果
      final second = await rxNet
          .getRequest()
          .setPath('/cached')
          .setCacheMode(CacheMode.FIRST_USE_CACHE_THEN_REQUEST)
          .request();

      expect(second.isSuccess, isTrue);
      expect(second.model, SourcesType.net);
      expect(adapter.requestHistory, hasLength(2));
    });

    test('request returns the final success after retries', () async {
      final adapter = _FlakyAdapter(failures: 2);
      final rxNet = RxNet.create();
      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://example.com',
          adapter: adapter,
          cachePath: tempDir.path,
          databaseName: 'request_retry.db',
          cacheMode: CacheMode.ONLY_REQUEST,
        ),
      );
      addTearDown(() => rxNet.getDatabase()?.closeInstance());

      final result = await rxNet
          .getRequest()
          .setPath('/retry')
          .setRetryCount(2, interval: Duration.zero)
          .request();

      expect(adapter.calls, 3);
      expect(result.isSuccess, isTrue);
      expect(result.value, {'ok': true});
    });

    test('request returns the last error after all retries fail', () async {
      final adapter = _FlakyAdapter(failures: 10);
      final rxNet = RxNet.create();
      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://example.com',
          adapter: adapter,
          cachePath: tempDir.path,
          databaseName: 'request_retry_fail.db',
          cacheMode: CacheMode.ONLY_REQUEST,
        ),
      );
      addTearDown(() => rxNet.getDatabase()?.closeInstance());

      final result = await rxNet
          .getRequest()
          .setPath('/always-fail')
          .setRetryCount(2, interval: Duration.zero)
          .request();

      expect(adapter.calls, 3);
      expect(result.isError, isTrue);
      expect(result.error, isA<NetworkException>());
    });
  });

  group('BuildRequest retry filtering (P1)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rxnet_retry_filter_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<RxNet> initAdapter(NetworkAdapter adapter, String dbName) async {
      final rxNet = RxNet.create();
      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://example.com',
          adapter: adapter,
          cachePath: tempDir.path,
          databaseName: dbName,
          cacheMode: CacheMode.ONLY_REQUEST,
        ),
      );
      addTearDown(() => rxNet.getDatabase()?.closeInstance());
      return rxNet;
    }

    AdapterException responseError(int statusCode) => AdapterException(
          message: 'status $statusCode',
          type: AdapterExceptionType.response,
          statusCode: statusCode,
        );

    test('GET retries transient 5xx errors', () async {
      final adapter = _ScriptedAdapter(error: responseError(500));
      final rxNet = await initAdapter(adapter, 'retry_5xx.db');

      final result = await rxNet
          .getRequest()
          .setPath('/retry-5xx')
          .setRetryCount(2, interval: Duration.zero)
          .request();

      expect(adapter.calls, 3);
      expect(result.isError, isTrue);
    });

    test('GET does not retry client errors such as 404', () async {
      final adapter = _ScriptedAdapter(error: responseError(404));
      final rxNet = await initAdapter(adapter, 'retry_404.db');

      final result = await rxNet
          .getRequest()
          .setPath('/retry-404')
          .setRetryCount(2, interval: Duration.zero)
          .request();

      expect(adapter.calls, 1);
      expect(result.isError, isTrue);
    });

    test('GET retries 429 rate limit responses', () async {
      final adapter = _ScriptedAdapter(error: responseError(429));
      final rxNet = await initAdapter(adapter, 'retry_429.db');

      await rxNet
          .getRequest()
          .setPath('/retry-429')
          .setRetryCount(2, interval: Duration.zero)
          .request();

      expect(adapter.calls, 3);
    });

    test('POST is not retried by default to avoid duplicate side effects',
        () async {
      final adapter = _ScriptedAdapter(error: responseError(500));
      final rxNet = await initAdapter(adapter, 'retry_post.db');

      final result = await rxNet
          .postRequest()
          .setPath('/retry-post')
          .setRetryCount(2, interval: Duration.zero)
          .request();

      expect(adapter.calls, 1);
      expect(result.isError, isTrue);
    });

    test('POST can be retried when retryOnNonIdempotent is enabled', () async {
      final adapter = _ScriptedAdapter(error: responseError(500));
      final rxNet = await initAdapter(adapter, 'retry_post_opt_in.db');

      await rxNet
          .postRequest()
          .setPath('/retry-post')
          .setRetryPolicy(
            RetryPolicy.fixed(
              maxRetries: 2,
              interval: Duration.zero,
              retryOnNonIdempotent: true,
            ),
          )
          .request();

      expect(adapter.calls, 3);
    });

    test('cancelled requests are never retried', () async {
      final adapter = _ScriptedAdapter(
        error: AdapterException(
          message: 'cancelled',
          type: AdapterExceptionType.cancel,
        ),
      );
      final rxNet = await initAdapter(adapter, 'retry_cancel.db');

      final result = await rxNet
          .getRequest()
          .setPath('/retry-cancel')
          .setRetryCount(2, interval: Duration.zero)
          .request();

      expect(adapter.calls, 1);
      expect(result.error, isA<CancellationException>());
    });

    test('unknown errors are not retried', () async {
      final adapter = _ScriptedAdapter(
        error: AdapterException(
          message: 'weird',
          type: AdapterExceptionType.unknown,
        ),
      );
      final rxNet = await initAdapter(adapter, 'retry_unknown.db');

      await rxNet
          .getRequest()
          .setPath('/retry-unknown')
          .setRetryCount(2, interval: Duration.zero)
          .request();

      expect(adapter.calls, 1);
    });

    test('callback API only receives the final failure once', () async {
      final adapter = _ScriptedAdapter(error: responseError(503));
      final rxNet = await initAdapter(adapter, 'retry_callback.db');

      var successCount = 0;
      var failureCount = 0;
      final done = Completer<void>();

      rxNet
          .getRequest()
          .setPath('/retry-callback')
          .setRetryCount(2, interval: Duration.zero)
          .execute(
            success: (_, __) => successCount++,
            failure: (_) => failureCount++,
            completed: done.complete,
          );

      await done.future.timeout(const Duration(seconds: 5));

      expect(adapter.calls, 3);
      expect(successCount, 0);
      expect(failureCount, 1);
    });
  });

  group('BuildRequest cache data type guard (P1)', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rxnet_cache_guard_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('binary responses succeed without being json-encoded into cache',
        () async {
      final adapter = _BytesAdapter();
      final rxNet = RxNet.create();
      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://example.com',
          adapter: adapter,
          cachePath: tempDir.path,
          databaseName: 'cache_bytes.db',
          cacheMode: CacheMode.FIRST_USE_CACHE_THEN_REQUEST,
        ),
      );
      addTearDown(() => rxNet.getDatabase()?.closeInstance());

      final result = await rxNet
          .getRequest()
          .setPath('/bytes')
          .setResponseType(ResponseType.bytes)
          .setCacheMode(CacheMode.FIRST_USE_CACHE_THEN_REQUEST)
          .request();

      expect(result.isSuccess, isTrue);
      expect(result.value, isA<Uint8List>());
      expect(result.value, [1, 2, 3, 4]);
      expect(await rxNet.cacheManager.getAllKeys(), isEmpty);
    });
  });

  group('BuildRequest REQUEST_FAILED_READ_CACHE semantics (P1)', () {
    late Directory tempDir;
    late MockAdapter adapter;
    late RxNet rxNet;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('rxnet_failed_cache_');
      adapter = MockAdapter();
      rxNet = RxNet.create();
      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://example.com',
          adapter: adapter,
          cachePath: tempDir.path,
          databaseName: 'failed_cache.db',
          cacheMode: CacheMode.ONLY_REQUEST,
        ),
      );
      addTearDown(() => rxNet.getDatabase()?.closeInstance());
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    Future<(int, int)> runCacheMode(String path) async {
      var successCount = 0;
      var failureCount = 0;
      final done = Completer<void>();

      rxNet
          .getRequest()
          .setPath(path)
          .setCacheMode(CacheMode.REQUEST_FAILED_READ_CACHE)
          .execute(
            success: (_, __) => successCount++,
            failure: (_) => failureCount++,
            completed: done.complete,
          );

      await done.future.timeout(const Duration(seconds: 5));
      return (successCount, failureCount);
    }

    test('network success emits a single network success', () async {
      final counts = await runCacheMode('/ok');

      expect(counts.$1, 1);
      expect(counts.$2, 0);
    });

    test('network failure falls back to cache without emitting an error first',
        () async {
      // 先用同样的 path 写入缓存。
      await rxNet
          .getRequest()
          .setPath('/cached-fallback')
          .setCacheMode(CacheMode.FIRST_USE_CACHE_THEN_REQUEST)
          .request();
      expect(await rxNet.cacheManager.getAllKeys(), isNotEmpty);

      adapter.setMockError(
        '/cached-fallback',
        AdapterException(
          message: 'server down',
          type: AdapterExceptionType.response,
          statusCode: 500,
        ),
      );

      final counts = await runCacheMode('/cached-fallback');

      expect(counts.$1, 1);
      expect(counts.$2, 0);
    });

    test('network failure without cache emits exactly one failure', () async {
      adapter.setMockError(
        '/no-cache',
        AdapterException(
          message: 'server down',
          type: AdapterExceptionType.response,
          statusCode: 500,
        ),
      );

      final counts = await runCacheMode('/no-cache');

      expect(counts.$1, 0);
      expect(counts.$2, 1);
    });
  });
}

class _FlakyAdapter implements NetworkAdapter {
  _FlakyAdapter({required this.failures});

  final int failures;
  int calls = 0;

  @override
  Future<AdapterResponse> request(AdapterRequest request) async {
    calls++;
    if (calls <= failures) {
      throw AdapterException(
        message: 'temporary failure',
        type: AdapterExceptionType.connectionError,
      );
    }
    return AdapterResponse(
      statusCode: 200,
      data: {'ok': true},
      headers: const {},
      request: request,
    );
  }

  @override
  Future<AdapterResponse> download(
    AdapterRequest request,
    String savePath, {
    ProgressCallback? onProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdapterResponse> upload(
    AdapterRequest request, {
    ProgressCallback? onProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  void cancel(CancelToken token) {}

  @override
  void addInterceptor(AdapterInterceptor interceptor) {}

  @override
  void removeInterceptor(AdapterInterceptor interceptor) {}

  @override
  String get name => 'FlakyAdapter';

  @override
  String get version => '1.0.0';

  @override
  void setBaseUrl(String url) {}

  @override
  void applyBaseOptions(AdapterBaseOptions options) {}
}
/// 每次调用都抛出同一个错误，用于验证重试过滤逻辑。
class _ScriptedAdapter implements NetworkAdapter {
  _ScriptedAdapter({required this.error});

  final AdapterException error;
  int calls = 0;

  @override
  Future<AdapterResponse> request(AdapterRequest request) async {
    calls++;
    throw error;
  }

  @override
  Future<AdapterResponse> download(
    AdapterRequest request,
    String savePath, {
    ProgressCallback? onProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdapterResponse> upload(
    AdapterRequest request, {
    ProgressCallback? onProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  void cancel(CancelToken token) {}

  @override
  void addInterceptor(AdapterInterceptor interceptor) {}

  @override
  void removeInterceptor(AdapterInterceptor interceptor) {}

  @override
  String get name => 'ScriptedAdapter';

  @override
  String get version => '1.0.0';

  @override
  void setBaseUrl(String url) {}

  @override
  void applyBaseOptions(AdapterBaseOptions options) {}
}

/// 返回二进制响应，用于验证不可 JSON 序列化的数据不会导致缓存写入失败。
class _BytesAdapter implements NetworkAdapter {
  @override
  Future<AdapterResponse> request(AdapterRequest request) async {
    return AdapterResponse(
      statusCode: 200,
      data: Uint8List.fromList([1, 2, 3, 4]),
      headers: const {},
      request: request,
    );
  }

  @override
  Future<AdapterResponse> download(
    AdapterRequest request,
    String savePath, {
    ProgressCallback? onProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<AdapterResponse> upload(
    AdapterRequest request, {
    ProgressCallback? onProgress,
  }) {
    throw UnimplementedError();
  }

  @override
  void cancel(CancelToken token) {}

  @override
  void addInterceptor(AdapterInterceptor interceptor) {}

  @override
  void removeInterceptor(AdapterInterceptor interceptor) {}

  @override
  String get name => 'BytesAdapter';

  @override
  String get version => '1.0.0';

  @override
  void setBaseUrl(String url) {}

  @override
  void applyBaseOptions(AdapterBaseOptions options) {}
}