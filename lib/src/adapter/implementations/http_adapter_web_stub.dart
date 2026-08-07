/// Web platform stub for dart:io types
/// 
/// This file provides stub definitions for dart:io types that are not
/// available on the Web platform. It's used via conditional imports.

// Stub class for File (not used on Web)
class File {
  File(String path);

  Directory get parent => Directory('');
  
  bool existsSync() => false;
  int lengthSync() => 0;
  
  dynamic openWrite() {
    throw UnsupportedError('File operations are not supported on Web platform');
  }
  
  String get path => '';
}

// Stub class for Directory (not used on Web)
class Directory {
  Directory(String path);

  bool existsSync() => false;
  void createSync({bool recursive = false}) {}
}

// Stub class for HttpHeaders constants used in shared code
class HttpHeaders {
  static const String contentTypeHeader = 'content-type';
  static const String contentLengthHeader = 'content-length';
  static const String rangeHeader = 'range';
  static const String contentRangeHeader = 'content-range';
}

// Stub class for MultipartFile (not used on Web)
class MultipartFile {
  static Future<MultipartFile> fromPath(
    String filePath, {
    String? filename,
    String? contentType,
  }) async {
    throw UnsupportedError('MultipartFile is not supported on Web platform');
  }
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
