import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';


import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('default timeouts', () {
    test('DioAdapter created with safe default timeouts', () {
      final adapter = DioAdapter();

      expect(
        adapter.dio.options.connectTimeout,
        AdapterBaseOptions.defaultConnectTimeout,
      );
      expect(
        adapter.dio.options.receiveTimeout,
        AdapterBaseOptions.defaultReceiveTimeout,
      );
      expect(
        adapter.dio.options.sendTimeout,
        AdapterBaseOptions.defaultSendTimeout,
      );
    });

    test('DioAdapter honors request-level connectTimeout', () async {
      final dio = Dio();
      final capture = _CapturingHttpClientAdapter();
      dio.httpClientAdapter = capture;
      final adapter = DioAdapter(dio: dio);

      final response = await adapter.request(
        AdapterRequest(
          baseUrl: 'https://example.com',
          path: '/timeout',
          method: HttpMethod.GET,
          connectTimeout: const Duration(seconds: 3),
        ),
      );

      expect(response.statusCode, 200);
      expect(capture.lastOptions, isNotNull);
      expect(capture.lastOptions!.connectTimeout, const Duration(seconds: 3));
    });
  });

  group('HttpAdapter request-level timeouts', () {
    late HttpServer server;

    tearDown(() async {
      await server.close(force: true);
    });

    test('receiveTimeout aborts a slow response body', () async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        try {
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"ok":true}');
          await request.response.flush();
          await Future.delayed(const Duration(milliseconds: 300));
          await request.response.close();
        } catch (_) {
          // Client may have disconnected after its timeout.
        }
      });

      final adapter = HttpAdapter();

      await expectLater(
        adapter.request(
          AdapterRequest(
            baseUrl: 'http://127.0.0.1:${server.port}',
            path: '/slow',
            method: HttpMethod.GET,
            receiveTimeout: const Duration(milliseconds: 50),
          ),
        ),
        throwsA(
          isA<AdapterException>().having(
            (error) => error.type,
            'type',
            AdapterExceptionType.receiveTimeout,
          ),
        ),
      );
    });
  });

  group('TokenRefreshInterceptor retries through HttpAdapter', () {
    late HttpServer server;
    late List<String?> authorizationHeaders;

    tearDown(() async {
      await server.close(force: true);
    });

    test('401 is refreshed and the request is actually retried', () async {
      authorizationHeaders = [];
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;

      server.listen((request) async {
        requestCount++;
        authorizationHeaders.add(request.headers.value('authorization'));

        request.response.headers.contentType = ContentType.json;
        request.response.statusCode = requestCount == 1 ? 401 : 200;
        request.response.write(jsonEncode({'request': requestCount}));
        await request.response.close();
      });

      final adapter = HttpAdapter();
      adapter.addInterceptor(
        TokenRefreshInterceptor(
          tokenProvider: () async => 'new-token',
          onRequestUpdated: (request, token) => request.copyWith(
            headers: {
              ...request.headers,
              'Authorization': 'Bearer $token',
            },
          ),
        ),
      );

      final response = await adapter.request(
        AdapterRequest(
          baseUrl: 'http://127.0.0.1:${server.port}',
          path: '/secure',
          method: HttpMethod.GET,
          headers: const {'Authorization': 'Bearer old'},
        ),
      );

      expect(response.statusCode, 200);
      expect(requestCount, 2);
      expect(authorizationHeaders, ['Bearer old', 'Bearer new-token']);
    });
  });
}

class _CapturingHttpClientAdapter implements HttpClientAdapter {
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode({'ok': true}),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}