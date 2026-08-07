import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';
import 'package:rxnet_plus/utils/rx_net_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RxNetDataBase readiness', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('rxnet_database_');
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

    test('saveCache/readCache await database initialization internally',
        () async {
      final initFuture = RxNet.init(config: RxNetConfig(
        baseUrl: 'https://unit.test',
        cachePath: tempDir.path,
        adapter: MockAdapter(),
      ));

      await RxNet.saveCache('name', 'Alice');

      final value = await RxNet.readCache<String>('name');

      expect(value, 'Alice');
      await initFuture;
    });

    test('instance init completes and ready resolves', () async {
      final database = RxNetDataBase();

      await database.init(databasePath: tempDir.path);

      expect(database.isDatabaseReady, isTrue);
      await database.ready;
      await database.closeInstance();
    });

    test('static initDatabase works via static instance', () async {
      final ready = Completer<bool>();

      await RxNetDataBase.initDatabase(databasePath: tempDir.path);

      expect(RxNetDataBase.isReady, isTrue);
      await RxNetDataBase.waitUntilReady();
    });
  });
}
