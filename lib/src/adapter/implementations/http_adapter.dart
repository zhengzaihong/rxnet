import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../net/type/http_method.dart';
import '../network_adapter.dart';
import '../models/adapter_request.dart';
import '../models/adapter_response.dart';
import '../interceptor/adapter_interceptor.dart';
import '../exceptions/adapter_exception.dart';
import '../cancel_token.dart' as adapter_cancel;

///
/// HttpAdapter - 基于 http 包的轻量级网络适配器 / Lightweight Network Adapter Based on http Package
/// 
/// author: ZhengZaiHong
/// email: 1096877329@qq.com
/// date: 2026-04-23
/// 
/// ============================================================================
/// 类说明 / Class Description
/// ============================================================================
/// 
/// HttpAdapter 是 RxNet Plus 的轻量级网络适配器，基于 Dart 官方的 http 包实现。
/// 它提供了基础的 HTTP 功能，适合对包大小敏感或不需要高级功能的场景。
/// 
/// HttpAdapter is a lightweight network adapter for RxNet Plus, based on
/// Dart's official http package. It provides basic HTTP functionality,
/// suitable for scenarios sensitive to package size or not requiring
/// advanced features.
/// 
/// ============================================================================
/// 核心特性 / Core Features
/// ============================================================================
/// 
/// 1. **轻量级 / Lightweight**
///    - 基于 Dart 官方 http 包，无额外依赖
///    - Based on Dart's official http package, no extra dependencies
///    - 包大小更小，适合简单场景
///    - Smaller package size, suitable for simple scenarios
/// 
/// 2. **基础 HTTP 支持 / Basic HTTP Support**
///    - 支持所有标准 HTTP 方法
///    - Support for all standard HTTP methods
///    - 支持请求头和查询参数
///    - Support for headers and query parameters
///    - 支持 JSON 和文本响应
///    - Support for JSON and text responses
/// 
/// 3. **拦截器支持 / Interceptor Support**
///    - 完整的 AdapterInterceptor 支持
///    - Full AdapterInterceptor support
///    - 与 DioAdapter 相同的拦截器接口
///    - Same interceptor interface as DioAdapter
/// 
/// 4. **请求取消 / Request Cancellation**
///    - 支持 RxNet 的 CancelToken
///    - Support for RxNet's CancelToken
///    - 基于 Completer 的取消机制
///    - Completer-based cancellation mechanism
/// 
/// 5. **自定义 Client / Custom Client**
///    - 可以传入自定义的 http.Client
///    - Can pass in custom http.Client
///    - 支持证书固定等高级配置
///    - Support for advanced configurations like certificate pinning
/// 
/// ============================================================================
/// 适用场景 / Use Cases
/// ============================================================================
/// 
/// ✅ 适合使用 HttpAdapter 的场景 / Suitable for HttpAdapter:
/// 
/// 1. **简单的 REST API 调用 / Simple REST API Calls**
///    - 基础的 GET/POST 请求
///    - Basic GET/POST requests
///    - 不需要复杂的拦截器逻辑
///    - No need for complex interceptor logic
/// 
/// 2. **包大小敏感的应用 / Size-Sensitive Applications**
///    - 需要减小应用体积
///    - Need to reduce app size
///    - 不需要 Dio 的高级功能
///    - Don't need Dio's advanced features
/// 
/// 3. **证书固定 / Certificate Pinning**
///    - 需要自定义 SSL/TLS 验证
///    - Need custom SSL/TLS validation
///    - 可以通过自定义 IOClient 实现
///    - Can be implemented via custom IOClient
/// 
/// ❌ 不适合使用 HttpAdapter 的场景 / Not Suitable for HttpAdapter:
/// 
/// 1. **文件上传下载 / File Upload/Download**
///    - HttpAdapter 不支持进度回调
///    - HttpAdapter doesn't support progress callbacks
///    - 建议使用 DioAdapter
///    - Recommend using DioAdapter
/// 
/// 2. **复杂的拦截器需求 / Complex Interceptor Requirements**
///    - 需要修改请求体或响应体
///    - Need to modify request/response body
///    - DioAdapter 提供更好的支持
///    - DioAdapter provides better support
/// 
/// 3. **流式响应 / Streaming Responses**
///    - HttpAdapter 不支持流式响应
///    - HttpAdapter doesn't support streaming responses
///    - 建议使用 DioAdapter
///    - Recommend using DioAdapter
/// 
/// ============================================================================
/// 使用示例 / Usage Examples
/// ============================================================================
/// 
/// 1. 基础使用 / Basic Usage:
/// ```dart
/// final api = RxNet.create();
/// await api.initNet(
///   baseUrl: "https://api.example.com",
///   adapter: HttpAdapter(),
/// );
/// 
/// final result = await api.getRequest()
///   .setPath("/users")
///   .request();
/// ```
/// 
/// 2. 使用自定义 Client / Using Custom Client:
/// ```dart
/// final httpClient = HttpClient();
/// httpClient.badCertificateCallback = (cert, host, port) {
///   // 自定义证书验证逻辑
///   // Custom certificate validation logic
///   return true;
/// };
/// 
/// final client = IOClient(httpClient);
/// final adapter = HttpAdapter(client: client);
/// 
/// await api.initNet(
///   baseUrl: "https://api.example.com",
///   adapter: adapter,
/// );
/// ```
/// 
/// 3. 证书固定示例 / Certificate Pinning Example:
/// ```dart
/// IOClient createPinnedClient() {
///   final httpClient = HttpClient();
///   httpClient.badCertificateCallback = (cert, host, port) {
///     // 获取证书指纹并验证
///     // Get certificate fingerprint and validate
///     final der = cert.der;
///     final sha256 = sha256Convert(der);
///     const trustedFingerprint = "YOUR_SHA256_FINGERPRINT";
///     return sha256 == trustedFingerprint;
///   };
///   return IOClient(httpClient);
/// }
/// 
/// final adapter = HttpAdapter(client: createPinnedClient());
/// ```
/// 
/// 4. 添加拦截器 / Adding Interceptors:
/// ```dart
/// final adapter = HttpAdapter();
/// adapter.addInterceptor(RxNetLogAdapterInterceptor());
/// adapter.addInterceptor(AuthInterceptor());
/// 
/// await api.initNet(
///   baseUrl: "https://api.example.com",
///   adapter: adapter,
/// );
/// ```
/// 
/// ============================================================================
/// 与 DioAdapter 的对比 / Comparison with DioAdapter
/// ============================================================================
/// 
/// | 特性 / Feature              | HttpAdapter | DioAdapter |
/// |----------------------------|-------------|------------|
/// | 包大小 / Package Size       | ✅ 小 / Small | ❌ 大 / Large |
/// | 基础请求 / Basic Requests   | ✅ 支持 / Yes | ✅ 支持 / Yes |
/// | 文件上传 / File Upload      | ⚠️ 基础 / Basic | ✅ 完整 / Full |
/// | 文件下载 / File Download    | ⚠️ 基础 / Basic | ✅ 完整 / Full |
/// | 进度回调 / Progress         | ❌ 不支持 / No | ✅ 支持 / Yes |
/// | 流式响应 / Streaming        | ❌ 不支持 / No | ✅ 支持 / Yes |
/// | 拦截器 / Interceptors       | ✅ 支持 / Yes | ✅ 支持 / Yes |
/// | 证书固定 / Cert Pinning     | ✅ 支持 / Yes | ✅ 支持 / Yes |
/// | 请求取消 / Cancellation     | ✅ 支持 / Yes | ✅ 支持 / Yes |
/// 
/// ============================================================================
/// 性能考虑 / Performance Considerations
/// ============================================================================
/// 
/// 1. **内存使用 / Memory Usage**
///    - HttpAdapter 内存占用更小
///    - HttpAdapter has smaller memory footprint
///    - 适合资源受限的设备
///    - Suitable for resource-constrained devices
/// 
/// 2. **请求速度 / Request Speed**
///    - 简单请求性能相当
///    - Similar performance for simple requests
///    - 复杂场景 DioAdapter 可能更快
///    - DioAdapter may be faster in complex scenarios
/// 
/// 3. **启动时间 / Startup Time**
///    - HttpAdapter 启动更快
///    - HttpAdapter starts faster
///    - 依赖更少，初始化更快
///    - Fewer dependencies, faster initialization
/// 
/// ============================================================================
/// 限制和注意事项 / Limitations and Notes
/// ============================================================================
/// 
/// 1. **不支持进度回调 / No Progress Callbacks**
///    - upload() 和 download() 方法的 onProgress 参数无效
///    - onProgress parameter in upload() and download() is ineffective
///    - 如需进度回调，请使用 DioAdapter
///    - Use DioAdapter if progress callbacks are needed
/// 
/// 2. **不支持流式响应 / No Streaming Responses**
///    - ResponseType.stream 会被当作 bytes 处理
///    - ResponseType.stream is treated as bytes
///    - 大文件下载可能占用较多内存
///    - Large file downloads may consume more memory
/// 
/// 3. **文件上传限制 / File Upload Limitations**
///    - 不支持 MultipartFile 类型
///    - MultipartFile type not supported
///    - 需要手动构建 multipart 请求
///    - Need to manually build multipart requests
/// 
/// 4. **取消机制 / Cancellation Mechanism**
///    - 基于 Completer，可能不如 Dio 的取消机制精确
///    - Based on Completer, may not be as precise as Dio's mechanism
///    - 请求可能已发送但被标记为取消
///    - Request may have been sent but marked as cancelled
/// 
/// ============================================================================
/// 
/// See also / 另见:
/// - [NetworkAdapter] for the adapter interface
/// - [DioAdapter] for a full-featured alternative
/// - [MockAdapter] for testing
/// - [AdapterInterceptor] for interceptor implementation
/// 
/// ============================================================================

/// HttpAdapter - http package-based implementation of NetworkAdapter
/// 
/// HttpAdapter - 基于 http 包的 NetworkAdapter 实现
/// 
/// This is a lightweight adapter that uses Dart's official http package.
/// It's suitable for simple scenarios where package size matters.
/// 
/// 这是一个使用 Dart 官方 http 包的轻量级适配器。
/// 适合对包大小敏感的简单场景。
class HttpAdapter implements NetworkAdapter {
  final http.Client _client;
  final List<AdapterInterceptor> _interceptors = [];
  final Map<adapter_cancel.CancelToken, List<Completer>> _pendingRequests = {};
  
  /// Creates an HttpAdapter.
  /// 
  /// 创建 HttpAdapter。
  /// 
  /// Parameters / 参数:
  /// - [client]: Optional custom http.Client instance. If not provided,
  ///             a default instance will be created.
  ///             可选的自定义 http.Client 实例。如果不提供，将创建默认实例。
  /// 
  /// Example / 示例:
  /// ```dart
  /// // Using default client / 使用默认 client
  /// final adapter = HttpAdapter();
  /// 
  /// // Using custom client / 使用自定义 client
  /// final client = IOClient(HttpClient());
  /// final adapter = HttpAdapter(client: client);
  /// ```
  HttpAdapter({http.Client? client}) : _client = client ?? http.Client();
  
  /// Gets the underlying http.Client instance.
  /// 
  /// 获取底层 http.Client 实例。
  /// 
  /// This allows direct access to the client for advanced configuration.
  /// 这允许直接访问 client 进行高级配置。
  http.Client get client => _client;
  
  @override
  String get name => 'HttpAdapter';
  
  @override
  String get version => '1.0.0';
  
  @override
  Future<AdapterResponse> request(AdapterRequest request) async {
    // 创建 Completer 用于取消 / Create Completer for cancellation
    final completer = Completer<AdapterResponse>();
    
    // 如果有 cancelToken，注册取消回调
    if (request.cancelToken != null) {
      _registerCancelToken(request.cancelToken!, completer);
      
      // 如果已经取消，立即抛出异常
      if (request.cancelToken!.isCancelled) {
        throw AdapterException(
          type: AdapterExceptionType.cancel,
          message: request.cancelToken!.cancelReason ?? 'Request cancelled',
        );
      }
    }
    
    try {
      // 执行请求拦截器
      var modifiedRequest = request;
      for (final interceptor in _interceptors) {
        final handler = RequestInterceptorHandler();
         interceptor.onRequest(modifiedRequest, handler);
        
        if (handler.resolvedResponse != null) {
          _unregisterCancelToken(request.cancelToken, completer);
          return handler.resolvedResponse!;
        }
        if (handler.rejectedError != null) {
          _unregisterCancelToken(request.cancelToken, completer);
          throw handler.rejectedError!;
        }
        if (handler.modifiedRequest != null) {
          modifiedRequest = handler.modifiedRequest!;
        }
      }
      
      // 构建 URI
      final uri = _buildUri(modifiedRequest);
      
      // 构建头部
      final headers = _buildHeaders(modifiedRequest);
      
      // 构建请求体
      final body = _buildBody(modifiedRequest);
      
      // 执行 HTTP 请求（使用 Future.any 支持取消）
      http.Response httpResponse;
      final requestFuture = _executeRequest(modifiedRequest.method, uri, headers, body);
      
      if (request.cancelToken != null) {
        httpResponse = await Future.any([
          requestFuture,
          completer.future.then((_) => throw AdapterException(
            type: AdapterExceptionType.cancel,
            message: request.cancelToken!.cancelReason ?? 'Request cancelled',
          )),
        ]);
      } else {
        httpResponse = await requestFuture;
      }
      
      // 转换响应
      var response = _convertFromHttpResponse(httpResponse, modifiedRequest);
      
      // 检查是否是错误响应
      if (!response.isSuccess) {
        final exception = AdapterException(
          message: 'HTTP ${response.statusCode}: ${response.statusMessage ?? ""}',
          type: AdapterExceptionType.response,
          statusCode: response.statusCode,
          response: response,
        );
        
        // 执行错误拦截器
        var modifiedException = exception;
        for (final interceptor in _interceptors) {
          final handler = ErrorInterceptorHandler();
           interceptor.onError(modifiedException, handler);
          
          if (handler.resolvedResponse != null) {
            _unregisterCancelToken(request.cancelToken, completer);
            return handler.resolvedResponse!;
          }
          if (handler.modifiedError != null) {
            modifiedException = handler.modifiedError!;
          }
        }
        
        _unregisterCancelToken(request.cancelToken, completer);
        throw modifiedException;
      }
      
      // 执行响应拦截器
      for (final interceptor in _interceptors) {
        final handler = ResponseInterceptorHandler();
         interceptor.onResponse(response, handler);
        
        if (handler.rejectedError != null) {
          _unregisterCancelToken(request.cancelToken, completer);
          throw handler.rejectedError!;
        }
        if (handler.modifiedResponse != null) {
          response = handler.modifiedResponse!;
        }
      }
      
      _unregisterCancelToken(request.cancelToken, completer);
      return response;
    } on AdapterException {
      _unregisterCancelToken(request.cancelToken, completer);
      rethrow;
    } catch (e, stackTrace) {
      _unregisterCancelToken(request.cancelToken, completer);
      var exception = _convertException(e, stackTrace);
      
      // 执行错误拦截器
      for (final interceptor in _interceptors) {
        final handler = ErrorInterceptorHandler();
         interceptor.onError(exception, handler);
        
        if (handler.resolvedResponse != null) {
          return handler.resolvedResponse!;
        }
        if (handler.modifiedError != null) {
          exception = handler.modifiedError!;
        }
      }
      
      throw exception;
    }
  }
  
  /// 执行 HTTP 请求
  Future<http.Response> _executeRequest(
    HttpMethod method,
    Uri uri,
    Map<String, String> headers,
    dynamic body,
  ) async {
    switch (method) {
      case HttpMethod.GET:
        return await _client.get(uri, headers: headers);
      case HttpMethod.POST:
        return await _client.post(uri, headers: headers, body: body);
      case HttpMethod.PUT:
        return await _client.put(uri, headers: headers, body: body);
      case HttpMethod.DELETE:
        return await _client.delete(uri, headers: headers, body: body);
      case HttpMethod.PATCH:
        return await _client.patch(uri, headers: headers, body: body);
      case HttpMethod.HEAD:
        return await _client.head(uri, headers: headers);
      case HttpMethod.OPTIONS:
        // http package doesn't have a built-in options method
        // We'll use a custom request
        final request = http.Request('OPTIONS', uri);
        request.headers.addAll(headers);
        final streamedResponse = await _client.send(request);
        return await http.Response.fromStream(streamedResponse);
      default:
        throw AdapterException(
          message: 'Unsupported HTTP method: $method',
          type: AdapterExceptionType.unknown,
        );
    }
  }
  
  /// 注册取消令牌
  void _registerCancelToken(adapter_cancel.CancelToken token, Completer completer) {
    if (!_pendingRequests.containsKey(token)) {
      _pendingRequests[token] = [];
    }
    _pendingRequests[token]!.add(completer);
    
    // 添加取消回调
    token.whenCancel((reason) {
      final completers = _pendingRequests[token];
      if (completers != null) {
        for (final c in completers) {
          if (!c.isCompleted) {
            c.completeError(AdapterException(
              type: AdapterExceptionType.cancel,
              message: reason ?? 'Request cancelled',
            ));
          }
        }
        _pendingRequests.remove(token);
      }
    });
  }
  
  /// 注销取消令牌
  void _unregisterCancelToken(adapter_cancel.CancelToken? token, Completer completer) {
    if (token != null && _pendingRequests.containsKey(token)) {
      _pendingRequests[token]!.remove(completer);
      if (_pendingRequests[token]!.isEmpty) {
        _pendingRequests.remove(token);
      }
    }
  }
  
  /// 构建 URI
  Uri _buildUri(AdapterRequest request) {
    final fullUrl = request.buildFullUrl();
    final uri = Uri.parse(fullUrl);
    
    if (request.queryParams.isEmpty) {
      return uri;
    }
    
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...request.queryParams.map((key, value) => MapEntry(key, value.toString())),
    });
  }
  
  /// 构建头部
  Map<String, String> _buildHeaders(AdapterRequest request) {
    final headers = <String, String>{};
    
    for (final entry in request.headers.entries) {
      if (entry.value is List) {
        headers[entry.key] = (entry.value as List).join(', ');
      } else {
        headers[entry.key] = entry.value.toString();
      }
    }
    
    // 如果有 contentType，添加到头部
    if (request.contentType != null && !headers.containsKey('content-type')) {
      headers['content-type'] = request.contentType!;
    }
    
    return headers;
  }
  
  /// 构建请求体
  dynamic _buildBody(AdapterRequest request) {
    // 如果有原始 body，直接使用
    if (request.rawBody != null) {
      return request.rawBody;
    }
    
    // 如果没有 body 参数，返回 null
    if (request.bodyParams.isEmpty) {
      return null;
    }
    
    // 根据 contentType 处理
    final contentType = request.contentType?.toLowerCase() ?? '';
    
    if (contentType.contains('application/json')) {
      return jsonEncode(request.bodyParams);
    } else if (contentType.contains('application/x-www-form-urlencoded')) {
      return request.bodyParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
    } else {
      // 默认使用 JSON
      return jsonEncode(request.bodyParams);
    }
  }
  
  /// 转换 http.Response 到 AdapterResponse
  AdapterResponse _convertFromHttpResponse(
    http.Response httpResponse,
    AdapterRequest request,
  ) {
    // 解析响应数据
    dynamic data;
    try {
      final contentType = httpResponse.headers['content-type'] ?? '';
      if (contentType.contains('application/json')) {
        data = jsonDecode(httpResponse.body);
      } else {
        data = httpResponse.body;
      }
    } catch (e) {
      data = httpResponse.body;
    }
    
    // 转换头部
    final headers = <String, List<String>>{};
    httpResponse.headers.forEach((key, value) {
      headers[key] = [value];
    });
    
    return AdapterResponse(
      statusCode: httpResponse.statusCode,
      statusMessage: httpResponse.reasonPhrase,
      data: data,
      headers: headers,
      request: request,
    );
  }
  
  /// 转换异常
  AdapterException _convertException(Object error, StackTrace stackTrace) {
    if (error is SocketException) {
      return AdapterException(
        message: 'Connection error: ${error.message}',
        type: AdapterExceptionType.connectionError,
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (error is TimeoutException) {
      return AdapterException(
        message: 'Request timeout: ${error.message ?? ""}',
        type: AdapterExceptionType.receiveTimeout,
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (error is HttpException) {
      return AdapterException(
        message: 'HTTP error: ${error.message}',
        type: AdapterExceptionType.response,
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (error.toString().contains('SocketException') || 
               error.toString().contains('Failed host lookup') ||
               error.toString().contains('Connection refused')) {
      // 处理包装的 SocketException
      return AdapterException(
        message: 'Connection error: ${error.toString()}',
        type: AdapterExceptionType.connectionError,
        originalError: error,
        stackTrace: stackTrace,
      );
    } else {
      return AdapterException(
        message: 'Unknown error: ${error.toString()}',
        type: AdapterExceptionType.unknown,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }
  
  @override
  Future<AdapterResponse> download(
    AdapterRequest request,
    String savePath, {
    ProgressCallback? onProgress,
  }) async {
    try {
      // 构建 URI
      final uri = _buildUri(request);
      
      // 构建头部
      final headers = _buildHeaders(request);
      
      // 创建请求
      final httpRequest = http.Request('GET', uri);
      httpRequest.headers.addAll(headers);
      
      // 发送请求
      final streamedResponse = await _client.send(httpRequest);
      
      // 检查状态码
      if (streamedResponse.statusCode >= 400) {
        throw AdapterException(
          message: 'HTTP ${streamedResponse.statusCode}',
          type: AdapterExceptionType.response,
          statusCode: streamedResponse.statusCode,
        );
      }
      
      // 下载文件
      final file = File(savePath);
      final sink = file.openWrite();
      
      var received = 0;
      final total = streamedResponse.contentLength ?? 0;
      
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        
        if (onProgress != null && total > 0) {
          onProgress(received, total);
        }
      }
      
      await sink.close();
      
      // 转换头部
      final responseHeaders = <String, List<String>>{};
      streamedResponse.headers.forEach((key, value) {
        responseHeaders[key] = [value];
      });
      
      return AdapterResponse(
        statusCode: streamedResponse.statusCode,
        statusMessage: streamedResponse.reasonPhrase,
        data: savePath,
        headers: responseHeaders,
        request: request,
      );
    } catch (e, stackTrace) {
      if (e is AdapterException) {
        rethrow;
      }
      throw _convertException(e, stackTrace);
    }
  }
  
  @override
  Future<AdapterResponse> upload(
    AdapterRequest request, {
    ProgressCallback? onProgress,
  }) async {
    try {
      // 构建 URI
      final uri = _buildUri(request);
      
      // 创建 multipart 请求
      final multipartRequest = http.MultipartRequest(
        request.method.name.toUpperCase(),
        uri,
      );
      
      // 添加头部
      final headers = _buildHeaders(request);
      multipartRequest.headers.addAll(headers);
      
      // 添加字段和文件
      for (final entry in request.bodyParams.entries) {
        if (entry.value is File) {
          final file = entry.value as File;
          multipartRequest.files.add(
            await http.MultipartFile.fromPath(entry.key, file.path),
          );
        } else if (entry.value is http.MultipartFile) {
          multipartRequest.files.add(entry.value as http.MultipartFile);
        } else {
          multipartRequest.fields[entry.key] = entry.value.toString();
        }
      }
      
      // 发送请求
      final streamedResponse = await multipartRequest.send();
      
      // 读取响应
      final responseBody = await streamedResponse.stream.bytesToString();
      
      // 解析响应数据
      dynamic data;
      try {
        final contentType = streamedResponse.headers['content-type'] ?? '';
        if (contentType.contains('application/json')) {
          data = jsonDecode(responseBody);
        } else {
          data = responseBody;
        }
      } catch (e) {
        data = responseBody;
      }
      
      // 转换头部
      final responseHeaders = <String, List<String>>{};
      streamedResponse.headers.forEach((key, value) {
        responseHeaders[key] = [value];
      });
      
      final response = AdapterResponse(
        statusCode: streamedResponse.statusCode,
        statusMessage: streamedResponse.reasonPhrase,
        data: data,
        headers: responseHeaders,
        request: request,
      );
      
      // 检查是否是错误响应
      if (!response.isSuccess) {
        throw AdapterException(
          message: 'HTTP ${response.statusCode}',
          type: AdapterExceptionType.response,
          statusCode: response.statusCode,
          response: response,
        );
      }
      
      return response;
    } catch (e, stackTrace) {
      if (e is AdapterException) {
        rethrow;
      }
      throw _convertException(e, stackTrace);
    }
  }
  
  @override
  void cancel(adapter_cancel.CancelToken token) {
    token.cancel();
  }
  
  @override
  void addInterceptor(AdapterInterceptor interceptor) {
    _interceptors.add(interceptor);
  }
  
  @override
  void removeInterceptor(AdapterInterceptor interceptor) {
    _interceptors.remove(interceptor);
  }
}
