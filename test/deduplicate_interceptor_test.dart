import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('DeduplicateInterceptor', () {
    late DeduplicateInterceptor interceptor;

    setUp(() {
      interceptor = DeduplicateInterceptor(duration: Duration(milliseconds: 200));
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
      final handler = _MockRequestHandler();
      interceptor.onRequest(_makeRequest(), handler);
      expect(handler.nextCalled, isTrue);
      expect(handler.rejected, isFalse);
    });

    test('duplicate request within window is rejected', () {
      final handler1 = _MockRequestHandler();
      final handler2 = _MockRequestHandler();
      interceptor.onRequest(_makeRequest(), handler1);
      interceptor.onRequest(_makeRequest(), handler2);
      expect(handler1.nextCalled, isTrue);
      expect(handler2.rejected, isTrue);
    });

    test('same-path request after window passes through', () async {
      final handler1 = _MockRequestHandler();
      interceptor.onRequest(_makeRequest(), handler1);
      expect(handler1.nextCalled, isTrue);

      await Future.delayed(Duration(milliseconds: 300));

      final handler2 = _MockRequestHandler();
      interceptor.onRequest(_makeRequest(), handler2);
      expect(handler2.nextCalled, isTrue);
      expect(handler2.rejected, isFalse);
    });

    test('different path requests pass through simultaneously', () {
      final handler1 = _MockRequestHandler();
      final handler2 = _MockRequestHandler();
      interceptor.onRequest(_makeRequest(path: '/api/a'), handler1);
      interceptor.onRequest(_makeRequest(path: '/api/b'), handler2);
      expect(handler1.nextCalled, isTrue);
      expect(handler2.nextCalled, isTrue);
    });

    test('clearAll resets all pending requests', () {
      final handler1 = _MockRequestHandler();
      interceptor.onRequest(_makeRequest(), handler1);
      expect(handler1.nextCalled, isTrue);

      interceptor.clearAll();

      final handler2 = _MockRequestHandler();
      interceptor.onRequest(_makeRequest(), handler2);
      expect(handler2.nextCalled, isTrue);
      expect(handler2.rejected, isFalse);
    });
  });
}

class _MockRequestHandler implements RequestInterceptorHandler {
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

