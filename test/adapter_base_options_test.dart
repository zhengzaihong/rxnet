import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_base_options.dart';
import 'package:rxnet_plus/src/adapter/models/adapter_request.dart';
import 'package:rxnet_plus/src/type/http_method.dart';
import 'package:rxnet_plus/src/type/response_type.dart';

void main() {
  group('AdapterBaseOptions defaults', () {
    test('uses safe redirect / response defaults', () {
      const options = AdapterBaseOptions();

      expect(options.connectTimeout, isNull);
      expect(options.receiveTimeout, isNull);
      expect(options.sendTimeout, isNull);
      expect(options.responseType, ResponseType.json);
      expect(options.followRedirects, isTrue);
      expect(options.maxRedirects, 5);
      expect(options.receiveDataWhenStatusError, isTrue);
      expect(options.persistentConnection, isTrue);
      expect(options.validateStatus, isNull);
      expect(options.headers, isEmpty);
      expect(options.extra, isEmpty);
    });

    test('exposes documented default timeout constants', () {
      expect(
        AdapterBaseOptions.defaultConnectTimeout,
        const Duration(seconds: 15),
      );
      expect(
        AdapterBaseOptions.defaultReceiveTimeout,
        const Duration(seconds: 30),
      );
      expect(
        AdapterBaseOptions.defaultSendTimeout,
        const Duration(seconds: 30),
      );
    });
  });

  group('AdapterBaseOptions.copyWith / merge', () {
    test('copyWith propagates persistentConnection', () {
      const options = AdapterBaseOptions();

      final disabled = options.copyWith(persistentConnection: false);
      expect(disabled.persistentConnection, isFalse);

      final restored = disabled.copyWith(persistentConnection: true);
      expect(restored.persistentConnection, isTrue);
    });

    test('merge keeps persistentConnection from the overriding options', () {
      const base = AdapterBaseOptions(persistentConnection: true);
      const override = AdapterBaseOptions(persistentConnection: false);

      final merged = base.merge(override);

      expect(merged.persistentConnection, isFalse);
    });

    test('merge keeps extra keys from both sides', () {
      final base = AdapterBaseOptions(
        extra: const {'a': 1},
        headers: const {'X-Base': 'base'},
      );
      final override = AdapterBaseOptions(
        extra: const {'b': 2},
        headers: const {'X-Override': 'override'},
      );

      final merged = base.merge(override);

      expect(merged.extra, {'a': 1, 'b': 2});
      expect(merged.headers, {'X-Base': 'base', 'X-Override': 'override'});
    });

    test('copyWith can explicitly clear nullable timeouts', () {
      const options = AdapterBaseOptions(
        connectTimeout: Duration(seconds: 1),
        receiveTimeout: Duration(seconds: 2),
        sendTimeout: Duration(seconds: 3),
      );

      final cleared = options.copyWith(
        clearConnectTimeout: true,
        clearReceiveTimeout: true,
        clearSendTimeout: true,
      );

      expect(cleared.connectTimeout, isNull);
      expect(cleared.receiveTimeout, isNull);
      expect(cleared.sendTimeout, isNull);
    });
  });

  group('AdapterBaseOptions.applyToRequest', () {
    test('merges extra and lets request-level values win', () {
      const options = AdapterBaseOptions(
        headers: {'X-Global': 'global', 'X-Shared': 'global'},
        extra: {'globalKey': 'global', 'sharedKey': 'global'},
        contentType: 'application/json',
        connectTimeout: Duration(seconds: 5),
      );
      final request = AdapterRequest(
        baseUrl: 'https://example.com',
        path: '/items',
        method: HttpMethod.POST,
        headers: const {'X-Shared': 'request'},
        extra: const {'sharedKey': 'request'},
        contentType: 'text/plain',
        connectTimeout: const Duration(seconds: 1),
      );

      final applied = options.applyToRequest(request);

      expect(applied.headers['X-Global'], 'global');
      expect(applied.headers['X-Shared'], 'request');
      expect(applied.extra['globalKey'], 'global');
      expect(applied.extra['sharedKey'], 'request');
      expect(applied.contentType, 'text/plain');
      expect(applied.connectTimeout, const Duration(seconds: 1));
    });

    test('uses base responseType when request keeps the json default', () {
      const options = AdapterBaseOptions(responseType: ResponseType.plain);
      final request = AdapterRequest(
        baseUrl: 'https://example.com',
        path: '/text',
        method: HttpMethod.GET,
      );

      final applied = options.applyToRequest(request);

      expect(applied.responseType, ResponseType.plain);
    });

    test('request-level non-default responseType overrides base', () {
      const options = AdapterBaseOptions(responseType: ResponseType.plain);
      final request = AdapterRequest(
        baseUrl: 'https://example.com',
        path: '/bytes',
        method: HttpMethod.GET,
        responseType: ResponseType.bytes,
      );

      final applied = options.applyToRequest(request);

      expect(applied.responseType, ResponseType.bytes);
    });

    test('does not mutate the original request', () {
      const options = AdapterBaseOptions(
        headers: {'X-Global': 'global'},
        extra: {'fromBase': true},
      );
      final request = AdapterRequest(
        baseUrl: 'https://example.com',
        path: '/items',
        method: HttpMethod.GET,
      );

      options.applyToRequest(request);

      expect(request.headers, isEmpty);
      expect(request.extra, isEmpty);
    });
  });

  group('AdapterBaseOptions.validateStatus', () {
    test('custom validator is evaluated for the adpater success decision', () {
      final options = AdapterBaseOptions(
        validateStatus: (statusCode) => statusCode < 500,
      );

      expect(options.validateStatus!(200), isTrue);
      expect(options.validateStatus!(404), isTrue);
      expect(options.validateStatus!(500), isFalse);
    });

    test('clearing validateStatus restores the default 2xx semantics', () {
      final options = AdapterBaseOptions(
        validateStatus: (statusCode) => statusCode < 500,
      );

      final cleared = options.copyWith(clearValidateStatus: true);

      expect(cleared.validateStatus, isNull);
    });
  });
}