/// DioAdapter helper for Web platform
/// 
/// DioAdapter Web 平台辅助文件

import 'package:dio/dio.dart';

import '../models/adapter_base_options.dart';

/// 创建配置好的 Dio 实例（Web 平台）
/// Create configured Dio instance (Web platform)
Dio createConfiguredDio() {
  // Web 平台：Dio 5.x 会自动使用 dio_web_adapter
  // 不需要手动设置任何适配器，Dio 会根据平台自动选择
  // Web platform: Dio 5.x automatically uses dio_web_adapter
  // No need to manually set any adapter, Dio will automatically select based on platform
  return Dio(BaseOptions(
    connectTimeout: AdapterBaseOptions.defaultConnectTimeout,
    receiveTimeout: AdapterBaseOptions.defaultReceiveTimeout,
    sendTimeout: AdapterBaseOptions.defaultSendTimeout,
  ));
}
