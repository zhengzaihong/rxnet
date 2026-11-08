import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('HttpAdapter validateStatus (P1)', () {
    late HttpServer server;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.statusCode = 404;
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode({'ok': false}));
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('honors AdapterBaseOptions.validateStatus', () async {
      final adapter = HttpAdapter();
      adapter.applyBaseOptions(
        AdapterBaseOptions(validateStatus: (statusCode) => statusCode < 500),
      );

      final response = await adapter.request(
        AdapterRequest(
          baseUrl: 'http://127.0.0.1:${server.port}',
          path: '/error',
          method: HttpMethod.GET,
        ),
      );

      expect(response.statusCode, 404);
      expect(response.successOverride, isTrue);
      expect(response.isSuccess, isTrue);
    });

    test('keeps default 2xx semantics without a validator', () async {
      final adapter = HttpAdapter();

      await expectLater(
        adapter.request(
          AdapterRequest(
            baseUrl: 'http://127.0.0.1:${server.port}',
            path: '/error',
            method: HttpMethod.GET,
          ),
        ),
        throwsA(
          isA<AdapterException>()
              .having(
                (error) => error.type,
                'type',
                AdapterExceptionType.response,
              )
              .having((error) => error.statusCode, 'statusCode', 404),
        ),
      );
    });
  });

  group('HttpAdapter interceptors on download/upload (P1)', () {
    late HttpServer server;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('rxnet_http_io_');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.headers.contentType = ContentType.text;
        if (request.method == 'POST') {
          await request.drain<void>();
          request.response.write('upload-ok');
        } else {
          request.response.write('download-content');
        }
        await request.response.close();
      });
    });

    tearDown(() async {
      await server.close(force: true);
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('download executes response interceptors', () async {
      final adapter = HttpAdapter();
      final interceptor = _CountingResponseInterceptor();
      adapter.addInterceptor(interceptor);

      final savePath = '${tempDir.path}/http-download.txt';
      final response = await adapter.download(
        AdapterRequest(
          baseUrl: 'http://127.0.0.1:${server.port}',
          path: '/file',
          method: HttpMethod.GET,
        ),
        savePath,
      );

      expect(response.statusCode, 200);
      expect(interceptor.count, 1);
      expect(File(savePath).readAsStringSync(), 'download-content');
    });

    test('upload executes response interceptors', () async {
      final adapter = HttpAdapter();
      final interceptor = _CountingResponseInterceptor();
      adapter.addInterceptor(interceptor);

      final response = await adapter.upload(
        AdapterRequest(
          baseUrl: 'http://127.0.0.1:${server.port}',
          path: '/upload',
          method: HttpMethod.POST,
          bodyParams: const {'name': 'avatar'},
        ),
      );

      expect(response.statusCode, 200);
      expect(interceptor.count, 1);
    });
  });

  group('HttpAdapter request-level timeouts (P1)', () {
    late HttpServer server;

    setUp(() async {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    });

    tearDown(() async {
      await server.close(force: true);
    });

    test('request-level receiveTimeout overrides base options', () async {
      server.listen((request) async {
        try {
          request.response.headers.contentType = ContentType.json;
          request.response.write('{"slow":true}');
          await request.response.flush();
          await Future.delayed(const Duration(milliseconds: 300));
          await request.response.close();
        } catch (_) {
          // Client disconnected after timeout.
        }
      });

      final adapter = HttpAdapter();
      adapter.applyBaseOptions(
        const AdapterBaseOptions(receiveTimeout: Duration(seconds: 10)),
      );

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

    test('request-level sendTimeout is applied to the send phase', () async {
      // 服务端不读取请求体，使客户端发送阶段阻塞。
      server.listen((request) async {
        await Future.delayed(const Duration(seconds: 1));
        request.response.statusCode = 200;
        await request.response.close();
      });

      final adapter = HttpAdapter();
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);

      await expectLater(
        adapter.request(
          AdapterRequest(
            baseUrl: 'http://127.0.0.1:${server.port}',
            path: '/upload',
            method: HttpMethod.POST,
            rawBody: controller.stream,
            sendTimeout: const Duration(milliseconds: 50),
          ),
        ),
        throwsA(
          isA<AdapterException>().having(
            (error) => error.type,
            'type',
            AdapterExceptionType.sendTimeout,
          ),
        ),
      );
    });
  });
}

class _CountingResponseInterceptor extends AdapterInterceptor {
  int count = 0;

  @override
  void onResponse(
    AdapterResponse response,
    ResponseInterceptorHandler handler,
  ) {
    count++;
    handler.next(response);
  }
}