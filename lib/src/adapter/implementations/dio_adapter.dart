import 'dart:async';
import 'package:dio/dio.dart';
import '../../../net/type/http_method.dart';
import '../../../net/type/response_type.dart' as adapter_model;
import '../network_adapter.dart' hide ProgressCallback;
import '../models/adapter_request.dart';
import '../models/adapter_response.dart';
import '../interceptor/adapter_interceptor.dart' hide RequestInterceptorHandler, ResponseInterceptorHandler, ErrorInterceptorHandler;
import '../interceptor/adapter_interceptor.dart' as adapter_interceptor;
import '../exceptions/adapter_exception.dart';
import '../cancel_token.dart' as adapter_cancel;

// 条件导入：Web 平台导入 web 辅助文件，其他平台导入 io 辅助文件
// Conditional import: web helper for Web, io helper for other platforms
import 'dio_adapter_io.dart' if (dart.library.html) 'dio_adapter_web.dart' show createConfiguredDio;

///
/// author: ZhengZaiHong
/// email: 1096877329@qq.com
/// date: 2026-04-23
/// describe: DioAdapter - 基于 Dio 的网络适配器 / Dio-based Network Adapter
/// ============================================================================
/// 类说明 / Class Description
/// ============================================================================
/// 
/// DioAdapter 是 RxNet Plus 的默认网络适配器，基于强大的 Dio 库实现。
/// 它提供了完整的 HTTP 功能，包括拦截器、文件上传下载、请求取消等。
/// 
/// DioAdapter is the default network adapter for RxNet Plus, based on the
/// powerful Dio library. It provides complete HTTP functionality including
/// interceptors, file upload/download, request cancellation, etc.
/// 
/// ============================================================================
/// 核心特性 / Core Features
/// ============================================================================
/// 
/// 1. **完整的 HTTP 支持 / Complete HTTP Support**
///    - 支持所有 HTTP 方法（GET、POST、PUT、DELETE 等）
///    - Support for all HTTP methods (GET, POST, PUT, DELETE, etc.)
///    - 支持文件上传和下载
///    - Support for file upload and download
///    - 支持流式响应
///    - Support for streaming responses
/// 
/// 2. **拦截器系统 / Interceptor System**
///    - 统一的 AdapterInterceptor 接口
///    - Unified AdapterInterceptor interface
///    - 在 Dio 请求前执行，保留完整的请求信息
///    - Executed before Dio requests, preserving complete request information
///    - 支持请求、响应、错误拦截
///    - Support for request, response, and error interception
/// 
/// 3. **请求取消 / Request Cancellation**
///    - 支持 RxNet 的 CancelToken
///    - Support for RxNet's CancelToken
///    - 向后兼容 Dio 的 CancelToken
///    - Backward compatible with Dio's CancelToken
/// 
/// 4. **自动类型转换 / Automatic Type Conversion**
///    - 自动转换 AdapterRequest 到 Dio RequestOptions
///    - Automatically convert AdapterRequest to Dio RequestOptions
///    - 自动转换 Dio Response 到 AdapterResponse
///    - Automatically convert Dio Response to AdapterResponse
///    - 自动转换异常类型
///    - Automatically convert exception types
/// 
/// 5. **灵活的配置 / Flexible Configuration**
///    - 可以传入自定义的 Dio 实例
///    - Can pass in custom Dio instance
///    - 支持所有 Dio 配置选项
///    - Support for all Dio configuration options
/// 
/// ============================================================================
/// 使用示例 / Usage Examples
/// ============================================================================
/// 
/// 1. 使用默认 DioAdapter / Using Default DioAdapter:
/// ```dart
/// await RxNet.init(
///   baseUrl: "https://api.example.com",
///   // DioAdapter 是默认适配器，无需显式指定
///   // DioAdapter is the default adapter, no need to specify explicitly
/// );
/// ```
/// 
/// 2. 使用自定义 Dio 实例 / Using Custom Dio Instance:
/// ```dart
/// final dio = Dio(BaseOptions(
///   connectTimeout: Duration(seconds: 30),
///   receiveTimeout: Duration(seconds: 30),
/// ));
/// 
/// final adapter = DioAdapter(dio: dio);
/// await RxNet.init(
///   baseUrl: "https://api.example.com",
///   adapter: adapter,
/// );
/// ```
/// 
/// 3. 添加拦截器 / Adding Interceptors:
/// ```dart
/// final adapter = DioAdapter();
/// adapter.addInterceptor(RxNetLogAdapterInterceptor());
/// adapter.addInterceptor(AuthInterceptor());
/// 
/// await RxNet.init(
///   baseUrl: "https://api.example.com",
///   adapter: adapter,
/// );
/// ```
/// 
/// 4. 访问底层 Dio 实例 / Accessing Underlying Dio Instance:
/// ```dart
/// final adapter = DioAdapter();
/// final dio = adapter.dio;
/// 
/// // 配置 Dio
/// // Configure Dio
/// dio.options.connectTimeout = Duration(seconds: 30);
/// dio.interceptors.add(LogInterceptor());
/// ```
/// 
/// ============================================================================
/// 拦截器执行流程 / Interceptor Execution Flow
/// ============================================================================
/// 
/// 在 0.6.0 版本中，拦截器执行流程已优化：
/// In version 0.6.0, the interceptor execution flow has been optimized:
/// 
/// 1. BuildRequest 创建 AdapterRequest（包含 bodyParams）
///    BuildRequest creates AdapterRequest (with bodyParams)
///    ↓
/// 2. DioAdapter.request() 接收 AdapterRequest
///    DioAdapter.request() receives AdapterRequest
///    ↓
/// 3. 执行 AdapterInterceptor（可访问完整的 bodyParams）
///    Execute AdapterInterceptor (can access complete bodyParams)
///    ↓
/// 4. 转换为 Dio RequestOptions
///    Convert to Dio RequestOptions
///    ↓
/// 5. 调用 Dio.request()
///    Call Dio.request()
///    ↓
/// 6. 转换 Dio Response 为 AdapterResponse
///    Convert Dio Response to AdapterResponse
///    ↓
/// 7. 执行响应拦截器
///    Execute response interceptors
///    ↓
/// 8. 返回 AdapterResponse
///    Return AdapterResponse
/// 
/// 注意：拦截器在 Dio 请求前执行，避免了信息丢失和重复执行的问题。
/// Note: Interceptors are executed before Dio requests, avoiding information
/// loss and duplicate execution issues.
/// 
/// ============================================================================
/// 类型转换 / Type Conversion
/// ============================================================================
/// 
/// DioAdapter 负责在 RxNet 类型和 Dio 类型之间进行转换：
/// DioAdapter handles conversion between RxNet types and Dio types:
/// 
/// - HttpMethod ↔ String (GET, POST, etc.)
/// - ResponseType ↔ Dio ResponseType
/// - AdapterRequest ↔ Dio RequestOptions
/// - AdapterResponse ↔ Dio Response
/// - AdapterException ↔ DioException
/// - CancelToken ↔ Dio CancelToken
/// 
/// ============================================================================
/// 性能考虑 / Performance Considerations
/// ============================================================================
/// 
/// 1. **拦截器开销 / Interceptor Overhead**
///    - 拦截器按顺序执行，避免添加过多拦截器
///    - Interceptors execute sequentially, avoid adding too many
/// 
/// 2. **类型转换 / Type Conversion**
///    - 类型转换开销很小，可以忽略
///    - Type conversion overhead is minimal and negligible
/// 
/// 3. **内存使用 / Memory Usage**
///    - 每个请求创建新的对象，请求完成后会被垃圾回收
///    - New objects created for each request, garbage collected after completion
/// 
/// ============================================================================
/// 注意事项 / Notes
/// ============================================================================
/// 
/// 1. DioAdapter 是默认适配器，通常不需要显式创建
///    DioAdapter is the default adapter, usually no need to create explicitly
/// 
/// 2. 如果需要自定义 Dio 配置，可以传入自定义 Dio 实例
///    If custom Dio configuration is needed, pass in a custom Dio instance
/// 
/// 3. 拦截器通过 addInterceptor() 添加，不要直接操作 Dio 的拦截器
///    Add interceptors via addInterceptor(), don't manipulate Dio's interceptors directly
/// 
/// 4. 取消令牌会自动在 RxNet CancelToken 和 Dio CancelToken 之间转换
///    Cancel tokens are automatically converted between RxNet and Dio CancelTokens
/// 
/// ============================================================================
/// 
/// See also / 另见:
/// - [NetworkAdapter] for the adapter interface
/// - [HttpAdapter] for a lightweight alternative
/// - [MockAdapter] for testing
/// - [AdapterInterceptor] for interceptor implementation
/// 
/// ============================================================================

/// Internal exception: Interceptor returns early response
/// 
/// 内部异常：拦截器提前返回响应
/// 
/// This exception is used internally when an interceptor decides to return
/// a response directly without making the actual HTTP request.
/// 
/// 当拦截器决定直接返回响应而不发起实际 HTTP 请求时，使用此异常。
class _EarlyResponseException implements Exception {
  final AdapterResponse response;
  _EarlyResponseException(this.response);
}

/// DioAdapter - Dio-based implementation of NetworkAdapter
/// 
/// DioAdapter - 基于 Dio 的 NetworkAdapter 实现
/// 
/// This is the default and most feature-complete adapter for RxNet Plus.
/// It leverages the powerful Dio library to provide comprehensive HTTP
/// functionality.
/// 
/// 这是 RxNet Plus 的默认且功能最完整的适配器。
/// 它利用强大的 Dio 库提供全面的 HTTP 功能。
class DioAdapter implements NetworkAdapter {
  final Dio _dio;
  final List<AdapterInterceptor> _interceptors = [];
  final Map<adapter_cancel.CancelToken, CancelToken> _cancelTokenMap = {};
  
  /// Creates a DioAdapter.
  /// 
  /// 创建 DioAdapter。
  /// 
  /// Parameters / 参数:
  /// - [dio]: Optional custom Dio instance. If not provided, a platform-specific
  ///          default instance will be created.
  ///          可选的自定义 Dio 实例。如果不提供，将创建平台特定的默认实例。
  /// 
  /// Example / 示例:
  /// ```dart
  /// // Using default Dio / 使用默认 Dio
  /// final adapter = DioAdapter();
  /// 
  /// // Using custom Dio / 使用自定义 Dio
  /// final dio = Dio(BaseOptions(connectTimeout: Duration(seconds: 30)));
  /// final adapter = DioAdapter(dio: dio);
  /// ```
  /// 
  /// Note / 注意:
  /// On Web platform, the Dio instance is automatically configured for Web.
  /// 
  /// 在 Web 平台上，Dio 实例会自动配置为 Web 平台。
  DioAdapter({Dio? dio}) : _dio = dio ?? createConfiguredDio();
  
  /// Creates a DioAdapter with BaseOptions.
  /// 
  /// 使用 BaseOptions 创建 DioAdapter。
  /// 
  /// This factory method creates a platform-specific Dio instance with the
  /// provided BaseOptions.
  /// 
  /// 此工厂方法使用提供的 BaseOptions 创建平台特定的 Dio 实例。
  /// 
  /// Parameters / 参数:
  /// - [options]: BaseOptions for configuring Dio
  ///              用于配置 Dio 的 BaseOptions
  /// 
  /// Example / 示例:
  /// ```dart
  /// final adapter = DioAdapter.withOptions(
  ///   BaseOptions(
  ///     baseUrl: "https://api.example.com",
  ///     connectTimeout: Duration(seconds: 30),
  ///   ),
  /// );
  /// ```
  factory DioAdapter.withOptions(BaseOptions options) {
    final dio = createConfiguredDio();
    dio.options = options;
    return DioAdapter(dio: dio);
  }
  
  /// Gets the underlying Dio instance.
  /// 
  /// 获取底层 Dio 实例。
  /// 
  /// This allows direct access to Dio for advanced configuration.
  /// 这允许直接访问 Dio 进行高级配置。
  /// 
  /// Example / 示例:
  /// ```dart
  /// final adapter = DioAdapter();
  /// adapter.dio.options.connectTimeout = Duration(seconds: 30);
  /// ```
  Dio get dio => _dio;
  
  @override
  String get name => 'DioAdapter';
  
  @override
  String get version => '1.0.0';
  
  @override
  Future<AdapterResponse> request(AdapterRequest request) async {
    try {
      // 先执行请求拦截器
      final interceptedRequest = await _executeRequestInterceptors(request);
      
      // 转换 AdapterRequest 到 Dio RequestOptions
      final options = _convertToOptions(interceptedRequest);
      
      // 构建请求体
      final requestBody = _buildRequestBody(interceptedRequest);
      
      // 转换 CancelToken
      final dioCancelToken = _convertCancelToken(interceptedRequest.cancelToken);
      
      // 构建完整 URL，统一处理 baseUrl/path 斜杠和 RESTful 参数替换。
      // 这避免了 `baseUrl` 无尾斜杠且 `path` 无前导斜杠时，
      // Dio 将它们拼成 `hostpath` 的问题。
      final requestUrl = interceptedRequest.buildFullUrl();
      final response = await _dio.request(
        requestUrl,
        data: requestBody,
        queryParameters: interceptedRequest.queryParams,
        options: options,
        cancelToken: dioCancelToken,
      );
      
      // 转换 Dio Response 到 AdapterResponse
      var adapterResponse = _convertFromResponse(response, interceptedRequest);
      
      // 执行响应拦截器
      adapterResponse = await _executeResponseInterceptors(adapterResponse);
      
      return adapterResponse;
    } on _EarlyResponseException catch (e) {
      // 拦截器提前返回了响应
      return e.response;
    } on DioException catch (e) {
      // 执行错误拦截器
      var exception = _convertException(e);
      exception = await _executeErrorInterceptors(exception);
      throw exception;
    } catch (e) {
      // 其他错误也通过错误拦截器
      var exception = AdapterException(
        message: e.toString(),
        type: AdapterExceptionType.unknown,
        originalError: e,
      );
      exception = await _executeErrorInterceptors(exception);
      throw exception;
    }
  }
  
  /// 执行请求拦截器
  Future<AdapterRequest> _executeRequestInterceptors(AdapterRequest request) async {
    var currentRequest = request;
    
    for (final interceptor in _interceptors) {
      final handler = adapter_interceptor.RequestInterceptorHandler();
      interceptor.onRequest(currentRequest, handler);
      
      if (handler.resolvedResponse != null) {
        // 拦截器直接返回了响应，抛出特殊异常
        throw _EarlyResponseException(handler.resolvedResponse!);
      } else if (handler.rejectedError != null) {
        // 拦截器拒绝了请求
        throw handler.rejectedError!;
      } else if (handler.modifiedRequest != null) {
        // 拦截器修改了请求
        currentRequest = handler.modifiedRequest!;
      }
      // 否则继续使用当前请求
    }
    
    return currentRequest;
  }
  
  /// 执行响应拦截器
  Future<AdapterResponse> _executeResponseInterceptors(AdapterResponse response) async {
    var currentResponse = response;
    
    for (final interceptor in _interceptors) {
      final handler = adapter_interceptor.ResponseInterceptorHandler();
       interceptor.onResponse(currentResponse, handler);

      if (handler.rejectedError != null) {
        // 拦截器拒绝了响应
        throw handler.rejectedError!;
      } else if (handler.modifiedResponse != null) {
        // 拦截器修改了响应
        currentResponse = handler.modifiedResponse!;
      }
      // 否则继续使用当前响应
    }
    
    return currentResponse;
  }
  
  /// 执行错误拦截器
  Future<AdapterException> _executeErrorInterceptors(AdapterException error) async {
    var currentError = error;
    
    for (final interceptor in _interceptors) {
      final handler = adapter_interceptor.ErrorInterceptorHandler();
      interceptor.onError(currentError, handler);
      
      if (handler.resolvedResponse != null) {
        // 拦截器解决了错误，返回响应
        throw _EarlyResponseException(handler.resolvedResponse!);
      } else if (handler.modifiedError != null) {
        // 拦截器修改了错误
        currentError = handler.modifiedError!;
      }
      // 否则继续使用当前错误
    }
    
    return currentError;
  }

  /// 转换 AdapterRequest 到 Dio Options
  Options _convertToOptions(AdapterRequest request) {
    return Options(
      method: _convertHttpMethod(request.method),
      headers: request.headers.isNotEmpty ? request.headers : null,
      contentType: request.contentType,
      responseType: _convertResponseType(request.responseType),
      sendTimeout: request.sendTimeout,
      receiveTimeout: request.receiveTimeout,
      extra: request.extra.isNotEmpty ? request.extra : null,
    );
  }
  
  /// 构建请求体
  dynamic _buildRequestBody(AdapterRequest request) {
    // 如果有原始 body，直接使用
    if (request.rawBody != null) {
      return request.rawBody;
    }
    
    // 如果没有 body 参数，返回 null
    if (request.bodyParams.isEmpty) {
      return null;
    }
    
    // 检测是否包含文件
    final hasFile = request.bodyParams.values.any(
      (v) => v is MultipartFile || v is FormData
    );
    
    // 如果包含文件或 contentType 是 multipart，使用 FormData
    if (hasFile || request.contentType?.contains('multipart') == true) {
      return FormData.fromMap(request.bodyParams);
    }
    
    // 否则直接返回参数 Map（Dio 会根据 contentType 自动处理）
    return request.bodyParams;
  }
  
  /// 转换 Dio Response 到 AdapterResponse
  AdapterResponse _convertFromResponse(Response dioResponse, AdapterRequest request) {
    return AdapterResponse(
      statusCode: dioResponse.statusCode ?? 0,
      statusMessage: dioResponse.statusMessage,
      data: dioResponse.data,
      headers: dioResponse.headers.map,
      request: request,
      isRedirect: dioResponse.isRedirect,
      redirectUrl: dioResponse.realUri.toString(),
      extra: dioResponse.extra,
    );
  }
  
  /// 转换 DioException 到 AdapterException
  AdapterException _convertException(DioException e) {
    final type = _convertExceptionType(e.type);
    
    return AdapterException(
      message: e.message ?? 'Unknown error',
      type: type,
      statusCode: e.response?.statusCode,
      response: e.response != null 
        ? _convertFromResponse(
            e.response!,
            AdapterRequest(
              baseUrl: e.requestOptions.baseUrl,
              path: e.requestOptions.path,
              method: _parseHttpMethod(e.requestOptions.method),
            ),
          )
        : null,
      originalError: e,
      stackTrace: e.stackTrace,
    );
  }
  
  /// 转换 CancelToken
  CancelToken? _convertCancelToken(adapter_cancel.CancelToken? token) {
    if (token == null) return null;
    
    // 如果已经有映射，返回已有的 Dio CancelToken
    if (_cancelTokenMap.containsKey(token)) {
      return _cancelTokenMap[token];
    }
    
    // 创建新的 Dio CancelToken
    final dioCancelToken = CancelToken();
    _cancelTokenMap[token] = dioCancelToken;
    
    // 监听适配器 CancelToken 的取消事件
    token.whenCancel((reason) {
      if (!dioCancelToken.isCancelled) {
        dioCancelToken.cancel(reason);
      }
      _cancelTokenMap.remove(token);
    });
    
    return dioCancelToken;
  }
  
  /// 转换 HTTP 方法
  String _convertHttpMethod(HttpMethod method) {
    return method.name.toUpperCase();
  }
  
  /// 解析 HTTP 方法字符串
  HttpMethod _parseHttpMethod(String method) {
    switch (method.toUpperCase()) {
      case 'GET':
        return HttpMethod.GET;
      case 'POST':
        return HttpMethod.POST;
      case 'PUT':
        return HttpMethod.PUT;
      case 'DELETE':
        return HttpMethod.DELETE;
      case 'PATCH':
        return HttpMethod.PATCH;
      case 'HEAD':
        return HttpMethod.HEAD;
      case 'OPTIONS':
        return HttpMethod.OPTIONS;
      default:
        return HttpMethod.GET;
    }
  }
  
  /// 转换响应类型
  ResponseType _convertResponseType(adapter_model.ResponseType type) {
    switch (type) {
      case adapter_model.ResponseType.json:
        return ResponseType.json;
      case adapter_model.ResponseType.stream:
        return ResponseType.stream;
      case adapter_model.ResponseType.plain:
        return ResponseType.plain;
      case adapter_model.ResponseType.bytes:
        return ResponseType.bytes;
    }
  }
  
  /// 转换异常类型
  AdapterExceptionType _convertExceptionType(DioExceptionType type) {
    switch (type) {
      case DioExceptionType.connectionTimeout:
        return AdapterExceptionType.connectTimeout;
      case DioExceptionType.sendTimeout:
        return AdapterExceptionType.sendTimeout;
      case DioExceptionType.receiveTimeout:
        return AdapterExceptionType.receiveTimeout;
      case DioExceptionType.badResponse:
        return AdapterExceptionType.response;
      case DioExceptionType.cancel:
        return AdapterExceptionType.cancel;
      case DioExceptionType.connectionError:
        return AdapterExceptionType.connectionError;
      default:
        return AdapterExceptionType.unknown;
    }
  }
  
  @override
  Future<AdapterResponse> download(
    AdapterRequest request,
    String savePath, {
    ProgressCallback? onProgress,
  }) async {
    try {
      final options = _convertToOptions(request);
      final requestBody = _buildRequestBody(request);
      final dioCancelToken = _convertCancelToken(request.cancelToken);
      
      // 下载与普通请求保持一致，统一使用规范化后的完整 URL。
      final response = await _dio.download(
        request.buildFullUrl(),
        savePath,
        queryParameters: request.queryParams,
        data: requestBody,
        options: options,
        cancelToken: dioCancelToken,
        onReceiveProgress: onProgress,
      );
      
      return _convertFromResponse(response, request);
    } on DioException catch (e) {
      throw _convertException(e);
    }
  }
  
  @override
  Future<AdapterResponse> upload(
    AdapterRequest request, {
    ProgressCallback? onProgress,
  }) async {
    try {
      final options = _convertToOptions(request);
      final requestBody = _buildRequestBody(request);
      final dioCancelToken = _convertCancelToken(request.cancelToken);
      
      final response = await _dio.request(
        request.buildFullUrl(),
        data: requestBody,
        queryParameters: request.queryParams,
        options: options,
        cancelToken: dioCancelToken,
        onSendProgress: onProgress,
      );
      
      return _convertFromResponse(response, request);
    } on DioException catch (e) {
      throw _convertException(e);
    }
  }
  
  @override
  void cancel(adapter_cancel.CancelToken token) {
    token.cancel();
  }
  
  @override
  void addInterceptor(AdapterInterceptor interceptor) {
    _interceptors.add(interceptor);
    // 不再使用 Dio 的拦截器桥接，因为我们在 request() 方法中直接执行拦截器
    // _dio.interceptors.add(_DioInterceptorBridge(interceptor));
  }
  
  @override
  void removeInterceptor(AdapterInterceptor interceptor) {
    _interceptors.remove(interceptor);
    // 不再使用 Dio 的拦截器桥接
    // _dio.interceptors.removeWhere((i) => 
    //   i is _DioInterceptorBridge && i.interceptor == interceptor
    // );
  }
}

/// Dio 拦截器桥接器（已弃用）
// Note: _DioInterceptorBridge has been removed in 0.6.1
// Interceptors are now executed directly in DioAdapter.request() before Dio processes them.
// This ensures interceptors have access to complete request information (bodyParams, pathParams, etc.)
// and prevents information loss during conversion to Dio's RequestOptions.
