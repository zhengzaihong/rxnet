/// Web platform stub for dart:io types
/// 
/// This file provides stub definitions for dart:io types that are not
/// available on the Web platform. It's used via conditional imports.
/// 
/// Web 平台的 dart:io 类型存根
/// 
/// 此文件为 Web 平台上不可用的 dart:io 类型提供存根定义。
/// 通过条件导入使用。

// Stub class for File (not used on Web)
class File {
  File(String path);
  
  dynamic openWrite() {
    throw UnsupportedError('File operations are not supported on Web platform');
  }
  
  String get path => throw UnsupportedError('File.path is not supported on Web platform');
}

// Stub class for SocketException (not used on Web)
class SocketException implements Exception {
  final String message;
  SocketException(this.message);
}

// Stub class for HttpException (not used on Web)
class HttpException implements Exception {
  final String message;
  HttpException(this.message);
}
