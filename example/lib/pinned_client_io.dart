import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// IO 平台：创建带证书固定回调的客户端。
///
/// 生产环境必须校验固定指纹，不能直接 return true。
http.Client createPinnedClient() {
  final httpClient = HttpClient();
  httpClient.badCertificateCallback =
      (X509Certificate cert, String host, int port) {
    // 默认拒绝未固定证书；生产环境替换为指纹校验。
    return false;
  };
  return IOClient(httpClient);
}