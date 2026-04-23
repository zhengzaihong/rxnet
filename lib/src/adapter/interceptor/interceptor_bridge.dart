import 'package:dio/dio.dart' as dio;
import '../../../net/type/http_method.dart';
import '../../../net/type/response_type.dart';
import 'adapter_interceptor.dart';
import '../models/adapter_request.dart';
import '../models/adapter_response.dart';
import '../exceptions/adapter_exception.dart';

/// 拦截器桥接工具
/// 
/// 用于将 Dio 拦截器桥接到 AdapterInterceptor 接口
/// 使现有的 Dio 拦截器可以与适配器架构一起使用
class InterceptorBridge {
  /// 将 Dio Interceptor 转换为 AdapterInterceptor
  /// 
  /// 这允许现有的 Dio 拦截器在适配器架构中使用
  /// 
  /// 注意：由于 Dio 和 Adapter 的模型不同，某些功能可能无法完全桥接
  static AdapterInterceptor fromDioInterceptor(dio.Interceptor dioInterceptor) {
    return _DioInterceptorBridge(dioInterceptor);
  }
}

/// Dio 拦截器桥接实现
class _DioInterceptorBridge implements AdapterInterceptor {
  final dio.Interceptor _dioInterceptor;

  _DioInterceptorBridge(this._dioInterceptor);

  @override
  Future<void> onRequest(
    AdapterRequest request,
    RequestInterceptorHandler handler,
  ) async {
    // 将 AdapterRequest 转换为 Dio RequestOptions
    final options = _convertToRequestOptions(request);
    
    // 创建 Dio 的 RequestInterceptorHandler
    final dioHandler = dio.RequestInterceptorHandler();
    
    // 调用 Dio 拦截器（不使用 await，因为返回 void）
    _dioInterceptor.onRequest(options, dioHandler);
    
    // 继续请求
    handler.next(request);
  }

  @override
  Future<void> onResponse(
    AdapterResponse response,
    ResponseInterceptorHandler handler,
  ) async {
    // 将 AdapterResponse 转换为 Dio Response
    final dioResponse = _convertToDioResponse(response);
    
    // 创建 Dio 的 ResponseInterceptorHandler
    final dioHandler = dio.ResponseInterceptorHandler();
    
    // 调用 Dio 拦截器（不使用 await，因为返回 void）
    _dioInterceptor.onResponse(dioResponse, dioHandler);
    
    // 继续响应
    handler.next(response);
  }

  @override
  Future<void> onError(
    AdapterException error,
    ErrorInterceptorHandler handler,
  ) async {
    // 将 AdapterException 转换为 DioException
    final dioError = _convertToDioException(error);
    
    // 创建 Dio 的 ErrorInterceptorHandler
    final dioHandler = dio.ErrorInterceptorHandler();
    
    // 调用 Dio 拦截器（不使用 await，因为返回 void）
    // 注意：Dio 的 ErrorInterceptorHandler.next() 会抛出异常
    // 我们需要捕获这个异常，因为这是 Dio 的正常行为
    // 在 Dio 中，错误拦截器通过抛出异常来传播错误
    // 但在适配器架构中，我们使用 handler.next() 来传播错误
    try {
      _dioInterceptor.onError(dioError, dioHandler);
      // 如果没有抛出异常，说明拦截器处理了错误，我们继续
      handler.next(error);
    } catch (e) {
      // Dio 拦截器抛出了异常（这是正常的），我们继续处理适配器的错误流程
      handler.next(error);
    }
  }

  /// 将 AdapterRequest 转换为 Dio RequestOptions
  dio.RequestOptions _convertToRequestOptions(AdapterRequest request) {
    return dio.RequestOptions(
      baseUrl: request.baseUrl,
      path: request.path,
      method: _convertHttpMethod(request.method),
      queryParameters: request.queryParams,
      data: request.rawBody ?? request.bodyParams,
      headers: request.headers,
      contentType: request.contentType,
      responseType: _convertResponseType(request.responseType),
      connectTimeout: request.connectTimeout,
      receiveTimeout: request.receiveTimeout,
      sendTimeout: request.sendTimeout,
      extra: request.extra,
    );
  }

  /// 将 AdapterResponse 转换为 Dio Response
  dio.Response _convertToDioResponse(AdapterResponse response) {
    return dio.Response(
      requestOptions: _convertToRequestOptions(response.request),
      data: response.data,
      statusCode: response.statusCode,
      statusMessage: response.statusMessage,
      headers: dio.Headers.fromMap(response.headers),
      isRedirect: response.isRedirect,
      redirects: response.redirectUrl != null
          ? [dio.RedirectRecord(response.statusCode, _convertHttpMethod(response.request.method), Uri.parse(response.redirectUrl!))]
          : [],
      extra: response.extra,
    );
  }

  /// 将 AdapterException 转换为 DioException
  dio.DioException _convertToDioException(AdapterException error) {
    dio.DioExceptionType type;
    switch (error.type) {
      case AdapterExceptionType.connectTimeout:
        type = dio.DioExceptionType.connectionTimeout;
        break;
      case AdapterExceptionType.sendTimeout:
        type = dio.DioExceptionType.sendTimeout;
        break;
      case AdapterExceptionType.receiveTimeout:
        type = dio.DioExceptionType.receiveTimeout;
        break;
      case AdapterExceptionType.response:
        type = dio.DioExceptionType.badResponse;
        break;
      case AdapterExceptionType.cancel:
        type = dio.DioExceptionType.cancel;
        break;
      case AdapterExceptionType.connectionError:
        type = dio.DioExceptionType.connectionError;
        break;
      case AdapterExceptionType.unknown:
      default:
        type = dio.DioExceptionType.unknown;
        break;
    }

    return dio.DioException(
      requestOptions: error.response != null
          ? _convertToRequestOptions(error.response!.request)
          : dio.RequestOptions(path: ''),
      response: error.response != null ? _convertToDioResponse(error.response!) : null,
      type: type,
      error: error.originalError,
      message: error.message,
      stackTrace: error.stackTrace ?? StackTrace.current,
    );
  }

  /// 转换 HTTP 方法
  String _convertHttpMethod(HttpMethod method) {
    switch (method) {
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

  /// 转换响应类型
  dio.ResponseType _convertResponseType(ResponseType type) {
    switch (type) {
      case ResponseType.json:
        return dio.ResponseType.json;
      case ResponseType.stream:
        return dio.ResponseType.stream;
      case ResponseType.plain:
        return dio.ResponseType.plain;
      case ResponseType.bytes:
        return dio.ResponseType.bytes;
    }
  }
}
