/// DioAdapter helper for Web platform
/// 
/// DioAdapter Web 平台辅助文件

import 'package:dio/dio.dart';
import 'package:dio/browser.dart';

/// 配置 Dio 适配器（Web 平台）
/// Configure Dio adapter (Web platform)
void configureDioAdapter(Dio dio) {
  // Web 平台需要使用 BrowserHttpClientAdapter
  // Web platform requires BrowserHttpClientAdapter
  dio.httpClientAdapter = BrowserHttpClientAdapter();
}
