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

    AdapterRequest _makeRequest({String path = '/api/test'}) {
      return AdapterRequest(
        baseUrl: 'https://example.com',
        path: path,
        method: HttpMethod.GET,
      );
    }

    test('first request passes through', () {
      final handler = _MockHandler();
      interceptor.onRequest(_makeRequest(), handler);
      expect(handler.nextCalled, isTrue);
      expect(handler.rejected, isFalse);
    });

    test('request within throttle window is rejected', () {
      final h1 = _MockHandler();
      final h2 = _MockHandler();
      interceptor.onRequest(_makeRequest(), h1);
      interceptor.onRequest(_makeRequest(), h2);
      expect(h1.nextCalled, isTrue);
      expect(h2.rejected, isTrue);
    });

    test('request after throttle window passes', () async {
      final h1 = _MockHandler();
      interceptor.onRequest(_makeRequest(), h1);
      await Future.delayed(Duration(milliseconds: 250));
      final h2 = _MockHandler();
      interceptor.onRequest(_makeRequest(), h2);
      expect(h2.nextCalled, isTrue);
    });

    test('different paths are throttled independently', () {
      final h1 = _MockHandler();
      final h2 = _MockHandler();
      interceptor.onRequest(_makeRequest(path: '/api/a'), h1);
      interceptor.onRequest(_makeRequest(path: '/api/b'), h2);
      expect(h1.nextCalled, isTrue);
      expect(h2.nextCalled, isTrue);
    });

    test('clearAll resets throttle state', () {
      final h1 = _MockHandler();
      interceptor.onRequest(_makeRequest(), h1);
      interceptor.clearAll();
      final h2 = _MockHandler();
      interceptor.onRequest(_makeRequest(), h2);
      expect(h2.nextCalled, isTrue);
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

