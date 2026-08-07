import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/utils/net_utils.dart';

void main() {
  group('NetUtils.getCacheKeyFromPath', () {
    test('short path returns raw key', () {
      final key = NetUtils.getCacheKeyFromPath('/api/users', {'id': '123'}, []);
      expect(key, '/api/users?id=123');
    });

    test('empty params returns path only', () {
      final key = NetUtils.getCacheKeyFromPath('/api/users', {}, []);
      expect(key, '/api/users');
    });

    test('params are sorted alphabetically', () {
      final key = NetUtils.getCacheKeyFromPath('/api', {'z': '1', 'a': '2'}, []);
      expect(key, '/api?a=2&z=1');
    });

    test('ignored keys are excluded', () {
      final key = NetUtils.getCacheKeyFromPath('/api', {'id': '1', 'token': 'abc', 'ts': '999'}, ['token', 'ts']);
      expect(key, '/api?id=1');
    });

    test('long key is hashed with SHA-256', () {
      final longParams = <String, dynamic>{};
      for (var i = 0; i < 20; i++) {
        longParams['key_$i'] = 'value_${'x' * 10}';
      }
      final key = NetUtils.getCacheKeyFromPath('/api/endpoint', longParams, []);
      expect(key.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(key), isTrue);
    });

    test('same long inputs produce same hash', () {
      final params = <String, dynamic>{};
      for (var i = 0; i < 20; i++) {
        params['key_$i'] = 'value_${'x' * 10}';
      }
      final key1 = NetUtils.getCacheKeyFromPath('/api', params, []);
      final key2 = NetUtils.getCacheKeyFromPath('/api', params, []);
      expect(key1, key2);
    });

    test('different params produce different keys', () {
      final key1 = NetUtils.getCacheKeyFromPath('/api', {'a': '1'}, []);
      final key2 = NetUtils.getCacheKeyFromPath('/api', {'a': '2'}, []);
      expect(key1, isNot(key2));
    });

    test('throws on empty path', () {
      expect(() => NetUtils.getCacheKeyFromPath('', {}, []), throwsA(isA<Exception>()));
    });

    test('throws on null path', () {
      expect(() => NetUtils.getCacheKeyFromPath(null, {}, []), throwsA(isA<Exception>()));
    });
  });
}
