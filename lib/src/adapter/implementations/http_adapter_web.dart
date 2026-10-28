/// HttpAdapter helper for Web platform
///
/// HttpAdapter Web 平台辅助文件

import 'package:http/http.dart' as http;

/// Creates the default http.Client for Web.
///
/// On Web, dart:io HttpClient / IOClient are unavailable, so a plain
/// [http.Client] is used. The optional [httpClient] argument is ignored.
///
/// 为 Web 平台创建默认的 http.Client。
/// Web 上不可用 dart:io HttpClient / IOClient，因此使用普通 http.Client。
http.Client createDefaultHttpClient([dynamic httpClient]) {
  return http.Client();
}
