import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:dio/dio.dart' as dio;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:rxnet_plus/rxnet_lib.dart';
import 'package:rxnet_plus/utils/rx_net_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('breakPointDownload', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rxnet_breakpoint_');
    });

    tearDown(() async {
      await RxNetDataBase.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } on FileSystemException {
          // Database may still be releasing file handles on Windows.
        }
      }
    });

    test(
      'resumes with DioAdapter without manually setting ResponseType.stream',
      () async {
        final payload = utf8.encode('hello breakpoint download');
        final adapter = DioAdapter(
          dio: dio.Dio()
            ..httpClientAdapter = _FakeDioHttpClientAdapter((options) async {
              final rangeHeader =
                  options.headers[HttpHeaders.rangeHeader]?.toString();
              final start = rangeHeader == null
                  ? 0
                  : int.parse(
                      RegExp(r'bytes=(\d+)-')
                          .firstMatch(rangeHeader)!
                          .group(1)!,
                    );
              final body = payload.sublist(start);

              return dio.ResponseBody(
                _delayedUint8Chunks(body),
                start > 0 ? HttpStatus.partialContent : HttpStatus.ok,
                headers: <String, List<String>>{
                  HttpHeaders.contentTypeHeader: <String>[
                    ContentType.binary.mimeType,
                  ],
                  HttpHeaders.contentLengthHeader: <String>[
                    body.length.toString(),
                  ],
                  if (start > 0)
                    HttpHeaders.contentRangeHeader: <String>[
                      'bytes $start-${payload.length - 1}/${payload.length}',
                    ],
                },
              );
            }),
        );

        final api = RxNet.create();
        await api.initNet(
          baseUrl: 'https://unit.test',
          adapter: adapter,
          cachePath: tempDir.path,
        );

        final file = File(p.join(tempDir.path, 'dio_resume.bin'));
        await file.writeAsBytes(payload.sublist(0, 6));

        Object? failure;
        Object? successValue;
        int lastReceived = 0;
        int lastTotal = 0;
        final completed = Completer<void>();

        api.getRequest().setPath('/resume').breakPointDownload(
              savePath: file.path,
              onReceiveProgress: (received, total) {
                lastReceived = received;
                lastTotal = total;
              },
              success: (data, _) {
                successValue = data;
              },
              failure: (error) {
                failure = error;
              },
              completed: () {
                if (!completed.isCompleted) {
                  completed.complete();
                }
              },
            );

        await completed.future.timeout(const Duration(seconds: 5));

        expect(failure, isNull);
        expect(successValue, isA<File>());
        expect(await file.readAsBytes(), payload);
        expect(lastReceived, payload.length);
        expect(lastTotal, payload.length);
      },
    );

    test(
      'restarts cleanly when HttpAdapter receives a full response for a ranged request',
      () async {
        final payload = utf8.encode('0123456789abcdef');
        String? seenRangeHeader;

        final api = RxNet.create();
        await api.initNet(
          baseUrl: 'https://unit.test',
          adapter: HttpAdapter(
            client: _FakeStreamClient((request) async {
              seenRangeHeader = request.headers[HttpHeaders.rangeHeader];
              return http.StreamedResponse(
                _delayedByteChunks(payload),
                HttpStatus.ok,
                headers: <String, String>{
                  HttpHeaders.contentTypeHeader: ContentType.binary.mimeType,
                  HttpHeaders.contentLengthHeader: payload.length.toString(),
                },
              );
            }),
          ),
          cachePath: tempDir.path,
        );

        final file = File(p.join(tempDir.path, 'http_restart.bin'));
        await file.writeAsBytes(payload.sublist(0, 5));

        Object? failure;
        final completed = Completer<void>();

        api.getRequest().setPath('/restart').breakPointDownload(
              savePath: file.path,
              failure: (error) {
                failure = error;
              },
              completed: () {
                if (!completed.isCompleted) {
                  completed.complete();
                }
              },
            );

        await completed.future.timeout(const Duration(seconds: 5));

        expect(failure, isNull);
        expect(seenRangeHeader, 'bytes=5-');
        expect(await file.readAsBytes(), payload);
      },
    );
  });

  group('file transfer callbacks', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rxnet_transfer_');
    });

    tearDown(() async {
      await RxNetDataBase.close();
      await Future<void>.delayed(const Duration(milliseconds: 50));
      if (await tempDir.exists()) {
        try {
          await tempDir.delete(recursive: true);
        } on FileSystemException {
          // Database may still be releasing file handles on Windows.
        }
      }
    });

    test('download succeeds even when the adapter never emits progress',
        () async {
      final payload = utf8.encode('plain download payload');
      final adapter = _DownloadCallbackAdapter(
        onDownload: (request, savePath, onProgress) async {
          final file = File(savePath);
          if (!file.parent.existsSync()) {
            file.parent.createSync(recursive: true);
          }
          await file.writeAsBytes(payload);
          return AdapterResponse(
            statusCode: HttpStatus.ok,
            data: savePath,
            headers: const <String, List<String>>{},
            request: request,
          );
        },
      );

      final api = RxNet.create();
      await api.initNet(
        baseUrl: 'https://unit.test',
        adapter: adapter,
        cachePath: tempDir.path,
      );

      final savePath = p.join(tempDir.path, 'nested', 'download.bin');
      Object? failure;
      Object? successValue;
      final completed = Completer<void>();

      api.getRequest().setPath('/download').download(
            savePath: savePath,
            success: (data, _) {
              successValue = data;
            },
            failure: (error) {
              failure = error;
            },
            completed: () {
              if (!completed.isCompleted) {
                completed.complete();
              }
            },
          );

      await completed.future.timeout(const Duration(seconds: 5));

      expect(failure, isNull);
      expect(successValue, savePath);
      expect(await File(savePath).readAsBytes(), payload);
    });

    test(
      'breakPointUpload streams only the remaining bytes through HttpAdapter',
      () async {
        final payload = utf8.encode('abcdefghij');
        late Map<String, String> seenHeaders;
        late List<int> uploadedBytes;

        final api = RxNet.create();
        await api.initNet(
          baseUrl: 'https://unit.test',
          adapter: HttpAdapter(
            client: _FakeStreamClient((request) async {
              seenHeaders = request.headers.map(
                (key, value) => MapEntry(key.toLowerCase(), value),
              );
              uploadedBytes = await request.finalize().fold<List<int>>(<int>[],
                  (all, chunk) {
                all.addAll(chunk);
                return all;
              });

              return http.StreamedResponse(
                Stream<List<int>>.value(utf8.encode('{"ok":true}')),
                HttpStatus.ok,
                headers: <String, String>{
                  HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
                },
              );
            }),
          ),
          cachePath: tempDir.path,
        );

        final file = File(p.join(tempDir.path, 'resume_upload.bin'));
        await file.writeAsBytes(payload);

        Object? failure;
        Object? successValue;
        final progressEvents = <List<int>>[];
        final completed = Completer<void>();

        api.postRequest().setPath('/upload').breakPointUpload(
              filePath: file.path,
              start: 4,
              onSendProgress: (sent, total) {
                progressEvents.add(<int>[sent, total]);
              },
              success: (data, _) {
                successValue = data;
              },
              failure: (error) {
                failure = error;
              },
              completed: () {
                if (!completed.isCompleted) {
                  completed.complete();
                }
              },
            );

        await completed.future.timeout(const Duration(seconds: 5));

        expect(failure, isNull);
        expect(successValue, isA<File>());
        expect(uploadedBytes, payload.sublist(4));
        expect(seenHeaders[HttpHeaders.contentRangeHeader], 'bytes 4-9/10');
        expect(seenHeaders[HttpHeaders.contentLengthHeader], '6');
        expect(progressEvents.first, <int>[4, 10]);
        expect(progressEvents.last, <int>[10, 10]);
      },
    );
  });
}

Stream<Uint8List> _delayedUint8Chunks(List<int> bytes) async* {
  for (var index = 0; index < bytes.length; index += 3) {
    final end = (index + 3 < bytes.length) ? index + 3 : bytes.length;
    yield Uint8List.fromList(bytes.sublist(index, end));
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

Stream<List<int>> _delayedByteChunks(List<int> bytes) async* {
  for (var index = 0; index < bytes.length; index += 3) {
    final end = (index + 3 < bytes.length) ? index + 3 : bytes.length;
    yield bytes.sublist(index, end);
    await Future<void>.delayed(const Duration(milliseconds: 15));
  }
}

class _FakeStreamClient extends http.BaseClient {
  _FakeStreamClient(this._handler);

  final Future<http.StreamedResponse> Function(http.BaseRequest request)
      _handler;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _handler(request);
  }
}

class _FakeDioHttpClientAdapter implements dio.HttpClientAdapter {
  _FakeDioHttpClientAdapter(this._handler);

  final Future<dio.ResponseBody> Function(dio.RequestOptions options) _handler;

  @override
  Future<dio.ResponseBody> fetch(
    dio.RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    return _handler(options);
  }

  @override
  void close({bool force = false}) {}
}

class _DownloadCallbackAdapter implements NetworkAdapter {
  _DownloadCallbackAdapter({
    required this.onDownload,
  });

  final Future<AdapterResponse> Function(
    AdapterRequest request,
    String savePath,
    ProgressCallback? onProgress,
  ) onDownload;

  @override
  String get name => 'DownloadCallbackAdapter';

  @override
  String get version => '1.0.0';

  @override
  Future<AdapterResponse> request(AdapterRequest request) async {
    throw UnimplementedError('request');
  }

  @override
  Future<AdapterResponse> download(
    AdapterRequest request,
    String savePath, {
    ProgressCallback? onProgress,
  }) async {
    return onDownload(request, savePath, onProgress);
  }

  @override
  Future<AdapterResponse> upload(
    AdapterRequest request, {
    ProgressCallback? onProgress,
  }) async {
    throw UnimplementedError('upload');
  }

  @override
  void cancel(CancelToken token) {}

  @override
  void addInterceptor(AdapterInterceptor interceptor) {}

  @override
  void removeInterceptor(AdapterInterceptor interceptor) {}
}
