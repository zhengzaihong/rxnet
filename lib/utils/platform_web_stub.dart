/// Web/Wasm 平台 `Platform` 替身。
///
/// 条件导入在 Web 上使用本文件，避免引入 `dart:io`。
class Platform {
  Platform._();

  static bool get isAndroid => false;
  static bool get isIOS => false;
  static bool get isMacOS => false;
  static bool get isWindows => false;
  static bool get isFuchsia => false;
  static bool get isLinux => false;

  static String get operatingSystem => 'web';
}