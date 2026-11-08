import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('ThrottleInterceptor', () {
    late ThrottleInterceptor interceptor;

    setUp(() {
      interceptor = ThrottleInterceptor(duration: Duration(milliseconds: 200));
    });

    tearDown(() {
      interceptor.clearAll();
    });

    AdapterRequest makeRequest({String path = '/api/test'}) {
      return AdapterRequest(
        baseUrl: 'https://example.com',
        path: path,
        method: HttpMethod.GET,
      );
    }

    test('first request passes through', () {
      final handler = _MockHandler();
      interceptor.onRequest(makeRequest(), handler);
      expect(handler.nextCalled, isTrue);
      expect(handler.rejected, isFalse);
    });

    test('request within throttle window is rejected', () {
      final h1 = _MockHandler();
      final h2 = _MockHandler();
      interceptor.onRequest(makeRequest(), h1);
      interceptor.onRequest(makeRequest(), h2);
      expect(h1.nextCalled, isTrue);
      expect(h2.rejected, isTrue);
    });

    test('request after throttle window passes', () async {
      final h1 = _MockHandler();
      interceptor.onRequest(makeRequest(), h1);
      await Future.delayed(Duration(milliseconds: 250));
      final h2 = _MockHandler();
      interceptor.onRequest(makeRequest(), h2);
      expect(h2.nextCalled, isTrue);
    });

    test('different paths are throttled independently', () {
      final h1 = _MockHandler();
      final h2 = _MockHandler();
      interceptor.onRequest(makeRequest(path: '/api/a'), h1);
      interceptor.onRequest(makeRequest(path: '/api/b'), h2);
      expect(h1.nextCalled, isTrue);
      expect(h2.nextCalled, isTrue);
    });

    test('clearAll resets throttle state', () {
      final h1 = _MockHandler();
      interceptor.onRequest(makeRequest(), h1);
      interceptor.clearAll();
      final h2 = _MockHandler();
      interceptor.onRequest(makeRequest(), h2);
      expect(h2.nextCalled, isTrue);
    });

    test('maxEntries evicts the oldest record when the map is full', () {
      final throttler = ThrottleInterceptor(
        duration: const Duration(seconds: 10),
        maxEntries: 2,
      );
      addTearDown(throttler.clearAll);

      throttler.onRequest(makeRequest(path: '/a'), _MockHandler());
      throttler.onRequest(makeRequest(path: '/b'), _MockHandler());

      // 第 3 个 key 触发淘汰最旧的 /a
      final h3 = _MockHandler();
      throttler.onRequest(makeRequest(path: '/c'), h3);
      expect(h3.nextCalled, isTrue);

      // /a 已被淘汰，可再次通过
      final ha = _MockHandler();
      throttler.onRequest(makeRequest(path: '/a'), ha);
      expect(ha.nextCalled, isTrue);

      // /c 仍在窗口内，被节流
      final hc = _MockHandler();
      throttler.onRequest(makeRequest(path: '/c'), hc);
      expect(hc.rejected, isTrue);
    });

    test('maxEntries prunes expired records before evicting the oldest',
        () async {
      final throttler = ThrottleInterceptor(
        duration: const Duration(milliseconds: 50),
        maxEntries: 2,
      );
      addTearDown(throttler.clearAll);

      throttler.onRequest(makeRequest(path: '/a'), _MockHandler());
      throttler.onRequest(makeRequest(path: '/b'), _MockHandler());

      await Future<void>.delayed(const Duration(milliseconds: 80));

      final hc = _MockHandler();
      throttler.onRequest(makeRequest(path: '/c'), hc);
      expect(hc.nextCalled, isTrue);

      // /a、/b 已过期，不应再被节流
      final ha = _MockHandler();
      final hb = _MockHandler();
      throttler.onRequest(makeRequest(path: '/a'), ha);
      throttler.onRequest(makeRequest(path: '/b'), hb);
      expect(ha.nextCalled, isTrue);
      expect(hb.nextCalled, isTrue);
    });

    test('default maxEntries is 1000', () {
      expect(ThrottleInterceptor().maxEntries, 1000);
    });
  });
}

class _MockHandler implements RequestInterceptorHandler {
  bool nextCalled = false;
  bool rejected = false;

  @override
  void next(AdapterRequest request) => nextCalled = true;

  @override
  void reject(AdapterException error) => rejected = true;

  @override
  bool get isCompleted => nextCalled || rejected;

  @override
  AdapterRequest? get modifiedRequest => null;

  @override
  AdapterException? get rejectedError => null;

  @override
  void resolve(AdapterResponse response) {}

  @override
  AdapterResponse? get resolvedResponse => null;
}

