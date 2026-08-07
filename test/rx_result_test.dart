import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('RxResult', () {
    test('success factory creates non-null result', () {
      final result = RxResult.success('hello');
      expect(result.isSuccess, isTrue);
      expect(result.isError, isFalse);
      expect(result.value, 'hello');
      expect(result.requiredValue, 'hello');
      expect(result.model, SourcesType.net);
    });

    test('error factory creates error result', () {
      final result = RxResult.error(Exception('fail'));
      expect(result.isSuccess, isFalse);
      expect(result.isError, isTrue);
      expect(result.value, isNull);
    });

    test('requiredValue throws StateError on error result', () {
      final result = RxResult.error(Exception('fail'));
      expect(() => result.requiredValue, throwsStateError);
    });

    test('requiredValue throws StateError when value is null via legacy constructor', () {
      final result = RxResult<String>();
      expect(result.isSuccess, isTrue);
      expect(() => result.requiredValue, throwsStateError);
    });

    test('value returns null via legacy constructor without value', () {
      final result = RxResult<int>();
      expect(result.value, isNull);
      expect(result.isSuccess, isTrue);
    });

    test('success factory preserves model parameter', () {
      final result = RxResult.success(42, model: SourcesType.cache);
      expect(result.model, SourcesType.cache);
      expect(result.requiredValue, 42);
    });

    test('error factory preserves error object', () {
      final error = Exception('test error');
      final result = RxResult.error(error);
      expect(result.error, error);
    });

    test('generic type is preserved', () {
      final result = RxResult.success(123);
      final int value = result.requiredValue;
      expect(value, 123);
    });
  });
}
