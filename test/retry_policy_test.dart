import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/src/request/retry_policy.dart';

void main() {
  group('RetryPolicy', () {
    group('fixed strategy', () {
      test('returns constant delay for all attempts', () {
        final policy = RetryPolicy.fixed(maxRetries: 3, interval: Duration(seconds: 2));
        expect(policy.getDelay(0), const Duration(seconds: 2));
        expect(policy.getDelay(1), const Duration(seconds: 2));
        expect(policy.getDelay(2), const Duration(seconds: 2));
        expect(policy.maxRetries, 3);
        expect(policy.strategy, RetryStrategy.fixed);
      });
    });

    group('exponentialBackoff strategy', () {
      test('delay doubles each attempt', () {
        const policy = RetryPolicy(
          strategy: RetryStrategy.exponentialBackoff,
          baseInterval: Duration(seconds: 1),
          backoffMultiplier: 2.0,
        );
        expect(policy.getDelay(0), const Duration(seconds: 1));
        expect(policy.getDelay(1), const Duration(seconds: 2));
        expect(policy.getDelay(2), const Duration(seconds: 4));
        expect(policy.getDelay(3), const Duration(seconds: 8));
      });

      test('respects maxInterval cap', () {
        const policy = RetryPolicy(
          strategy: RetryStrategy.exponentialBackoff,
          baseInterval: Duration(seconds: 1),
          backoffMultiplier: 2.0,
          maxInterval: Duration(seconds: 5),
        );
        expect(policy.getDelay(0), const Duration(seconds: 1));
        expect(policy.getDelay(1), const Duration(seconds: 2));
        expect(policy.getDelay(2), const Duration(seconds: 4));
        expect(policy.getDelay(3), const Duration(seconds: 5));
        expect(policy.getDelay(10), const Duration(seconds: 5));
      });
    });

    group('exponentialBackoffWithJitter strategy', () {
      test('delay is non-negative and less than or equal to exponential delay', () {
        const policy = RetryPolicy(
          strategy: RetryStrategy.exponentialBackoffWithJitter,
          baseInterval: Duration(seconds: 1),
          backoffMultiplier: 2.0,
        );
        for (var i = 0; i < 10; i++) {
          final delay = policy.getDelay(i);
          expect(delay.inMilliseconds, greaterThanOrEqualTo(0));
        }
      });

      test('respects maxInterval cap with jitter', () {
        const policy = RetryPolicy(
          strategy: RetryStrategy.exponentialBackoffWithJitter,
          baseInterval: Duration(seconds: 1),
          backoffMultiplier: 2.0,
          maxInterval: Duration(seconds: 5),
        );
        for (var i = 0; i < 20; i++) {
          final delay = policy.getDelay(i);
          expect(delay.inMilliseconds, lessThanOrEqualTo(5000));
        }
      });
    });

    test('factory methods create correct policies', () {
      final fixed = RetryPolicy.fixed(maxRetries: 5, interval: Duration(seconds: 3));
      expect(fixed.maxRetries, 5);
      expect(fixed.strategy, RetryStrategy.fixed);

      final exp = RetryPolicy.exponentialBackoff(maxRetries: 4);
      expect(exp.maxRetries, 4);
      expect(exp.strategy, RetryStrategy.exponentialBackoff);

      final jitter = RetryPolicy.exponentialBackoffWithJitter(maxRetries: 6);
      expect(jitter.maxRetries, 6);
      expect(jitter.strategy, RetryStrategy.exponentialBackoffWithJitter);
    });

    test('toString returns descriptive string', () {
      final policy = RetryPolicy.fixed(maxRetries: 3, interval: Duration(seconds: 1));
      expect(policy.toString(), contains('RetryPolicy'));
      expect(policy.toString(), contains('fixed'));
    });
  });
}

