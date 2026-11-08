import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/utils/net_utils.dart';

void main() {
  group('NetUtils.getCacheKeyFromPath raw mode (hashKey: false)', () {
    test('short path returns raw key', () {
      final key = NetUtils.getCacheKeyFromPath(
        '/api/users',
        {'id': '123'},
        [],
        hashKey: false,
      );
      expect(key, '/api/users?id=123');
    });

    test('empty params returns path only', () {
      final key = NetUtils.getCacheKeyFromPath(
        '/api/users',
        {},
        [],
        hashKey: false,
      );
      expect(key, '/api/users');
    });

    test('params are sorted alphabetically', () {
      final key = NetUtils.getCacheKeyFromPath(
        '/api',
        {'z': '1', 'a': '2'},
        [],
        hashKey: false,
      );
      expect(key, '/api?a=2&z=1');
    });

    test('ignored keys are excluded', () {
      final key = NetUtils.getCacheKeyFromPath(
        '/api',
        {'id': '1', 'token': 'abc', 'ts': '999'},
        ['token', 'ts'],
        hashKey: false,
      );
      expect(key, '/api?id=1');
    });

    test('raw mode keeps the plaintext key by design', () {
      final key = NetUtils.getCacheKeyFromPath(
        '/api/login',
        {'access_token': 'plain-token'},
        [],
        hashKey: false,
      );
      expect(key, contains('plain-token'));
    });
  });

  group('NetUtils.getCacheKeyFromPath hashing (default behavior)', () {
    test('hashes by default even for short keys', () {
      final key = NetUtils.getCacheKeyFromPath('/api/users', {'id': '123'}, []);

      expect(key.length, 32);
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(key), isTrue);
      expect(key, isNot('/api/users?id=123'));
      expect(key, isNot(contains('/api/users')));
    });

    test('hashes path-only keys too', () {
      final key = NetUtils.getCacheKeyFromPath('/api/users', {}, []);

      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(key), isTrue);
      expect(key, isNot('/api/users'));
    });

    test('is deterministic for identical inputs', () {
      final key1 = NetUtils.getCacheKeyFromPath('/api', {'a': '1'}, []);
      final key2 = NetUtils.getCacheKeyFromPath('/api', {'a': '1'}, []);

      expect(key1, key2);
    });

    test('is insensitive to parameter insertion order', () {
      final key1 = NetUtils.getCacheKeyFromPath('/api', {'a': '1', 'b': '2'}, []);
      final key2 = NetUtils.getCacheKeyFromPath('/api', {'b': '2', 'a': '1'}, []);

      expect(key1, key2);
    });

    test('different params produce different keys', () {
      final key1 = NetUtils.getCacheKeyFromPath('/api', {'a': '1'}, []);
      final key2 = NetUtils.getCacheKeyFromPath('/api', {'a': '2'}, []);

      expect(key1, isNot(key2));
    });

    test('different paths produce different keys', () {
      final key1 = NetUtils.getCacheKeyFromPath('/api/a', {}, []);
      final key2 = NetUtils.getCacheKeyFromPath('/api/b', {}, []);

      expect(key1, isNot(key2));
    });

    test('ignore keys change the resulting hash', () {
      final withIgnored = NetUtils.getCacheKeyFromPath('/api', {'id': '1'}, []);
      final withoutIgnored = NetUtils.getCacheKeyFromPath(
        '/api',
        {'id': '1', 'ts': '999'},
        ['ts'],
      );

      expect(withIgnored, withoutIgnored);
    });

    test('long key is hashed with 32 hex chars', () {
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

    test('token and PII are never exposed as plaintext in the cache key', () {
      const token = 'secret-token-abc123';
      const email = 'alice@example.com';
      const phone = '13800138000';
      const password = 'p@ssw0rd';

      final key = NetUtils.getCacheKeyFromPath('/api/login', {
        'access_token': token,
        'email': email,
        'phone': phone,
        'password': password,
      }, []);

      expect(key, isNot(contains(token)));
      expect(key, isNot(contains(email)));
      expect(key, isNot(contains(phone)));
      expect(key, isNot(contains(password)));
      expect(key, isNot(contains('/api/login')));
      expect(RegExp(r'^[0-9a-f]{32}$').hasMatch(key), isTrue);
    });

    test('throws on empty path', () {
      expect(
        () => NetUtils.getCacheKeyFromPath('', {}, []),
        throwsA(isA<Exception>()),
      );
    });

    test('throws on null path', () {
      expect(
        () => NetUtils.getCacheKeyFromPath(null, {}, []),
        throwsA(isA<Exception>()),
      );
    });
  });
}