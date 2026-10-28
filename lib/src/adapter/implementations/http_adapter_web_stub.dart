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
  String get path => '';

  RandomAccessFile openSync({int mode = FileMode.write}) {
    throw UnsupportedError('File operations are not supported on Web platform');
  }

  Stream<List<int>> openRead([int? start, int? end]) {
    throw UnsupportedError('File operations are not supported on Web platform');
  }

  dynamic openWrite() {
    throw UnsupportedError('File operations are not supported on Web platform');
  }
}

// Stub class for RandomAccessFile (not used on Web)
class RandomAccessFile {
  void writeFromSync(List<int> buffer) {}
  Future<void> close() async {}
}

// Stub class for Directory (not used on Web)
class Directory {
  Directory(String path);

  bool existsSync() => false;
  void createSync({bool recursive = false}) {}
}

// Stub for HttpHeaders constants used in shared code
class HttpHeaders {
  static const String contentTypeHeader = 'content-type';
  static const String contentLengthHeader = 'content-length';
  static const String rangeHeader = 'range';
  static const String contentRangeHeader = 'content-range';
}

// Stub for HttpStatus (mirrors dart:io HttpStatus)
class HttpStatus {
  static const int partialContent = 206;
  static const int requestedRangeNotSatisfiable = 416;
}

// Stub for FileMode (mirrors dart:io FileMode)
class FileMode {
  static const int write = 0;
  static const int append = 1;
  static const int read = 2;
  static const int writeOnly = 3;
  static const int readOnly = 4;
  static const int readWrite = 5;
  static const int writeOnlyAppend = 6;
}

// Stub for FileSystemException (mirrors dart:io FileSystemException)
class FileSystemException implements Exception {
  final String message;
  final String? path;

  FileSystemException(this.message, [this.path]);

  @override
  String toString() => 'FileSystemException: $message${path != null ? ', path = $path' : ''}';
}

// Stub for MultipartFile (not used on Web)
class MultipartFile {
  static Future<MultipartFile> fromPath(
    String filePath, {
    String? filename,
    String? contentType,
  }) async {
    throw UnsupportedError('MultipartFile is not supported on Web platform');
  }
}

// Stub for HttpClient (not supported on Web)
class HttpClient {
  Duration? connectionTimeout;
  Duration? idleTimeout;

  void close({bool force = false}) {}
}

// Stub for SocketException (not used on Web)
class SocketException implements Exception {
  final String message;
  SocketException(this.message);
}

// Stub for HttpException (not used on Web)
class HttpException implements Exception {
  final String message;
  HttpException(this.message);
}
