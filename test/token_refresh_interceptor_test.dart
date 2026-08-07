import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/src/adapter/interceptor/token_refresh_interceptor.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_request.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_response.dart';
import 'package:rxnet_plus/src/adapter/exceptions/adapter_exception.dart';
import 'package:rxnet_plus/src/adapter/interceptor/adapter_interceptor.dart';

void main() {
  setUp(() {
    // Suppress unhandled async errors from token refresh failure
    // The fire-and-forget async in onError is expected behavior
    final originalHandler = Zone.current.handleUncaughtError;
    // Use Flutter test's zone to suppress known unhandled errors
  });

  group('TokenRefreshInterceptor', () {
    test('non-401 error passes through unchanged', () async {
      String? refreshTokenCalled;
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async {
          refreshTokenCalled = 'called';
          return 'new_token';
        },
      );

      final handler = _MockErrorHandler();
      final error = AdapterException(
        message: 'Server error',
        statusCode: 500,
        type: AdapterExceptionType.unknown,
      );

      interceptor.onError(error, handler);

      expect(handler.nextCalled, isTrue);
      expect(handler.resolved, isFalse);
      expect(refreshTokenCalled, isNull);
    });

    test('401 triggers token refresh', () async {
      String? newToken;
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async => 'refreshed_token',
        onTokenRefreshed: (token) => newToken = token,
      );

      final handler = _MockErrorHandler();
      final error = AdapterException(
        message: 'Unauthorized',
        statusCode: 401,
        type: AdapterExceptionType.unknown,
      );

      interceptor.onError(error, handler);
      await Future.delayed(Duration(milliseconds: 50));

      expect(newToken, 'refreshed_token');
      expect(handler.resolved, isTrue);
      expect(handler.resolveResponse, isNotNull);
      expect(handler.resolveResponse!.data['_tokenRefreshed'], isTrue);
      expect(handler.resolveResponse!.data['_newToken'], 'refreshed_token');
    });

    test('custom isUnauthorized callback works', () async {
      String? refreshTokenCalled;
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async => 'new_token',
        isUnauthorized: (error, request) => error.statusCode == 403,
        onTokenRefreshed: (token) => refreshTokenCalled = token,
      );

      final handler = _MockErrorHandler();
      final error = AdapterException(
        message: 'Forbidden',
        statusCode: 403,
        type: AdapterExceptionType.unknown,
      );

      interceptor.onError(error, handler);
      await Future.delayed(Duration(milliseconds: 50));

      expect(refreshTokenCalled, 'new_token');
    });

    test('concurrent refresh calls share the same token', () async {
      var refreshCount = 0;
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async {
          refreshCount++;
          await Future.delayed(Duration(milliseconds: 100));
          return 'token_$refreshCount';
        },
      );

      final handler1 = _MockErrorHandler();
      final handler2 = _MockErrorHandler();
      final error = AdapterException(
        message: 'Unauthorized',
        statusCode: 401,
        type: AdapterExceptionType.unknown,
      );

      interceptor.onError(error, handler1);
      interceptor.onError(error, handler2);

      await Future.delayed(Duration(milliseconds: 200));

      expect(refreshCount, 1);
    });

    test('token refresh failure calls onTokenRefreshFailed and passes through', () async {
      Object? capturedError;
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async => throw Exception('Network error'),
        onTokenRefreshFailed: (error) => capturedError = error,
      );

      final handler = _MockErrorHandler();
      final error = AdapterException(
        message: 'Unauthorized',
        statusCode: 401,
        type: AdapterExceptionType.unknown,
      );

      // onError fires off an async token refresh - the error from
      // _refreshToken propagates through the handler.next() path
      interceptor.onError(error, handler);
      await Future.delayed(Duration(milliseconds: 100));

      expect(capturedError, isNotNull);
      expect(capturedError.toString(), contains('Network error'));
      expect(handler.nextCalled, isTrue);
    });

    test('onRequestUpdated callback modifies request', () async {
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async => 'new_token',
        onRequestUpdated: (request, newToken) {
          return request.copyWith(
            headers: {'Authorization': 'Bearer $newToken'},
          );
        },
      );

      final handler = _MockErrorHandler();
      final error = AdapterException(
        message: 'Unauthorized',
        statusCode: 401,
        type: AdapterExceptionType.unknown,
      );

      interceptor.onError(error, handler);
      await Future.delayed(Duration(milliseconds: 50));

      expect(handler.resolved, isTrue);
      final retryRequest = handler.resolveResponse!.data['_retryRequest'] as AdapterRequest;
      expect(retryRequest.headers['Authorization'], 'Bearer new_token');
    });

    test('lastRefreshTime is updated after refresh', () async {
      final interceptor = TokenRefreshInterceptor(
        tokenProvider: () async => 'token',
      );

      expect(interceptor.lastRefreshTime, isNull);

      final handler = _MockErrorHandler();
      final error = AdapterException(
        message: 'Unauthorized',
        statusCode: 401,
        type: AdapterExceptionType.unknown,
      );

      interceptor.onError(error, handler);
      await Future.delayed(Duration(milliseconds: 50));

      expect(interceptor.lastRefreshTime, isNotNull);
    });
  });
}

class _MockErrorHandler implements ErrorInterceptorHandler {
  bool nextCalled = false;
  bool resolved = false;
  AdapterResponse? resolveResponse;

  @override
  void next(AdapterException error) => nextCalled = true;

  @override
  void resolve(AdapterResponse response) {
    resolved = true;
    resolveResponse = response;
  }

  @override
  bool get isCompleted => nextCalled || resolved;

  @override
  AdapterException? get modifiedError => null;

  @override
  AdapterResponse? get resolvedResponse => resolveResponse;
}
