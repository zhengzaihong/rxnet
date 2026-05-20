import '../models/adapter_request.dart';
import '../models/adapter_response.dart';
import '../exceptions/adapter_exception.dart';

/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2026-04-21 16:04
/// describe: 请求拦截器处理器
/// 用于在拦截器中控制请求流程
class RequestInterceptorHandler {
  bool _isCompleted = false;
  AdapterRequest? _modifiedRequest;
  AdapterException? _rejectedError;
  AdapterResponse? _resolvedResponse;

  /// 继续处理请求（可以修改请求）
  void next(AdapterRequest request) {
    if (_isCompleted) return;
    _isCompleted = true;
    _modifiedRequest = request;
  }

  /// 拒绝请求并抛出错误
  void reject(AdapterException error) {
    if (_isCompleted) return;
    _isCompleted = true;
    _rejectedError = error;
  }

  /// 直接返回响应，跳过后续处理
  void resolve(AdapterResponse response) {
    if (_isCompleted) return;
    _isCompleted = true;
    _resolvedResponse = response;
  }

  bool get isCompleted => _isCompleted;

  AdapterRequest? get modifiedRequest => _modifiedRequest;

  AdapterException? get rejectedError => _rejectedError;

  AdapterResponse? get resolvedResponse => _resolvedResponse;
}

/// 响应拦截器处理器
///
/// 用于在拦截器中控制响应流程
class ResponseInterceptorHandler {
  bool _isCompleted = false;
  AdapterResponse? _modifiedResponse;
  AdapterException? _rejectedError;

  /// 继续处理响应（可以修改响应）
  void next(AdapterResponse response) {
    if (_isCompleted) return;
    _isCompleted = true;
    _modifiedResponse = response;
  }

  /// 拒绝响应并抛出错误
  void reject(AdapterException error) {
    if (_isCompleted) return;
    _isCompleted = true;
    _rejectedError = error;
  }

  bool get isCompleted => _isCompleted;

  AdapterResponse? get modifiedResponse => _modifiedResponse;

  AdapterException? get rejectedError => _rejectedError;
}

/// 错误拦截器处理器
///
/// 用于在拦截器中控制错误处理流程
class ErrorInterceptorHandler {
  bool _isCompleted = false;
  AdapterException? _modifiedError;
  AdapterResponse? _resolvedResponse;

  /// 继续传递错误（可以修改错误）
  void next(AdapterException error) {
    if (_isCompleted) return;
    _isCompleted = true;
    _modifiedError = error;
  }

  /// 解决错误，返回响应
  void resolve(AdapterResponse response) {
    if (_isCompleted) return;
    _isCompleted = true;
    _resolvedResponse = response;
  }

  bool get isCompleted => _isCompleted;

  AdapterException? get modifiedError => _modifiedError;

  AdapterResponse? get resolvedResponse => _resolvedResponse;
}

/// 统一的拦截器接口
///
/// 支持请求、响应、错误拦截
abstract class AdapterInterceptor {
  /// 请求拦截
  ///
  /// 在请求发送前调用，可以修改请求或直接返回响应
  ///
  /// [request] 请求配置
  /// [handler] 拦截器处理器
  void onRequest(
    AdapterRequest request,
    RequestInterceptorHandler handler,
  ) {
    handler.next(request);
  }

  /// 响应拦截
  ///
  /// 在收到响应后调用，可以修改响应或抛出错误
  ///
  /// [response] 响应对象
  /// [handler] 拦截器处理器
  void onResponse(
    AdapterResponse response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(response);
  }

  /// 错误拦截
  ///
  /// 在发生错误时调用，可以修改错误或返回响应
  ///
  /// [error] 错误对象
  /// [handler] 拦截器处理器
  void onError(
    AdapterException error,
    ErrorInterceptorHandler handler,
  ) {
    handler.next(error);
  }
}
