/// HttpAdapter helper for non-Web platforms (IO platforms)
///
/// HttpAdapter 非 Web 平台辅助文件

import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

/// Creates the default http.Client for IO platforms.
///
/// 为 IO 平台创建默认的 http.Client。
http.Client createDefaultHttpClient([HttpClient? httpClient]) {
  return IOClient(httpClient ?? HttpClient());
}
