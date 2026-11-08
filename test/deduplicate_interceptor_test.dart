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

    AdapterRequest makeRequest({
      String path = '/api/test',
      Map<String, dynamic> queryParams = const {},
      Map<String, dynamic> pathParams = const {},
      Map<String, dynamic> bodyParams = const {},
    }) {
      return AdapterRequest(
        baseUrl: 'https://example.com',
        path: path,
        method: HttpMethod.GET,
        queryParams: queryParams,
        pathParams: pathParams,
        bodyParams: bodyParams,
      );
    }

    test('first request passes through', () {
      final handler = _MockRequestHandler();
      interceptor.onRequest(makeRequest(), handler);
      expect(handler.nextCalled, isTrue);
      expect(handler.rejected, isFalse);
    });

    test('duplicate request within window is rejected', () {
      final handler1 = _MockRequestHandler();
      final handler2 = _MockRequestHandler();
      interceptor.onRequest(makeRequest(), handler1);
      interceptor.onRequest(makeRequest(), handler2);
      expect(handler1.nextCalled, isTrue);
      expect(handler2.rejected, isTrue);
    });

    test('same-path request after window passes through', () async {
      final handler1 = _MockRequestHandler();
      interceptor.onRequest(makeRequest(), handler1);
      expect(handler1.nextCalled, isTrue);

      await Future.delayed(Duration(milliseconds: 300));

      final handler2 = _MockRequestHandler();
      interceptor.onRequest(makeRequest(), handler2);
      expect(handler2.nextCalled, isTrue);
      expect(handler2.rejected, isFalse);
    });

    test('different path requests pass through simultaneously', () {
      final handler1 = _MockRequestHandler();
      final handler2 = _MockRequestHandler();
      interceptor.onRequest(makeRequest(path: '/api/a'), handler1);
      interceptor.onRequest(makeRequest(path: '/api/b'), handler2);
      expect(handler1.nextCalled, isTrue);
      expect(handler2.nextCalled, isTrue);
    });

    test('clearAll resets all pending requests', () {
      final handler1 = _MockRequestHandler();
      interceptor.onRequest(makeRequest(), handler1);
      expect(handler1.nextCalled, isTrue);

      interceptor.clearAll();

      final handler2 = _MockRequestHandler();
      interceptor.onRequest(makeRequest(), handler2);
      expect(handler2.nextCalled, isTrue);
      expect(handler2.rejected, isFalse);
    });

    test('same path with different bodyParams is not treated as duplicate', () {
      final handler1 = _MockRequestHandler();
      final handler2 = _MockRequestHandler();

      interceptor.onRequest(
        makeRequest(bodyParams: const {'id': 1}),
        handler1,
      );
      interceptor.onRequest(
        makeRequest(bodyParams: const {'id': 2}),
        handler2,
      );

      expect(handler1.nextCalled, isTrue);
      expect(handler1.rejected, isFalse);
      expect(handler2.nextCalled, isTrue);
      expect(handler2.rejected, isFalse);
    });

    test('same path with different pathParams is not treated as duplicate', () {
      final handler1 = _MockRequestHandler();
      final handler2 = _MockRequestHandler();

      interceptor.onRequest(
        makeRequest(path: '/api/users/{id}', pathParams: const {'id': '1'}),
        handler1,
      );
      interceptor.onRequest(
        makeRequest(path: '/api/users/{id}', pathParams: const {'id': '2'}),
        handler2,
      );

      expect(handler1.nextCalled, isTrue);
      expect(handler2.nextCalled, isTrue);
    });

    test('same path with different queryParams is not treated as duplicate', () {
      final handler1 = _MockRequestHandler();
      final handler2 = _MockRequestHandler();

      interceptor.onRequest(
        makeRequest(queryParams: const {'page': 1}),
        handler1,
      );
      interceptor.onRequest(
        makeRequest(queryParams: const {'page': 2}),
        handler2,
      );

      expect(handler1.nextCalled, isTrue);
      expect(handler2.nextCalled, isTrue);
    });

    test('identical request with reordered params is still deduplicated', () {
      final handler1 = _MockRequestHandler();
      final handler2 = _MockRequestHandler();

      interceptor.onRequest(
        makeRequest(bodyParams: const {'a': 1, 'b': 2}),
        handler1,
      );
      interceptor.onRequest(
        makeRequest(bodyParams: const {'b': 2, 'a': 1}),
        handler2,
      );

      expect(handler1.nextCalled, isTrue);
      expect(handler2.rejected, isTrue);
    });

    test('identical bodyParams request is still deduplicated', () {
      final handler1 = _MockRequestHandler();
      final handler2 = _MockRequestHandler();

      interceptor.onRequest(
        makeRequest(bodyParams: const {'id': 1}),
        handler1,
      );
      interceptor.onRequest(
        makeRequest(bodyParams: const {'id': 1}),
        handler2,
      );

      expect(handler1.nextCalled, isTrue);
      expect(handler2.rejected, isTrue);
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

