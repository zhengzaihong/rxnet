/// DioAdapter helper for non-Web platforms (IO platforms)
/// 
/// DioAdapter 非 Web 平台辅助文件

import 'package:dio/dio.dart';

/// 配置 Dio 适配器（IO 平台）
/// Configure Dio adapter (IO platforms)
void configureDioAdapter(Dio dio) {
  // IO 平台不需要特殊配置，使用默认的 IOHttpClientAdapter
  // IO platforms don't need special configuration, use default IOHttpClientAdapter
  // Dio 会自动使用 IOHttpClientAdapter
  // Dio will automatically use IOHttpClientAdapter
}
