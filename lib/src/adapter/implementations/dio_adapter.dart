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


/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2026-04-23 9:56
/// describe: 基于 Dio 库实现 NetworkAdapter 接口，保持与现有代码的兼容性

/// 内部异常：拦截器提前返回响应
class _EarlyResponseException implements Exception {
  final AdapterResponse response;
  _EarlyResponseException(this.response);
}

class DioAdapter implements NetworkAdapter {
  final Dio _dio;
  final List<AdapterInterceptor> _interceptors = [];
  final Map<adapter_cancel.CancelToken, CancelToken> _cancelTokenMap = {};
  
  /// 创建 DioAdapter
  /// 
  /// [dio] 可选的 Dio 实例，如果不提供则创建默认实例
  DioAdapter({Dio? dio}) : _dio = dio ?? Dio();
  
  /// 获取内部 Dio 实例
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
      
      // 处理 RESTful 参数
      String path = interceptedRequest.path;
      interceptedRequest.pathParams.forEach((key, value) {
        path = path.replaceAll('{$key}', value.toString());
      });
      
      // 直接使用 path，Dio 会自动处理：
      // - 如果 path 是完整 URL (http:// 或 https://)，Dio 直接使用
      // - 如果 path 是相对路径，Dio 会拼接 dio.options.baseUrl
      final response = await _dio.request(
        path,
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
      
      // 处理 RESTful 参数
      String path = request.path;
      request.pathParams.forEach((key, value) {
        path = path.replaceAll('{$key}', value.toString());
      });
      
      // 直接使用 path，Dio 会自动处理：
      // - 如果 path 是完整 URL (http:// 或 https://)，Dio 直接使用
      // - 如果 path 是相对路径，Dio 会拼接 dio.options.baseUrl
      final response = await _dio.download(
        path,
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
/// 
/// 注意：此类已不再使用。我们现在在 DioAdapter.request() 方法中
/// 直接执行 AdapterInterceptor，而不是通过 Dio 的拦截器系统。
/// 
/// 保留此类仅用于参考或未来可能的向后兼容需求。
/// 
/// 将 AdapterInterceptor 桥接到 Dio 的 Interceptor
@Deprecated('No longer used. Interceptors are now executed directly in DioAdapter.request()')
class _DioInterceptorBridge extends Interceptor {
  final AdapterInterceptor interceptor;
  
  _DioInterceptorBridge(this.interceptor);
  
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    try {
      // 转换 Dio RequestOptions 到 AdapterRequest
      final adapterRequest = _convertRequestOptions(options);
      
      // 创建适配器处理器
      final adapterHandler = adapter_interceptor.RequestInterceptorHandler();
      
      // 调用适配器拦截器
       interceptor.onRequest(adapterRequest, adapterHandler);
      
      // 处理结果
      if (adapterHandler.resolvedResponse != null) {
        // 直接返回响应
        handler.resolve(_convertToResponse(adapterHandler.resolvedResponse!));
      } else if (adapterHandler.rejectedError != null) {
        // 拒绝请求
        handler.reject(DioException(
          requestOptions: options,
          message: adapterHandler.rejectedError!.message,
        ));
      } else if (adapterHandler.modifiedRequest != null) {
        // 修改请求并继续
        _updateRequestOptions(options, adapterHandler.modifiedRequest!);
        handler.next(options);
      } else {
        // 继续原请求
        handler.next(options);
      }
    } catch (e) {
      handler.reject(DioException(
        requestOptions: options,
        message: e.toString(),
      ));
    }
  }
  
  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) async {
    try {
      // 转换 Dio Response 到 AdapterResponse
      final adapterResponse = _convertResponse(response);
      
      // 创建适配器处理器
      final adapterHandler = adapter_interceptor.ResponseInterceptorHandler();
      
      // 调用适配器拦截器
       interceptor.onResponse(adapterResponse, adapterHandler);
      
      // 处理结果
      if (adapterHandler.rejectedError != null) {
        // 拒绝响应
        handler.reject(DioException(
          requestOptions: response.requestOptions,
          message: adapterHandler.rejectedError!.message,
        ));
      } else if (adapterHandler.modifiedResponse != null) {
        // 修改响应并继续
        handler.next(_convertToResponse(adapterHandler.modifiedResponse!));
      } else {
        // 继续原响应
        handler.next(response);
      }
    } catch (e) {
      handler.reject(DioException(
        requestOptions: response.requestOptions,
        message: e.toString(),
      ));
    }
  }
  
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    try {
      // 转换 DioException 到 AdapterException
      final adapterException = _convertDioException(err);
      
      // 创建适配器处理器
      final adapterHandler = adapter_interceptor.ErrorInterceptorHandler();
      
      // 调用适配器拦截器
       interceptor.onError(adapterException, adapterHandler);
      
      // 处理结果
      if (adapterHandler.resolvedResponse != null) {
        // 解决错误，返回响应
        handler.resolve(_convertToResponse(adapterHandler.resolvedResponse!));
      } else if (adapterHandler.modifiedError != null) {
        // 修改错误并继续
        handler.next(DioException(
          requestOptions: err.requestOptions,
          message: adapterHandler.modifiedError!.message,
          response: err.response,
        ));
      } else {
        // 继续原错误
        handler.next(err);
      }
    } catch (e) {
      handler.next(err);
    }
  }
  
  // 辅助方法
  AdapterRequest _convertRequestOptions(RequestOptions options) {
    return AdapterRequest(
      baseUrl: options.baseUrl,
      path: options.path,
      method: _parseHttpMethod(options.method),
      queryParams: options.queryParameters,
      headers: options.headers,
      contentType: options.contentType?.toString(),
      extra: options.extra,
    );
  }
  
  AdapterResponse _convertResponse(Response response) {
    return AdapterResponse(
      statusCode: response.statusCode ?? 0,
      statusMessage: response.statusMessage,
      data: response.data,
      headers: response.headers.map,
      request: _convertRequestOptions(response.requestOptions),
      isRedirect: response.isRedirect,
      redirectUrl: response.realUri.toString(),
      extra: response.extra,
    );
  }
  
  AdapterException _convertDioException(DioException e) {
    return AdapterException(
      message: e.message ?? 'Unknown error',
      type: _convertExceptionType(e.type),
      statusCode: e.response?.statusCode,
      originalError: e,
      stackTrace: e.stackTrace,
    );
  }
  
  Response _convertToResponse(AdapterResponse adapterResponse) {
    return Response(
      requestOptions: RequestOptions(path: adapterResponse.request.path),
      statusCode: adapterResponse.statusCode,
      statusMessage: adapterResponse.statusMessage,
      data: adapterResponse.data,
      headers: Headers.fromMap(adapterResponse.headers),
      extra: adapterResponse.extra,
    );
  }
  
  void _updateRequestOptions(RequestOptions options, AdapterRequest request) {
    if (request.headers.isNotEmpty) {
      options.headers.addAll(request.headers);
    }
    if (request.queryParams.isNotEmpty) {
      options.queryParameters.addAll(request.queryParams);
    }
  }
  
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
}
