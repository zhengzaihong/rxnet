import 'platform_web_stub.dart'
    if (dart.library.io) 'dart:io';
import 'package:flutter/foundation.dart';

///
/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2025-08-12
/// time: 16:02
/// describe: 平台判断
///
class RxNetPlatform {
  RxNetPlatform._();

  static bool _isWeb() => kIsWeb;

  static bool _isAndroid() => _isWeb() ? false : Platform.isAndroid;

  static bool _isIOS() => _isWeb() ? false : Platform.isIOS;

  static bool _isMacOS() => _isWeb() ? false : Platform.isMacOS;

  static bool _isWindows() => _isWeb() ? false : Platform.isWindows;

  static bool _isFuchsia() => _isWeb() ? false : Platform.isFuchsia;

  static bool _isLinux() => _isWeb() ? false : Platform.isLinux;

  static bool _isHarmonyOS() {
    if (_isWeb()) {
      return false;
    }
    final os = Platform.operatingSystem.toLowerCase();
    return os == 'ohos' || os == 'harmonyos';
  }

  static bool get isAndroidIosHarmonyOs =>
      _isAndroid() || _isIOS() || _isHarmonyOS();

  @Deprecated('Use isAndroidIosHarmonyOs instead.')
  // ignore: non_constant_identifier_names
  static bool get isAndroid_IOS_HarmonyOS => isAndroidIosHarmonyOs;

  static bool get isWeb => _isWeb();

  static bool get isAndroid => _isAndroid();

  static bool get isIOS => _isIOS();

  static bool get isMacOS => _isMacOS();

  static bool get isWindows => _isWindows();

  static bool get isFuchsia => _isFuchsia();

  static bool get isLinux => _isLinux();

  static bool get isHarmonyOS => _isHarmonyOS();
}
