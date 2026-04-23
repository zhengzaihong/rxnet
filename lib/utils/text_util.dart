///
/// author: zhengzaihong
/// email:1096877329@qq.com
/// date: 2025-08-12
/// time: 16:02
/// describe: 字符串工具
///
class TextUtil {
  TextUtil._();
  static bool isEmpty(String? str) {
    return str == null || str.isEmpty;
  }
  static bool isNotEmpty(String? str) {
    return !isEmpty(str);
  }
}
