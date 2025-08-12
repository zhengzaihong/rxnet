import 'dart:developer';

import 'package:flutter/foundation.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2021/6/9
/// create_time: 15:48
/// describe: 日志输出
///
class LogUtil {
  LogUtil._();

  static const String _TAG_DEFAULT = "RxNet：";

  ///是否 debug 默认调试为true 正式环境为false
  ///Whether to debug The default debugging is true, the official environment is false
  static bool _debugMode = kDebugMode;

  static String tagDefault = _TAG_DEFAULT;

  static bool _isSystemPrint = false;

  static void init({bool systemLog = false}) {
    _isSystemPrint = systemLog;
  }

  static void e(Object object, {String? tag}) {
    _printLog(tag ?? "", '  e  ', object);
  }

  static void v(Object object, {String? tag}) {
    if (RxNet.I.logManager.collectLogs) {
      RxNet.I.logManager.addLogs("${tag ?? tagDefault} ${object.toString()}");
    }
    if (_debugMode) {
      if (_isSystemPrint) {
        print("${tag ?? tagDefault} ${object.toString()}");
        return;
      }
      _printLog(tag ?? tagDefault, '', object);
    }
  }

  static void _printLog(String tag, String stag, Object object) {
    StringBuffer sb = StringBuffer();
    sb.write((tag.isEmpty) ? tagDefault : tag);
    sb.write(stag);
    sb.write(object);
    log(sb.toString());
    if (RxNet.I.logManager.collectLogs) {
      RxNet.I.logManager.addLogs(sb.toString());
    }
  }
}
