import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rxnet_plus/utils/rx_net_platform.dart';

void main() {
  group('RxNetPlatform on the test host', () {
    test('isHarmonyOS is false when the host is not OHOS', () {
      final os = Platform.operatingSystem.toLowerCase();

      expect(os, isNot(anyOf('ohos', 'harmonyos')));
      expect(RxNetPlatform.isHarmonyOS, isFalse);
    });

    test('isAndroidIosHarmonyOs matches the deprecated alias', () {
      // ignore: deprecated_member_use_from_same_package
      final legacy = RxNetPlatform.isAndroid_IOS_HarmonyOS;

      expect(legacy, RxNetPlatform.isAndroidIosHarmonyOs);
    });

    test('desktop host reports no mobile/OHOS flags', () {
      expect(RxNetPlatform.isWeb, isFalse);
      expect(RxNetPlatform.isAndroid, isFalse);
      expect(RxNetPlatform.isIOS, isFalse);
      expect(RxNetPlatform.isHarmonyOS, isFalse);
      expect(RxNetPlatform.isAndroidIosHarmonyOs, isFalse);
    });
  });
}