import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('zipRequest cancellation', () {
    test('completes every pending request with ZipRequestError keeping index/tag',
        () async {
      final cancelToken = CancelToken();
      final requests = <ZipRequest>[
        ZipRequest<String>(
          tag: 'first',
          request: ({success, failure, completed}) {},
        ),
        ZipRequest<String>(
          tag: 'second',
          request: ({success, failure, completed}) {},
        ),
      ];

      final future = zipRequest(
        requests,
        cancelToken: cancelToken,
        eagerError: false,
      );
      await Future<void>.delayed(Duration.zero);
      cancelToken.cancel('stop');

      final results = await future;

      expect(results.length, 2);
      expect(results.successfulResults, isEmpty);
      expect(results.errors.length, 2);

      final first = results.errors[0] as ZipRequestError;
      final second = results.errors[1] as ZipRequestError;

      expect(first.index, 0);
      expect(first.tag, 'first');
      expect(second.index, 1);
      expect(second.tag, 'second');
      expect(first.error, isA<AdapterException>());
      expect(
        (first.error as AdapterException).type,
        AdapterExceptionType.cancel,
      );
    });

    test('eager mode surfaces the first cancellation error', () async {
      final cancelToken = CancelToken();
      final requests = <ZipRequest>[
        ZipRequest<String>(
          tag: 'first',
          request: ({success, failure, completed}) {},
        ),
        ZipRequest<String>(
          tag: 'second',
          request: ({success, failure, completed}) {},
        ),
      ];

      final future = zipRequest(requests, cancelToken: cancelToken);
      await Future<void>.delayed(Duration.zero);
      cancelToken.cancel('stop');

      await expectLater(
        future,
        throwsA(
          isA<ZipRequestError>()
              .having((error) => error.index, 'index', 0)
              .having((error) => error.tag, 'tag', 'first'),
        ),
      );
    });
  });

  group('zipRequest timeout', () {
    test('throws ZipRequestError with index -1 wrapping a TimeoutException',
        () async {
      final requests = <ZipRequest>[
        ZipRequest<String>(
          tag: 'slow',
          request: ({success, failure, completed}) {},
        ),
      ];

      await expectLater(
        zipRequest(requests, timeout: const Duration(milliseconds: 20)),
        throwsA(
          isA<ZipRequestError>()
              .having((error) => error.index, 'index', -1)
              .having((error) => error.tag, 'tag', isNull)
              .having((error) => error.error, 'error', isA<TimeoutException>()),
        ),
      );
    });

    test('completes pending requests so late callbacks are ignored', () async {
      Success<String>? capturedSuccess;
      Failure? capturedFailure;

      final requests = <ZipRequest>[
        ZipRequest<String>(
          tag: 'slow',
          request: ({success, failure, completed}) {
            capturedSuccess = success;
            capturedFailure = failure;
          },
        ),
      ];

      await expectLater(
        zipRequest(requests, timeout: const Duration(milliseconds: 20)),
        throwsA(isA<ZipRequestError>()),
      );

      expect(
        () => capturedSuccess?.call('late', SourcesType.net),
        returnsNormally,
      );
      expect(() => capturedFailure?.call('late error'), returnsNormally);
    });

    test('cancels the provided token when timing out', () async {
      final cancelToken = CancelToken();
      final requests = <ZipRequest>[
        ZipRequest<String>(
          tag: 'slow',
          request: ({success, failure, completed}) {},
        ),
      ];

      await expectLater(
        zipRequest(
          requests,
          cancelToken: cancelToken,
          timeout: const Duration(milliseconds: 20),
        ),
        throwsA(
          isA<ZipRequestError>().having((error) => error.index, 'index', -1),
        ),
      );

      expect(cancelToken.isCancelled, isTrue);
    });
  });

  group('zipRequest eagerError', () {
    test('first failure cancels remaining requests when a token is provided',
        () async {
      final cancelToken = CancelToken();
      final requests = <ZipRequest>[
        ZipRequest<String>(
          tag: 'fail',
          request: ({success, failure, completed}) {
            failure?.call('boom');
          },
        ),
        ZipRequest<String>(
          tag: 'hang',
          request: ({success, failure, completed}) {},
        ),
      ];

      await expectLater(
        zipRequest(requests, cancelToken: cancelToken),
        throwsA(
          isA<ZipRequestError>()
              .having((error) => error.index, 'index', 0)
              .having((error) => error.tag, 'tag', 'fail'),
        ),
      );

      expect(cancelToken.isCancelled, isTrue);
      expect(cancelToken.cancelReason, contains('ZipRequest failed'));
    });

    test('eagerError:false collects successes and wraps failures', () async {
      final requests = <ZipRequest>[
        ZipRequest<String>(
          tag: 'ok',
          request: ({success, failure, completed}) {
            success?.call('value', SourcesType.net);
          },
        ),
        ZipRequest<String>(
          tag: 'bad',
          request: ({success, failure, completed}) {
            failure?.call('oops');
          },
        ),
      ];

      final results = await zipRequest(requests, eagerError: false);

      expect(results.length, 2);
      expect(results.isSuccess(0), isTrue);
      expect(results.isSuccess(1), isFalse);
      expect(results.getRequestByTag<String>('ok'), 'value');
      expect(results.successfulResults, ['value']);
      expect(results.errors.length, 1);
      expect(results.errors.containsKey(1), isTrue);

      final error = results.errors[1] as ZipRequestError;
      expect(error.index, 1);
      expect(error.tag, 'bad');
      expect(error.error, 'oops');
      expect(
        () => results.getRequestByIndex<String>(1),
        throwsA(isA<ZipRequestError>()),
      );
    });
  });

  group('zipRequest validation', () {
    test('rejects an empty request list', () async {
      await expectLater(
        zipRequest(<ZipRequest>[]),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('rejects duplicate tags', () async {
      final requests = <ZipRequest>[
        ZipRequest<String>(
          tag: 'dup',
          request: ({success, failure, completed}) {},
        ),
        ZipRequest<String>(
          tag: 'dup',
          request: ({success, failure, completed}) {},
        ),
      ];

      await expectLater(
        zipRequest(requests),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}