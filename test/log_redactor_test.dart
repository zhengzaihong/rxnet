import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/utils/log_redactor.dart';

void main() {
  group('LogRedactor.redactHeaders', () {
    test('masks Authorization, Cookie and API key headers', () {
      final headers = <String, dynamic>{
        'Authorization': 'Bearer secret-token',
        'Cookie': 'sessionid=abc',
        'Proxy-Authorization': 'Basic dXNlcjpwYXNz',
        'X-Api-Key': 'key-123',
        'Content-Type': 'application/json',
        'Accept': '*/*',
      };

      final redacted = LogRedactor.redactHeaders(headers);

      expect(redacted['Authorization'], LogRedactor.mask);
      expect(redacted['Cookie'], LogRedactor.mask);
      expect(redacted['Proxy-Authorization'], LogRedactor.mask);
      expect(redacted['X-Api-Key'], LogRedactor.mask);
      expect(redacted['Content-Type'], 'application/json');
      expect(redacted['Accept'], '*/*');
    });

    test('handles case, underscore and dash variations', () {
      final headers = <String, dynamic>{
        'access_token': 'a',
        'refresh-token': 'r',
        'idToken': 'i',
        'client_secret': 'c',
      };

      final redacted = LogRedactor.redactHeaders(headers);

      expect(redacted.values, everyElement(LogRedactor.mask));
    });

    test('masks PII headers such as email and phone', () {
      final headers = <String, dynamic>{
        'X-User-Email': 'alice@example.com',
        'X-User-phone': '13800138000',
        'X-User-IdCard': '110101199001011234',
        'X-Request-Id': 'req-1',
      };

      final redacted = LogRedactor.redactHeaders(headers);

      expect(redacted['X-User-Email'], LogRedactor.mask);
      expect(redacted['X-User-phone'], LogRedactor.mask);
      expect(redacted['X-User-IdCard'], LogRedactor.mask);
      expect(redacted['X-Request-Id'], 'req-1');
    });

    test('does not mutate the input map', () {
      final headers = <String, dynamic>{'Authorization': 'Bearer secret'};

      LogRedactor.redactHeaders(headers);

      expect(headers['Authorization'], 'Bearer secret');
    });
  });

  group('LogRedactor.redactData', () {
    test('masks sensitive keys in nested maps', () {
      final data = <String, dynamic>{
        'user': <String, dynamic>{
          'name': 'Alice',
          'password': 'p@ssw0rd',
          'profile': <String, dynamic>{'access_token': 'token-value'},
        },
        'keep': 'visible',
      };

      final redacted = LogRedactor.redactData(data) as Map<String, dynamic>;
      final user = redacted['user'] as Map<String, dynamic>;
      final profile = user['profile'] as Map<String, dynamic>;

      expect(redacted['keep'], 'visible');
      expect(user['name'], 'Alice');
      expect(user['password'], LogRedactor.mask);
      expect(profile['access_token'], LogRedactor.mask);
    });

    test('masks sensitive keys inside lists of maps', () {
      final data = <String, dynamic>{
        'items': <dynamic>[
          <String, dynamic>{'token': 't1', 'name': 'one'},
          <String, dynamic>{'secret': 's2', 'name': 'two'},
        ],
        'tags': <dynamic>['a', 'b'],
      };

      final redacted = LogRedactor.redactData(data) as Map<String, dynamic>;
      final items = redacted['items'] as List<dynamic>;
      final first = items[0] as Map<String, dynamic>;
      final second = items[1] as Map<String, dynamic>;

      expect(first['name'], 'one');
      expect(first['token'], LogRedactor.mask);
      expect(second['name'], 'two');
      expect(second['secret'], LogRedactor.mask);
      expect(redacted['tags'], ['a', 'b']);
    });

    test('masks PII fields in nested structures', () {
      final data = <String, dynamic>{
        'user': <String, dynamic>{
          'name': 'Alice',
          'email': 'alice@example.com',
          'phone': '13800138000',
          'mobile': '13900139000',
          'idCard': '110101199001011234',
          'passport': 'E12345678',
          'bankCard': '6222021234567890',
        },
        'contacts': <dynamic>[
          <String, dynamic>{'mail': 'bob@example.com', 'tel': '010-12345678'},
          <String, dynamic>{'idNumber': '110101199001015678'},
        ],
      };

      final redacted = LogRedactor.redactData(data) as Map<String, dynamic>;
      final user = redacted['user'] as Map<String, dynamic>;
      final contacts = redacted['contacts'] as List<dynamic>;
      final first = contacts[0] as Map<String, dynamic>;
      final second = contacts[1] as Map<String, dynamic>;

      expect(user['name'], 'Alice');
      expect(user['email'], LogRedactor.mask);
      expect(user['phone'], LogRedactor.mask);
      expect(user['mobile'], LogRedactor.mask);
      expect(user['idCard'], LogRedactor.mask);
      expect(user['passport'], LogRedactor.mask);
      expect(user['bankCard'], LogRedactor.mask);
      expect(first['mail'], LogRedactor.mask);
      expect(first['tel'], LogRedactor.mask);
      expect(second['idNumber'], LogRedactor.mask);
    });

    test('masks Chinese PII field names', () {
      final data = <String, dynamic>{
        '姓名': '张三',
        '邮箱': 'zhangsan@example.com',
        '手机号': '13800138000',
        '身份证': '110101199001011234',
      };

      final redacted = LogRedactor.redactData(data) as Map<String, dynamic>;

      expect(redacted['姓名'], '张三');
      expect(redacted['邮箱'], LogRedactor.mask);
      expect(redacted['手机号'], LogRedactor.mask);
      expect(redacted['身份证'], LogRedactor.mask);
    });

    test('keeps non-sensitive scalar values untouched', () {
      final data = <String, dynamic>{
        'id': 7,
        'enabled': true,
        'score': 1.5,
        'name': 'Alice',
        'nothing': null,
      };

      final redacted = LogRedactor.redactData(data) as Map<String, dynamic>;

      expect(redacted, data);
    });

    test('returns [MaxDepth] for excessively deep structures', () {
      dynamic deep = <String, dynamic>{'password': 'x'};
      for (var i = 0; i < 12; i++) {
        deep = <String, dynamic>{'level': deep};
      }

      final redacted = LogRedactor.redactData(deep);

      expect(redacted.toString(), contains('[MaxDepth]'));
      expect(redacted.toString(), isNot(contains('password')));
    });
  });

  group('LogRedactor.redactUrl', () {
    test('returns URLs without query unchanged', () {
      expect(
        LogRedactor.redactUrl('https://example.com/api/users'),
        'https://example.com/api/users',
      );
      expect(
        LogRedactor.redactUrl('https://example.com/api/users#section'),
        'https://example.com/api/users#section',
      );
    });

    test('masks token in the query while keeping other params', () {
      expect(
        LogRedactor.redactUrl('https://example.com/api?a=1&token=abc'),
        'https://example.com/api?a=1&token=***',
      );
    });

    test('masks PII query params', () {
      expect(
        LogRedactor.redactUrl(
          'https://example.com/api?email=alice@example.com&phone=13800138000',
        ),
        'https://example.com/api?email=***&phone=***',
      );
    });

    test('preserves the fragment as-is', () {
      expect(
        LogRedactor.redactUrl(
          'https://example.com/api?token=abc#section//two',
        ),
        'https://example.com/api?token=***#section//two',
      );
    });

    test('preserves path and non-sensitive query values', () {
      expect(
        LogRedactor.redactUrl(
          'https://example.com/a//b?page=1&redirect=http://a//b',
        ),
        'https://example.com/a//b?page=1&redirect=http://a//b',
      );
    });

    test('decodes percent-encoded query keys before matching', () {
      expect(
        LogRedactor.redactUrl(
          'https://example.com/api?access%5Ftoken=abc',
        ),
        'https://example.com/api?access%5Ftoken=***',
      );
      expect(
        LogRedactor.redactUrl(
          'https://example.com/api?%E6%89%8B%E6%9C%BA%E5%8F%B7=13800138000',
        ),
        'https://example.com/api?%E6%89%8B%E6%9C%BA%E5%8F%B7=***',
      );
    });

    test('masks multiple sensitive params including empty values', () {
      expect(
        LogRedactor.redactUrl(
          'https://example.com/api?token=&password=&name=Alice',
        ),
        'https://example.com/api?token=***&password=***&name=Alice',
      );
    });

    test('handles an empty query string', () {
      expect(
        LogRedactor.redactUrl('https://example.com/api?'),
        'https://example.com/api?',
      );
    });
  });

  group('LogRedactor.redactJsonString', () {
    test('parses and redacts a JSON object string', () {
      final result = LogRedactor.redactJsonString(
        '{"password":"p@ss","name":"Alice"}',
      );

      expect(result, isA<Map<String, dynamic>>());
      final map = result as Map<String, dynamic>;
      expect(map['password'], LogRedactor.mask);
      expect(map['name'], 'Alice');
    });

    test('parses and redacts a JSON array string', () {
      final result = LogRedactor.redactJsonString(
        '[{"access_token":"t1","id":1}]',
      );

      expect(result, isA<List<dynamic>>());
      final first = (result as List<dynamic>).first as Map<String, dynamic>;
      expect(first['access_token'], LogRedactor.mask);
      expect(first['id'], 1);
    });

    test('returns plain text without key-value pairs unchanged', () {
      expect(LogRedactor.redactJsonString('plain text'), 'plain text');
      expect(LogRedactor.redactJsonString('hello world'), 'hello world');
      expect(LogRedactor.redactJsonString(''), '');
    });

    test('redacts key-value text when JSON parsing is not applicable', () {
      expect(LogRedactor.redactJsonString('token=abc'), 'token=***');
      expect(
        LogRedactor.redactJsonString('access_token=abc&page=1'),
        'access_token=***&page=1',
      );
      expect(
        LogRedactor.redactJsonString(
          'email=alice@example.com&phone=13800138000',
        ),
        'email=***&phone=***',
      );
    });

    test('returns malformed JSON unchanged', () {
      const malformed = '{"password":';
      expect(LogRedactor.redactJsonString(malformed), malformed);
    });

    test('falls back to key-value redaction for malformed JSON pairs', () {
      expect(
        LogRedactor.redactJsonString('{"password":"p@ss"&token=abc'),
        '{"password":"p@ss"&token=***',
      );
    });
  });

  group('LogRedactor.redactKeyValueText', () {
    test('masks sensitive query/form parameters', () {
      expect(
        LogRedactor.redactKeyValueText('token=abc'),
        'token=***',
      );
      expect(
        LogRedactor.redactKeyValueText('a=1&token=abc&b=2'),
        'a=1&token=***&b=2',
      );
    });

    test('masks PII parameters', () {
      expect(
        LogRedactor.redactKeyValueText('email=alice@example.com'),
        'email=***',
      );
      expect(
        LogRedactor.redactKeyValueText('phone=13800138000&mobile=13900139000'),
        'phone=***&mobile=***',
      );
      expect(
        LogRedactor.redactKeyValueText('idCard=110101199001011234'),
        'idCard=***',
      );
    });

    test('decodes percent-encoded keys before matching', () {
      expect(
        LogRedactor.redactKeyValueText('access%5Ftoken=abc'),
        'access%5Ftoken=***',
      );
      expect(
        LogRedactor.redactKeyValueText(
          '%E6%89%8B%E6%9C%BA%E5%8F%B7=13800138000',
        ),
        '%E6%89%8B%E6%9C%BA%E5%8F%B7=***',
      );
    });

    test('leaves non-sensitive params and plain segments untouched', () {
      expect(LogRedactor.redactKeyValueText('page=1&size=20'), 'page=1&size=20');
      expect(LogRedactor.redactKeyValueText('flag'), 'flag');
      expect(LogRedactor.redactKeyValueText('=abc'), '=abc');
      expect(LogRedactor.redactKeyValueText(''), '');
    });

    test('supports multiple separators and empty sensitive values', () {
      expect(
        LogRedactor.redactKeyValueText('token=&password=&name=Alice'),
        'token=***&password=***&name=Alice',
      );
    });
  });

  group('LogRedactor.isSensitiveKey', () {
    test('detects known keys regardless of case and separators', () {
      expect(LogRedactor.isSensitiveKey('Authorization'), isTrue);
      expect(LogRedactor.isSensitiveKey('authorization'), isTrue);
      expect(LogRedactor.isSensitiveKey('X-Api-Key'), isTrue);
      expect(LogRedactor.isSensitiveKey('client_secret'), isTrue);
      expect(LogRedactor.isSensitiveKey('userPassword'), isTrue);
      expect(LogRedactor.isSensitiveKey('refreshToken'), isTrue);
    });

    test('detects PII keys regardless of case and separators', () {
      expect(LogRedactor.isSensitiveKey('email'), isTrue);
      expect(LogRedactor.isSensitiveKey('Email'), isTrue);
      expect(LogRedactor.isSensitiveKey('user-email'), isTrue);
      expect(LogRedactor.isSensitiveKey('phone'), isTrue);
      expect(LogRedactor.isSensitiveKey('mobile'), isTrue);
      expect(LogRedactor.isSensitiveKey('mobileNumber'), isTrue);
      expect(LogRedactor.isSensitiveKey('idCard'), isTrue);
      expect(LogRedactor.isSensitiveKey('id_number'), isTrue);
      expect(LogRedactor.isSensitiveKey('邮箱'), isTrue);
      expect(LogRedactor.isSensitiveKey('手机号'), isTrue);
      expect(LogRedactor.isSensitiveKey('身份证'), isTrue);
    });

    test('does not flag ordinary fields', () {
      expect(LogRedactor.isSensitiveKey('Content-Type'), isFalse);
      expect(LogRedactor.isSensitiveKey('username'), isFalse);
      expect(LogRedactor.isSensitiveKey('page'), isFalse);
      expect(LogRedactor.isSensitiveKey('note'), isFalse);
      expect(LogRedactor.isSensitiveKey('mailbox'), isFalse);
      expect(LogRedactor.isSensitiveKey('orderId'), isFalse);
    });
  });

  group('LogRedactor.toSafeJson', () {
    test('encodes redacted map to JSON string', () {
      final safe = LogRedactor.toSafeJson(<String, dynamic>{
        'token': 'abc',
        'name': 'Alice',
      });

      expect(safe, contains('"token":"***"'));
      expect(safe, contains('"name":"Alice"'));
      expect(safe, isNot(contains('"abc"')));
    });

    test('redacts JSON strings before re-encoding', () {
      final safe = LogRedactor.toSafeJson('{"password":"p@ss","id":1}');

      expect(safe, contains('"password":"***"'));
      expect(safe, contains('"id":1'));
    });

    test('redacts key-value text strings', () {
      final safe = LogRedactor.toSafeJson('a=1&token=abc');

      expect(safe, 'a=1&token=***');
      expect(safe, isNot(contains('abc')));
    });

    test('redacts PII in plain strings', () {
      final safe = LogRedactor.toSafeJson('email=alice@example.com&page=1');

      expect(safe, 'email=***&page=1');
      expect(safe, isNot(contains('alice@example.com')));
    });
  });
}