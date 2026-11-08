import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('RxNet lifecycle', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('rxnet_lifecycle_');
    });

    tearDown(() {
      // Windows 下数据库文件句柄可能延迟释放，忽略删除失败。
      if (tempDir.existsSync()) {
        try {
          tempDir.deleteSync(recursive: true);
        } on FileSystemException {
          // ignore
        }
      }
    });

    test('dispose clears the adapter and closes a closable adapter', () async {
      final adapter = _TrackingAdapter();
      final rxNet = RxNet.create();

      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://lifecycle.test',
          adapter: adapter,
          cachePath: tempDir.path,
          databaseName: 'lifecycle_dispose.db',
        ),
      );

      expect(rxNet.getAdapter(), same(adapter));
      expect(adapter.setBaseUrlCalls, 1);

      await rxNet.disposeInstance();

      expect(rxNet.getAdapter(), isNull);
      expect(adapter.closeCalls, 1);
    });

    test('initNet works again after dispose', () async {
      final adapter = _TrackingAdapter();
      final rxNet = RxNet.create();

      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://lifecycle.test',
          adapter: adapter,
          cachePath: tempDir.path,
          databaseName: 'lifecycle_first.db',
        ),
      );

      await rxNet.disposeInstance();
      expect(rxNet.getAdapter(), isNull);

      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://lifecycle.test',
          adapter: adapter,
          cachePath: tempDir.path,
          databaseName: 'lifecycle_second.db',
        ),
      );

      expect(rxNet.getAdapter(), same(adapter));

      final result =
          await rxNet.getRequest().setPath('/after-dispose').request();

      expect(result.isSuccess, isTrue);
      expect((result.value as Map)['path'], '/after-dispose');

      await rxNet.disposeInstance();
    });

    test('repeated initNet with the same config does not re-add interceptors',
        () async {
      final adapter = _TrackingAdapter();
      final interceptor = _NoopInterceptor();
      final config = RxNetConfig(
        baseUrl: 'https://lifecycle.test',
        adapter: adapter,
        interceptors: [interceptor],
        cachePath: tempDir.path,
        databaseName: 'lifecycle_same_config.db',
      );
      final rxNet = RxNet.create();

      await rxNet.initNet(config: config);

      expect(adapter.addInterceptorCalls, 1);
      expect(adapter.interceptorCount, 1);

      // 相同 config 实例再次初始化应直接复用，不重复添加拦截器。
      await rxNet.initNet(config: config);

      expect(adapter.addInterceptorCalls, 1);
      expect(adapter.interceptorCount, 1);

      await rxNet.disposeInstance();
    });

    test('re-init with an equivalent config keeps a single interceptor copy',
        () async {
      final adapter = _TrackingAdapter();
      final interceptor = _NoopInterceptor();
      final rxNet = RxNet.create();

      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://lifecycle.test',
          adapter: adapter,
          interceptors: [interceptor],
          cachePath: tempDir.path,
          databaseName: 'lifecycle_reinit_a.db',
        ),
      );

      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://lifecycle.test',
          adapter: adapter,
          interceptors: [interceptor],
          cachePath: tempDir.path,
          databaseName: 'lifecycle_reinit_b.db',
        ),
      );

      expect(adapter.removeInterceptorCalls, 1);
      expect(adapter.addInterceptorCalls, 2);
      expect(adapter.interceptorCount, 1);

      await rxNet.disposeInstance();
    });
  });
}

class _NoopInterceptor extends AdapterInterceptor {}

class _TrackingAdapter implements NetworkAdapter, ClosableNetworkAdapter {
  int addInterceptorCalls = 0;
  int removeInterceptorCalls = 0;
  int closeCalls = 0;
  int setBaseUrlCalls = 0;
  final List<AdapterInterceptor> _interceptors = [];

  int get interceptorCount => _interceptors.length;

  @override
  Future<AdapterResponse> request(AdapterRequest request) async {
    return AdapterResponse(
      statusCode: 200,
      data: {'ok': true, 'path': request.path},
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
  void addInterceptor(AdapterInterceptor interceptor) {
    addInterceptorCalls++;
    _interceptors.add(interceptor);
  }

  @override
  void removeInterceptor(AdapterInterceptor interceptor) {
    removeInterceptorCalls++;
    _interceptors.remove(interceptor);
  }

  @override
  String get name => 'TrackingAdapter';

  @override
  String get version => '1.0.0';

  @override
  void setBaseUrl(String url) {
    setBaseUrlCalls++;
  }

  @override
  void applyBaseOptions(AdapterBaseOptions options) {}

  @override
  Future<void> close() async {
    closeCalls++;
  }
}