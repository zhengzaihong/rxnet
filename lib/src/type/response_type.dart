///
/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2025-01-31
/// describe: 响应类型枚举

/// Response type enumeration.
///
/// Defines how the response body should be parsed by the adapter.
/// Different adapters may handle these types differently, but the
/// semantic meaning remains consistent.
enum ResponseType {
  /// Parse response as JSON (default)
  /// 
  /// The response body will be automatically parsed as JSON.
  /// This is the most common response type for REST APIs.
  /// 
  /// Example:
  /// ```dart
  /// RxNet.get()
  ///   .setPath("/users")
  ///   .setResponseType(ResponseType.json)
  ///   .request();
  /// ```
  json,
  
  /// Return response as a stream
  /// 
  /// The response body will be returned as a stream of bytes.
  /// Useful for large files or real-time data.
  /// 
  /// Example:
  /// ```dart
  /// RxNet.get()
  ///   .setPath("/large-file")
  ///   .setResponseType(ResponseType.stream)
  ///   .request();
  /// ```
  stream,
  
  /// Return response as plain text
  /// 
  /// The response body will be returned as a plain string.
  /// Useful for HTML, XML, or other text-based formats.
  /// 
  /// Example:
  /// ```dart
  /// RxNet.get()
  ///   .setPath("/page.html")
  ///   .setResponseType(ResponseType.plain)
  ///   .request();
  /// ```
  plain,
  
  /// Return response as raw bytes
  /// 
  /// The response body will be returned as raw bytes (Uint8List).
  /// Useful for binary data like images, PDFs, etc.
  /// 
  /// Example:
  /// ```dart
  /// RxNet.get()
  ///   .setPath("/image.png")
  ///   .setResponseType(ResponseType.bytes)
  ///   .request();
  /// ```
  bytes,
}

/// Extension methods for ResponseType enum
extension ResponseTypeExtension on ResponseType {
  /// Returns the string representation of the response type
  /// 
  /// Example:
  /// ```dart
  /// ResponseType.json.value // returns "json"
  /// ResponseType.stream.value // returns "stream"
  /// ```
  String get value {
    switch (this) {
      case ResponseType.json:
        return 'json';
      case ResponseType.stream:
        return 'stream';
      case ResponseType.plain:
        return 'plain';
      case ResponseType.bytes:
        return 'bytes';
    }
  }
  
  /// Returns whether this response type is JSON
  bool get isJson => this == ResponseType.json;
  
  /// Returns whether this response type is a stream
  bool get isStream => this == ResponseType.stream;
  
  /// Returns whether this response type is plain text
  bool get isPlain => this == ResponseType.plain;
  
  /// Returns whether this response type is bytes
  bool get isBytes => this == ResponseType.bytes;
}
