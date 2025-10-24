import 'dart:io';
import 'package:flutter/foundation.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2025-08-12
/// create_time: 16:02
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
    if (_isWeb() ||
        _isAndroid() ||
        _isIOS() ||
        _isMacOS() ||
        _isWindows() ||
        _isFuchsia() ||
        _isLinux()) {
      return false;
    }
    return true;
  }

  static bool get isAndroid_IOS_HarmonyOS => _isAndroid() || _isIOS() || _isHarmonyOS();

  static bool get isWeb => _isWeb();

  static bool get isAndroid => _isAndroid();

  static bool get isIOS => _isIOS();

  static bool get isMacOS => _isMacOS();

  static bool get isWindows => _isWindows();

  static bool get isFuchsia => _isFuchsia();

  static bool get isLinux => _isLinux();

  static bool get isHarmonyOS => _isHarmonyOS();
}
