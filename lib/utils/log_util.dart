// ignore_for_file: constant_identifier_names, avoid_print
import 'dart:developer';

import 'package:rxnet_plus/rxnet_lib.dart';

import '../src/rx_net.dart';

///
/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2021/6/9
/// time: 15:48
/// describe: 日志输出
///
class LogUtil {
  LogUtil._();

  static const String _TAG_DEFAULT = "RxNet：";

  ///是否 debug 默认关闭，避免生产环境输出敏感日志
  ///Whether to debug The default is off to avoid sensitive logs in production
  static bool _debugMode = false;

  static String tagDefault = _TAG_DEFAULT;

  static bool _isSystemPrint = false;

  static void init({bool systemLog = false, bool debug = false}) {
    _debugMode = debug;
    _isSystemPrint = systemLog;
  }

  static void e(Object object, {String? tag}) {
    if (!_debugMode) return;
    _printLog(tag ?? "", '  e  ', object);
  }

  static void v(Object object, {String? tag}) {
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
