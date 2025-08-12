
import 'package:flutter/material.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2025-08-12
/// create_time: 16:28
/// describe: 抽离日志收集--调试窗口使用
///
class LogManager with ChangeNotifier {
  bool _isCollectLogs = false;
  final ValueNotifier<List<String>> logsNotifier = ValueNotifier([]);

  bool get collectLogs => _isCollectLogs;

  void setCollectLogs(bool collect) {
    _isCollectLogs = collect;
  }

  void addLogs(String log) {
    if (collectLogs) {
      logsNotifier.value.add(log);
      logsNotifier.notifyListeners();
    }
  }

  void clearLogs() {
    logsNotifier.value = [];
    logsNotifier.notifyListeners();
  }
}
