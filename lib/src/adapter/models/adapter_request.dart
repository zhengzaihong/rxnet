import '../../../net/type/http_method.dart';
import '../../../net/type/response_type.dart';
import '../network_adapter.dart';
import '../cancel_token.dart';


/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2026-04-21 16:03
/// describe: request adapter

/// Unified request configuration model.
///
/// This class encapsulates all the information needed to make an HTTP request,
/// abstracting away the differences between various HTTP client libraries.
///
/// ## Basic Usage
///
/// ```dart
/// final request = AdapterRequest(
///   baseUrl: 'https://api.example.com',
///   path: '/users/123',
///   method: HttpMethod.get,
/// );
/// ```
///
/// ## RESTful Parameters
///
/// Use [pathParams] for RESTful URL parameters:
///
/// ```dart
/// final request = AdapterRequest(
///   baseUrl: 'https://api.example.com',
///   path: '/users/{id}/posts/{postId}',
///   method: HttpMethod.get,
///   pathParams: {'id': '123', 'postId': '456'},
/// );
/// // Results in: https://api.example.com/users/123/posts/456
/// ```
///
/// ## Query Parameters
///
/// Use [queryParams] for URL query strings:
///
/// ```dart
/// final request = AdapterRequest(
///   baseUrl: 'https://api.example.com',
///   path: '/users',
///   method: HttpMethod.get,
///   queryParams: {'page': 1, 'limit': 20},
/// );
/// // Results in: https://api.example.com/users?page=1&limit=20
/// ```
///
/// ## Request Body
///
/// Use [bodyParams] for structured data or [rawBody] for raw data:
///
/// ```dart
/// // JSON body
/// final request = AdapterRequest(
///   baseUrl: 'https://api.example.com',
///   path: '/users',
///   method: HttpMethod.post,
///   bodyParams: {'name': 'John', 'email': 'john@example.com'},
///   contentType: 'application/json',
/// );
///
/// // Raw body
/// final request = AdapterRequest(
///   baseUrl: 'https://api.example.com',
///   path: '/upload',
///   method: HttpMethod.post,
///   rawBody: 'raw text data',
///   contentType: 'text/plain',
/// );
/// ```
///
/// See also:
/// - [AdapterResponse] for response structure
/// - [NetworkAdapter.request] for making requests
class AdapterRequest {
  // true → 同一个对象.false → 不是同一个对象
  // true → same object. false → not the same object
  static const Object _unset = Object();

  /// Base URL of the API.
  ///
  /// Example: 'https://api.example.com'
  final String baseUrl;
  
  /// Request path, optionally with RESTful parameters.
  ///
  /// Use curly braces for RESTful parameters: '/users/{id}'
  final String path;
  
  /// HTTP method for the request.
  final HttpMethod method;
  
  /// RESTful path parameters.
  ///
  /// Keys should match placeholders in [path].
  /// Example: {'id': '123'} for path '/users/{id}'
  final Map<String, dynamic> pathParams;
  
  /// URL query parameters.
  ///
  /// These will be appended to the URL as a query string.
  /// Example: {'page': 1, 'limit': 20} becomes '?page=1&limit=20'
  final Map<String, dynamic> queryParams;
  
  /// Request body parameters (for structured data).
  ///
  /// Used for JSON, form data, or URL-encoded bodies.
  /// The actual encoding depends on [contentType].
  final Map<String, dynamic> bodyParams;
  
  /// Raw request body (for unstructured data).
  ///
  /// Use this for raw strings, bytes, or custom data formats.
  /// Takes precedence over [bodyParams] if both are provided.
  final dynamic rawBody;
  
  /// Request headers.
  ///
  /// Example: {'Authorization': 'Bearer token', 'Accept': 'application/json'}
  final Map<String, dynamic> headers;
  
  /// Content-Type header value.
  ///
  /// Common values:
  /// - 'application/json'
  /// - 'application/x-www-form-urlencoded'
  /// - 'multipart/form-data'
  /// - 'text/plain'
  final String? contentType;
  
  /// Expected response type.
  ///
  /// Determines how the response body will be parsed.
  final ResponseType responseType;
  
  /// Connection timeout duration.
  ///
  /// If the connection cannot be established within this duration,
  /// an [AdapterException] with type [AdapterExceptionType.connectTimeout]
  /// will be thrown.
  final Duration? connectTimeout;
  
  /// Receive timeout duration.
  ///
  /// If no data is received within this duration after the connection
  /// is established, an [AdapterException] with type
  /// [AdapterExceptionType.receiveTimeout] will be thrown.
  final Duration? receiveTimeout;
  
  /// Send timeout duration.
  ///
  /// If data cannot be sent within this duration, an [AdapterException]
  /// with type [AdapterExceptionType.sendTimeout] will be thrown.
  final Duration? sendTimeout;
  
  /// Cancel token for request cancellation.
  ///
  /// Use this to cancel the request programmatically.
  /// See [NetworkAdapter.cancel] for details.
  final CancelToken? cancelToken;
  
  /// Extra configuration data.
  ///
  /// Can be used to pass adapter-specific configuration or metadata.
  final Map<String, dynamic> extra;
  
  /// Creates a new [AdapterRequest].
  ///
  /// Required parameters:
  /// - [baseUrl]: The base URL of the API
  /// - [path]: The request path
  /// - [method]: The HTTP method
  ///
  /// All other parameters are optional and have sensible defaults.
  const AdapterRequest({
    required this.baseUrl,
    required this.path,
    required this.method,
    this.pathParams = const {},
    this.queryParams = const {},
    this.bodyParams = const {},
    this.rawBody,
    this.headers = const {},
    this.contentType,
    this.responseType = ResponseType.json,
    this.connectTimeout,
    this.receiveTimeout,
    this.sendTimeout,
    this.cancelToken,
    this.extra = const {},
  });
  
  /// Builds the full URL by combining [baseUrl], [path], and [pathParams].
  ///
  /// RESTful parameters in [path] (enclosed in curly braces) are replaced
  /// with corresponding values from [pathParams].
  ///
  /// Example:
  /// ```dart
  /// final request = AdapterRequest(
  ///   baseUrl: 'https://api.example.com',
  ///   path: '/users/{id}/posts/{postId}',
  ///   method: HttpMethod.get,
  ///   pathParams: {'id': '123', 'postId': '456'},
  /// );
  /// print(request.buildFullUrl());
  /// // Output: https://api.example.com/users/123/posts/456
  /// ```
  ///
  /// Note: Query parameters are not included in the returned URL.
  /// They are handled separately by the adapter.
  String buildFullUrl() {
    String url = path;
    
    // 处理 RESTful 参数替换
    pathParams.forEach((key, value) {
      url = url.replaceAll('{$key}', Uri.encodeComponent(value.toString()));
    });
    
    // 如果 path 已经是完整 URL（以 http:// 或 https:// 开头），直接返回
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    
    // 智能拼接 baseUrl 和 path，处理斜杠
    // 确保 baseUrl 和 path 之间有且仅有一个斜杠
    String fullUrl = baseUrl;
    
    // 移除 baseUrl 末尾的斜杠
    if (fullUrl.endsWith('/')) {
      fullUrl = fullUrl.substring(0, fullUrl.length - 1);
    }
    
    // 确保 path 以斜杠开头
    if (!url.startsWith('/')) {
      url = '/$url';
    }
    
    return fullUrl + url;
  }
  
  /// Creates a copy of this request with some fields replaced.
  ///
  /// This is useful for modifying requests in interceptors or creating
  /// variations of a base request.
  ///
  /// Example:
  /// ```dart
  /// final baseRequest = AdapterRequest(
  ///   baseUrl: 'https://api.example.com',
  ///   path: '/users',
  ///   method: HttpMethod.get,
  /// );
  ///
  /// // Add authentication header
  /// final authenticatedRequest = baseRequest.copyWith(
  ///   headers: {...baseRequest.headers, 'Authorization': 'Bearer token'},
  /// );
  /// ```
  AdapterRequest copyWith({
    String? baseUrl,
    String? path,
    HttpMethod? method,
    Map<String, dynamic>? pathParams,
    Map<String, dynamic>? queryParams,
    Map<String, dynamic>? bodyParams,
    Object? rawBody = _unset,
    Map<String, dynamic>? headers,
    Object? contentType = _unset,
    ResponseType? responseType,
    Object? connectTimeout = _unset,
    Object? receiveTimeout = _unset,
    Object? sendTimeout = _unset,
    Object? cancelToken = _unset,
    Map<String, dynamic>? extra,
  }) {
    return AdapterRequest(
      baseUrl: baseUrl ?? this.baseUrl,
      path: path ?? this.path,
      method: method ?? this.method,
      pathParams: pathParams ?? this.pathParams,
      queryParams: queryParams ?? this.queryParams,
      bodyParams: bodyParams ?? this.bodyParams,
      rawBody: identical(rawBody, _unset) ? this.rawBody : rawBody,
      headers: headers ?? this.headers,
      contentType: identical(contentType, _unset)
          ? this.contentType
          : contentType as String?,
      responseType: responseType ?? this.responseType,
      connectTimeout: identical(connectTimeout, _unset)
          ? this.connectTimeout
          : connectTimeout as Duration?,
      receiveTimeout: identical(receiveTimeout, _unset)
          ? this.receiveTimeout
          : receiveTimeout as Duration?,
      sendTimeout: identical(sendTimeout, _unset)
          ? this.sendTimeout
          : sendTimeout as Duration?,
      cancelToken: identical(cancelToken, _unset)
          ? this.cancelToken
          : cancelToken as CancelToken?,
      extra: extra ?? this.extra,
    );
  }
  
  @override
  String toString() {
    return 'AdapterRequest(method: $method, url: ${buildFullUrl()}, '
        'queryParams: $queryParams, bodyParams: $bodyParams)';
  }
}
