import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('RxNet init / env', () {
    late Directory tempDir;
    late MockAdapter adapter;
    late RxNet rxNet;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('rxnet_init_env_');
      adapter = MockAdapter();
      rxNet = RxNet.create();
      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://primary.example.com',
          adapter: adapter,
          cachePath: tempDir.path,
          databaseName: 'init_env.db',
          baseUrlEnv: const {
            'dev': 'https://dev.example.com',
            'prod': 'https://prod.example.com',
          },
        ),
      );
    });

    tearDown(() async {
      await rxNet.getDatabase()?.closeInstance();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('uses config.adapter instead of default DioAdapter', () {
      expect(identical(rxNet.getAdapter(), adapter), isTrue);
    });

    test('setEnv updates baseUrl and outgoing request', () async {
      rxNet.setEnv('dev');

      expect(rxNet.baseUrl, 'https://dev.example.com');

      final result = await rxNet
          .getRequest()
          .setPath('/users')
          .setCacheMode(CacheMode.ONLY_REQUEST)
          .request();

      expect(result.isSuccess, isTrue);
      expect(adapter.requestHistory, hasLength(1));

      final sent = adapter.requestHistory.last;
      expect(sent.baseUrl, 'https://dev.example.com');
      expect(sent.buildFullUrl(), 'https://dev.example.com/users');
    });

    test('unknown env does not change current baseUrl', () {
      rxNet.setEnv('dev');
      rxNet.setEnv('missing');

      expect(rxNet.baseUrl, 'https://dev.example.com');
    });
  });
}