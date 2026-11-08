import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('network cache eviction', () {
    late Directory tempDir;
    late MockAdapter adapter;
    late RxNet rxNet;

    setUp(() async {
      tempDir = Directory.systemTemp.createTempSync('rxnet_cache_evict_');
      adapter = MockAdapter();
      rxNet = RxNet.create();
      await rxNet.initNet(
        config: RxNetConfig(
          baseUrl: 'https://example.com',
          adapter: adapter,
          cachePath: tempDir.path,
          databaseName: 'cache_evict.db',
          cacheMode: CacheMode.FIRST_USE_CACHE_THEN_REQUEST,
          cacheMaxSize: 1,
          cacheEvictionPolicy: CacheEvictionPolicy.lru,
        ),
      );
    });

    tearDown(() async {
      await rxNet.getDatabase()?.closeInstance();
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('request cache writes metadata and evicts by policy', () async {
      final first = await rxNet.getRequest().setPath('/a').request();
      expect(first.isSuccess, isTrue);

      final second = await rxNet.getRequest().setPath('/b').request();
      expect(second.isSuccess, isTrue);

      expect(await rxNet.cacheManager.getCacheSize(), 1);

      final keys = await rxNet.cacheManager.getAllKeys();
      expect(keys, hasLength(1));

      final metadata = await rxNet.getDatabase()?.getMetadata(keys.first);
      expect(metadata, isNotNull);
      expect(metadata!['accessCount'], isA<int>());
    });
  });
}