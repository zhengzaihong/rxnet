import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('IO branch exports', () {
    test('running on a dart:io platform', () {
      // 条件导出的 IO 分支只在非 Web/Wasm 平台生效。
      expect(Platform.isWindows || Platform.isLinux || Platform.isMacOS ||
          Platform.isAndroid || Platform.isIOS || Platform.isFuchsia, isTrue);
    });

    test('rxnet_lib exports IOClient', () {
      final client = IOClient();
      addTearDown(client.close);

      expect(client, isA<IOClient>());
      expect(IOClient, isNotNull);
    });

    test('rxnet_lib exports IOHttpClientAdapter', () {
      final adapter = IOHttpClientAdapter();
      addTearDown(() => adapter.close());

      expect(adapter, isA<IOHttpClientAdapter>());
      expect(adapter, isA<HttpClientAdapter>());
    });

    test('DioAdapter accepts IOHttpClientAdapter on IO platforms', () {
      final dio = Dio();
      final ioAdapter = IOHttpClientAdapter();
      addTearDown(() => ioAdapter.close());

      dio.httpClientAdapter = ioAdapter;

      expect(dio.httpClientAdapter, same(ioAdapter));
      expect(DioAdapter(dio: dio).name, isNotEmpty);
    });
  });
}