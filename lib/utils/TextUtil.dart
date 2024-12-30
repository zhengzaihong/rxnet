class TextUtil {
  TextUtil._();
  static bool isEmpty(String? str) {
    return str == null || str.isEmpty;
  }
  static bool isNotEmpty(String? str) {
    return !isEmpty(str);
  }
}
