import 'package:http/http.dart' as http;

/// Web 平台：使用普通 http.Client。
///
/// 浏览器证书校验由浏览器负责，不能使用 dart:io 的 IOClient。
http.Client createPinnedClient() {
  return http.Client();
}