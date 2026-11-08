import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/src/adapter/interceptor/token_refresh_interceptor.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_request.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_response.dart';
import 'package:rxnet_plus/src/adapter/exceptions/adapter_exception.dart';
import 'package:rxnet_plus/src/adapter/interceptor/adapter_interceptor.dart';
import 'package:rxnet_plus/src/type/http_method.dart';

void main() {
  group('TokenRefreshInterceptor', () {
    test('non-401 error passes through unchanged', () async {
      var refreshTokenCalled = false;
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async {
          refreshTokenCalled = true;
          return 'new_token';
        },
      );

      final request = _request();
      final handler = _MockErrorHandler();
      final error = AdapterException(
        message: 'Server error',
        statusCode: 500,
        type: AdapterExceptionType.response,
        response: _response(request, 500),
      );

      await interceptor.onError(error, handler);

      expect(handler.nextCalled, isTrue);
      expect(handler.retryRequest, isNull);
      expect(refreshTokenCalled, isFalse);
    });

    test('401 triggers token refresh and retry request', () async {
      String? newToken;
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async => 'refreshed_token',
        onTokenRefreshed: (token) => newToken = token,
        onRequestUpdated: (request, token) => request.copyWith(
          headers: {...request.headers, 'Authorization': 'Bearer $token'},
        ),
      );

      final request = _request();
      final handler = _MockErrorHandler();

      await interceptor.onError(_unauthorized(request), handler);

      expect(newToken, 'refreshed_token');
      expect(handler.nextCalled, isFalse);
      expect(handler.retryRequest, isNotNull);
      expect(
        handler.retryRequest!.headers['Authorization'],
        'Bearer refreshed_token',
      );
      expect(
        handler.retryRequest!.extra[TokenRefreshInterceptor.retryFlagKey],
        isTrue,
      );
    });

    test('custom isUnauthorized callback works', () async {
      var refreshTokenCalled = false;
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async {
          refreshTokenCalled = true;
          return 'new_token';
        },
        isUnauthorized: (error, request) => error.statusCode == 403,
      );

      final request = _request();
      final handler = _MockErrorHandler();
      final error = AdapterException(
        message: 'Forbidden',
        statusCode: 403,
        type: AdapterExceptionType.response,
        response: _response(request, 403),
      );

      await interceptor.onError(error, handler);

      expect(refreshTokenCalled, isTrue);
      expect(handler.retryRequest, isNotNull);
    });

    test('concurrent refresh calls share the same token', () async {
      var refreshCount = 0;
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async {
          refreshCount++;
          await Future.delayed(const Duration(milliseconds: 50));
          return 'token_$refreshCount';
        },
      );

      final request1 = _request(path: '/a');
      final request2 = _request(path: '/b');
      final handler1 = _MockErrorHandler();
      final handler2 = _MockErrorHandler();

      await Future.wait([
        interceptor.onError(_unauthorized(request1), handler1),
        interceptor.onError(_unauthorized(request2), handler2),
      ]);

      expect(refreshCount, 1);
      expect(handler1.retryRequest, isNotNull);
      expect(handler2.retryRequest, isNotNull);
    });

    test('token refresh failure calls onTokenRefreshFailed and passes through',
        () async {
      Object? capturedError;
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async => throw Exception('Network error'),
        onTokenRefreshFailed: (error) => capturedError = error,
      );

      final request = _request();
      final handler = _MockErrorHandler();

      await interceptor.onError(_unauthorized(request), handler);

      expect(capturedError, isNotNull);
      expect(capturedError.toString(), contains('Network error'));
      expect(handler.nextCalled, isTrue);
      expect(handler.retryRequest, isNull);
    });

    test('already retried request does not refresh again', () async {
      var refreshCount = 0;
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async {
          refreshCount++;
          return 'new_token';
        },
      );

      final request = _request(extra: {
        TokenRefreshInterceptor.retryFlagKey: true,
      });
      final handler = _MockErrorHandler();

      await interceptor.onError(_unauthorized(request), handler);

      expect(refreshCount, 0);
      expect(handler.nextCalled, isTrue);
      expect(handler.retryRequest, isNull);
    });

    test('lastRefreshTime is updated after refresh', () async {
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async => 'token',
      );

      expect(interceptor.lastRefreshTime, isNull);

      final request = _request();
      final handler = _MockErrorHandler();

      await interceptor.onError(_unauthorized(request), handler);

      expect(interceptor.lastRefreshTime, isNotNull);
    });
  });
}

AdapterRequest _request({
  String path = '/protected',
  Map<String, dynamic> extra = const {},
}) {
  return AdapterRequest(
    baseUrl: 'https://example.com',
    path: path,
    method: HttpMethod.GET,
    extra: extra,
  );
}

AdapterResponse _response(AdapterRequest request, int statusCode) {
  return AdapterResponse(
    statusCode: statusCode,
    headers: const {},
    request: request,
  );
}

AdapterException _unauthorized(AdapterRequest request) {
  return AdapterException(
    message: 'Unauthorized',
    statusCode: 401,
    type: AdapterExceptionType.response,
    response: _response(request, 401),
  );
}

class _MockErrorHandler implements ErrorInterceptorHandler {
  bool nextCalled = false;
  AdapterRequest? retryRequestValue;
  AdapterResponse? resolveResponse;

  @override
  void next(AdapterException error) => nextCalled = true;

  @override
  void resolve(AdapterResponse response) => resolveResponse = response;

  @override
  void retry(AdapterRequest request) => retryRequestValue = request;

  @override
  bool get isCompleted =>
      nextCalled || resolveResponse != null || retryRequestValue != null;

  @override
  AdapterException? get modifiedError => null;

  @override
  AdapterResponse? get resolvedResponse => resolveResponse;

  @override
  AdapterRequest? get retryRequest => retryRequestValue;
}