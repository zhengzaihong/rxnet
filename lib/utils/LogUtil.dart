import 'dart:developer';
///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2021/6/9
/// create_time: 15:48
/// describe: 日志输出
///
class LogUtil {
  static const String _TAG_DEFAULT = "###输出日志信息：";

  ///是否 debug
  static bool debug = false;

  static String tagDefault = _TAG_DEFAULT;

  static bool isSystemPrint = false;

  static void init({
    bool isDebug = false,
    String? tag,
    bool useSystemPrint = false
   }) {
    debug = isDebug;
    tagDefault = tag??_TAG_DEFAULT;
    isSystemPrint = useSystemPrint;
  }

  static void e(Object object, {String? tag}) {
    _printLog(tag??"", '  e  ', object);
  }

  static void v(Object object, {String? tag}) {
    if (debug) {
      if (isSystemPrint){
        print("${tag??tagDefault} ${object.toString()}");
        return;
      }
      _printLog(tag??"", '  v  ', object);
    }
  }

  static void _printLog(String tag, String stag, Object object) {
    StringBuffer sb = StringBuffer();
    sb.write((tag.isEmpty) ? tagDefault : tag);
    sb.write(stag);
    sb.write(object);
    log(sb.toString());
  }
}
