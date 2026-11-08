import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

AdapterRequest _getRequest({String path = '/resource'}) => AdapterRequest(
      baseUrl: 'https://example.com',
      path: path,
      method: HttpMethod.GET,
    );

void main() {
  group('DioAdapter validateStatus (P1)', () {
    test('honors AdapterBaseOptions.validateStatus', () async {
      final dio = Dio();
      dio.httpClientAdapter = _StaticAdapter(404);
      final adapter = DioAdapter(dio: dio);
      adapter.applyBaseOptions(
        AdapterBaseOptions(validateStatus: (statusCode) => statusCode < 500),
      );

      final response = await adapter.request(_getRequest());

      expect(response.statusCode, 404);
      expect(response.successOverride, isTrue);
      expect(response.isSuccess, isTrue);
    });

    test('rejects non-2xx status by default', () async {
      final dio = Dio();
      dio.httpClientAdapter = _StaticAdapter(500);
      final adapter = DioAdapter(dio: dio);

      await expectLater(
        adapter.request(_getRequest()),
        throwsA(
          isA<AdapterException>()
              .having(
                (error) => error.type,
                'type',
                AdapterExceptionType.response,
              )
              .having((error) => error.statusCode, 'statusCode', 500),
        ),
      );
    });
  });

  group('DioAdapter interceptor behavior (P1)', () {
    test('preserves AdapterException raised by a response interceptor',
        () async {
      final dio = Dio();
      dio.httpClientAdapter = _StaticAdapter(200);
      final adapter = DioAdapter(dio: dio);
      adapter.addInterceptor(_ThrowingResponseInterceptor());

      await expectLater(
        adapter.request(_getRequest()),
        throwsA(
          isA<AdapterException>()
              .having(
                (error) => error.type,
                'type',
                AdapterExceptionType.response,
              )
              .having((error) => error.statusCode, 'statusCode', 403),
        ),
      );
    });

    test('transforms interceptor exceptions through onError handlers', () async {
      final dio = Dio();
      dio.httpClientAdapter = _StaticAdapter(200);
      final adapter = DioAdapter(dio: dio);
      adapter.addInterceptor(_ThrowingResponseInterceptor());
      adapter.addInterceptor(_ErrorTaggingInterceptor());

      await expectLater(
        adapter.request(_getRequest()),
        throwsA(
          isA<AdapterException>().having(
            (error) => error.message,
            'message',
            'tagged-by-error-interceptor',
          ),
        ),
      );
    });
  });

  group('DioAdapter multipart body (P1)', () {
    test('converts dart:io File into a multipart FormData body', () async {
      final tempDir = Directory.systemTemp.createTempSync('rxnet_dio_file_');
      addTearDown(() {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });
      final file = File('${tempDir.path}/avatar.txt')
        ..writeAsStringSync('avatar-bytes');

      final capture = _CapturingAdapter();
      final dio = Dio();
      dio.httpClientAdapter = capture;
      final adapter = DioAdapter(dio: dio);

      final response = await adapter.request(
        AdapterRequest(
          baseUrl: 'https://example.com',
          path: '/upload',
          method: HttpMethod.POST,
          contentType: 'multipart/form-data',
          bodyParams: {'file': file},
        ),
      );

      expect(response.statusCode, 200);
      final body = latin1.decode(capture.requestBytes);
      expect(capture.lastOptions?.contentType, startsWith('multipart/form-data'));
      expect(body, contains('avatar.txt'));
      expect(body, contains('avatar-bytes'));
    });
  });

  group('DioAdapter download/upload interceptors (P1)', () {
    late HttpServer server;
    late Directory tempDir;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('rxnet_dio_io_');
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        request.response.headers.contentType = ContentType.text;
        request.response.write('downloaded-content');
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
      final adapter = DioAdapter();
      final interceptor = _CountingResponseInterceptor();
      adapter.addInterceptor(interceptor);

      final savePath = '${tempDir.path}/download.txt';
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
      expect(File(savePath).readAsStringSync(), 'downloaded-content');
    });

    test('upload executes response interceptors', () async {
      final dio = Dio();
      dio.httpClientAdapter = _CapturingAdapter();
      final adapter = DioAdapter(dio: dio);
      final interceptor = _CountingResponseInterceptor();
      adapter.addInterceptor(interceptor);

      final response = await adapter.upload(
        AdapterRequest(
          baseUrl: 'https://example.com',
          path: '/upload',
          method: HttpMethod.POST,
          bodyParams: const {'name': 'avatar'},
        ),
      );

      expect(response.statusCode, 200);
      expect(interceptor.count, 1);
    });
  });
}

class _StaticAdapter implements HttpClientAdapter {
  _StaticAdapter(this.statusCode);

  final int statusCode;
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    return ResponseBody.fromString(
      jsonEncode({'status': statusCode}),
      statusCode,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

class _CapturingAdapter implements HttpClientAdapter {
  Uint8List requestBytes = Uint8List(0);
  RequestOptions? lastOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    lastOptions = options;
    final chunks = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        chunks.addAll(chunk);
      }
    }
    requestBytes = Uint8List.fromList(chunks);
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

class _ThrowingResponseInterceptor extends AdapterInterceptor {
  @override
  void onResponse(
    AdapterResponse response,
    ResponseInterceptorHandler handler,
  ) {
    throw AdapterException(
      message: 'blocked by interceptor',
      type: AdapterExceptionType.response,
      statusCode: 403,
    );
  }
}

class _ErrorTaggingInterceptor extends AdapterInterceptor {
  @override
  void onError(AdapterException error, ErrorInterceptorHandler handler) {
    handler.next(
      AdapterException(
        message: 'tagged-by-error-interceptor',
        type: error.type,
        statusCode: error.statusCode,
      ),
    );
  }
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