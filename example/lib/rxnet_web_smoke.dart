/// CI Web 编译烟测入口。
///
/// 用于验证 `rxnet_lib`、DioAdapter、HttpAdapter、缓存与平台判断
/// 在 Web 条件导入分支下可以正常编译。
import 'package:flutter/widgets.dart';
import 'package:rxnet_plus/rxnet_lib.dart';
import 'package:rxnet_plus/utils/rx_net_database.dart';

void main() {
  // Force the Web conditional branches to be compiled.
  final dioAdapter = DioAdapter();
  final httpAdapter = HttpAdapter();
  final mockAdapter = MockAdapter();
  final database = RxNetDataBase();

  assert(dioAdapter.name.isNotEmpty);
  assert(httpAdapter.name.isNotEmpty);
  assert(mockAdapter.name.isNotEmpty);
  assert(database.runtimeType.toString().isNotEmpty);
  assert(RxNetPlatform.isWeb);

  runApp(const SizedBox.shrink());
}