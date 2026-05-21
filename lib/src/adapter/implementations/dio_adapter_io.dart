/// DioAdapter helper for non-Web platforms (IO platforms)
/// 
/// DioAdapter 非 Web 平台辅助文件

import 'package:dio/dio.dart';

/// 创建配置好的 Dio 实例（IO 平台）
/// Create configured Dio instance (IO platforms)
Dio createConfiguredDio() {
  // IO 平台：Dio 会自动使用 IOHttpClientAdapter
  // IO platforms: Dio will automatically use IOHttpClientAdapter
  return Dio(BaseOptions());
}
