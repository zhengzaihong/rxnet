import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

void main() {
  group('RxNetConfig security defaults', () {
    test('isDebug defaults to false', () {
      const config = RxNetConfig(baseUrl: 'https://example.com');

      expect(config.isDebug, isFalse);
    });

    test('builder defaults isDebug to false', () {
      final config = RxNetConfig.builder().build();

      expect(config.isDebug, isFalse);
    });

    test('systemLog defaults to false', () {
      const config = RxNetConfig(baseUrl: 'https://example.com');

      expect(config.systemLog, isFalse);
    });

    test('builder keeps systemLog disabled by default', () {
      final config = RxNetConfig.builder().build();

      expect(config.systemLog, isFalse);
    });

    test('isDebug can still be enabled explicitly', () {
      final config = RxNetConfig.builder().debug(true).build();

      expect(config.isDebug, isTrue);
    });

    test('copyWith keeps isDebug false unless requested', () {
      const config = RxNetConfig(baseUrl: 'https://example.com');

      final copied = config.copyWith(baseUrl: 'https://api.example.com');

      expect(copied.isDebug, isFalse);
      expect(config.copyWith(isDebug: true).isDebug, isTrue);
    });
  });
}