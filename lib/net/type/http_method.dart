///
/// author: zhengzaihong
/// email:1096877329@qq.com
/// date: 2025-01-31
/// describe: HTTP 请求方法枚举
///

/// HTTP method enumeration.
/// 
/// Defines the standard HTTP methods supported by RxNet Plus.
/// This enum is used across all adapters to ensure consistency.
enum HttpMethod {
  /// HTTP GET method - retrieves data from the server
  /// 
  /// Example:
  /// ```dart
  /// RxNet.get().setPath("/users").request();
  /// ```
  GET,
  
  /// HTTP POST method - submits data to the server
  /// 
  /// Example:
  /// ```dart
  /// RxNet.post()
  ///   .setPath("/users")
  ///   .setBodyParams({"name": "John"})
  ///   .asJson()
  ///   .request();
  /// ```
  POST,
  
  /// HTTP PUT method - updates existing data on the server
  /// 
  /// Example:
  /// ```dart
  /// RxNet.put()
  ///   .setPath("/users/123")
  ///   .setBodyParams({"name": "John Updated"})
  ///   .asJson()
  ///   .request();
  /// ```
  PUT,
  
  /// HTTP DELETE method - deletes data from the server
  /// 
  /// Example:
  /// ```dart
  /// RxNet.delete().setPath("/users/123").request();
  /// ```
  DELETE,
  
  /// HTTP PATCH method - partially updates data on the server
  /// 
  /// Example:
  /// ```dart
  /// RxNet.patch()
  ///   .setPath("/users/123")
  ///   .setBodyParams({"email": "new@example.com"})
  ///   .asJson()
  ///   .request();
  /// ```
  PATCH,
  
  /// HTTP HEAD method - retrieves headers only (no body)
  /// 
  /// Useful for checking if a resource exists or getting metadata
  /// without downloading the entire response body.
  /// 
  /// Example:
  /// ```dart
  /// RxNet.head().setPath("/users/123").request();
  /// ```
  HEAD,
  
  /// HTTP OPTIONS method - describes communication options
  /// 
  /// Used to determine which HTTP methods are supported by the server
  /// for a specific resource (CORS preflight requests).
  /// 
  /// Example:
  /// ```dart
  /// RxNet.options().setPath("/users").request();
  /// ```
  OPTIONS,
}

/// Extension methods for HttpMethod enum
extension HttpMethodExtension on HttpMethod {
  /// Returns the string representation of the HTTP method
  /// 
  /// Example:
  /// ```dart
  /// HttpMethod.GET.value // returns "GET"
  /// HttpMethod.POST.value // returns "POST"
  /// ```
  String get value {
    switch (this) {
      case HttpMethod.GET:
        return 'GET';
      case HttpMethod.POST:
        return 'POST';
      case HttpMethod.PUT:
        return 'PUT';
      case HttpMethod.DELETE:
        return 'DELETE';
      case HttpMethod.PATCH:
        return 'PATCH';
      case HttpMethod.HEAD:
        return 'HEAD';
      case HttpMethod.OPTIONS:
        return 'OPTIONS';
    }
  }
  
  /// Returns lowercase string representation
  /// 
  /// Example:
  /// ```dart
  /// HttpMethod.GET.name // returns "get"
  /// ```
  String get name => value.toLowerCase();
}
