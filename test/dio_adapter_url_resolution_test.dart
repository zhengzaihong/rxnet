import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('DioAdapter URL resolution', () {
    late HttpServer server;
    late StreamSubscription<HttpRequest> serverSubscription;
    final requestedPaths = <String>[];

    setUp(() async {
      requestedPaths.clear();
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      serverSubscription = server.listen((request) async {
        requestedPaths.add(request.uri.path);

        if (request.uri.path == '/download/test.txt') {
          request.response.headers.contentType = ContentType.text;
          request.response.write('download-ok');
        } else {
          request.response.headers.contentType = ContentType.json;
          request.response.write(jsonEncode({
            'path': request.uri.path,
            'query': request.uri.queryParameters,
          }));
        }

        await request.response.close();
      });
    });

    tearDown(() async {
      await serverSubscription.cancel();
      await server.close(force: true);
    });

    test('request works without trailing slash on baseUrl', () async {
      final adapter = DioAdapter();
      adapter.addInterceptor(_PassthroughInterceptor());

      final response = await adapter.request(
        AdapterRequest(
          baseUrl: 'http://${server.address.host}:${server.port}',
          path: 'api/weather/city/{id}',
          pathParams: const {'id': '101030100'},
          method: HttpMethod.GET,
          queryParams: const {'source': 'test'},
        ),
      );

      expect(response.isSuccess, isTrue);
      expect(requestedPaths, contains('/api/weather/city/101030100'));
      expect(response.data['path'], '/api/weather/city/101030100');
      expect(response.data['query']['source'], 'test');
    });

    test('download works without trailing slash on baseUrl', () async {
      final adapter = DioAdapter();
      final tempDir = await Directory.systemTemp.createTemp('rxnet_dio_url_');
      final targetFile = File('${tempDir.path}${Platform.pathSeparator}test.txt');

      try {
        final response = await adapter.download(
          AdapterRequest(
            baseUrl: 'http://${server.address.host}:${server.port}',
            path: 'download/test.txt',
            method: HttpMethod.GET,
          ),
          targetFile.path,
        );

        expect(response.isSuccess, isTrue);
        expect(requestedPaths, contains('/download/test.txt'));
        expect(await targetFile.readAsString(), 'download-ok');
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    });
  });
}

class _PassthroughInterceptor extends AdapterInterceptor {
  @override
  void onRequest(
    AdapterRequest request,
    RequestInterceptorHandler handler,
  ) {
    handler.next(request);
  }
}
