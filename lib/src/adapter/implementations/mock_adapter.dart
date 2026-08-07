import 'dart:async';
import 'package:rxnet_plus/src/adapter/models/adapter_base_options.dart';
import '../network_adapter.dart';
import '../models/adapter_request.dart';
import '../models/adapter_response.dart';
import '../interceptor/adapter_interceptor.dart';
import '../exceptions/adapter_exception.dart';
import '../cancel_token.dart';

/// Mock 适配器实现
/// 
/// 用于测试的模拟适配器，可以配置模拟响应、错误和延迟
class MockAdapter implements NetworkAdapter {
  final Map<String, _MockConfig> _mockConfigs = {};
  final List<AdapterRequest> _requestHistory = [];
  final List<AdapterInterceptor> _interceptors = [];
  final Map<CancelToken, List<Completer>> _pendingRequests = {};
  
  @override
  String get name => 'MockAdapter';
  
  @override
  String get version => '1.0.0';
  
  /// 获取请求历史记录
  List<AdapterRequest> get requestHistory => List.unmodifiable(_requestHistory);
  
  /// 设置模拟响应
  /// 
  /// [path] 请求路径
  /// [response] 模拟的响应
  void setMockResponse(String path, AdapterResponse response) {
    _mockConfigs[path] = _MockConfig(response: response);
  }
  
  /// 设置模拟错误
  /// 
  /// [path] 请求路径
  /// [error] 模拟的错误
  void setMockError(String path, AdapterException error) {
    _mockConfigs[path] = _MockConfig(error: error);
  }
  
  /// 设置模拟延迟
  /// 
  /// [path] 请求路径
  /// [delay] 延迟时间
  void setMockDelay(String path, Duration delay) {
    final existing = _mockConfigs[path];
    if (existing != null) {
      _mockConfigs[path] = _MockConfig(
        response: existing.response,
        error: existing.error,
        delay: delay,
      );
    } else {
      _mockConfigs[path] = _MockConfig(delay: delay);
    }
  }
  
  /// 清除请求历史记录
  void clearHistory() {
    _requestHistory.clear();
  }
  
  /// 清除所有模拟配置
  void clearMocks() {
    _mockConfigs.clear();
  }
  
  @override
  Future<AdapterResponse> request(AdapterRequest request) async {
    // 记录请求历史
    _requestHistory.add(request);
    
    // 创建 Completer 用于取消
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
    
    // 获取模拟配置
    final config = _mockConfigs[modifiedRequest.path];
    
    // 应用延迟
    if (config?.delay != null) {
      try {
        await Future.any([
          Future.delayed(config!.delay!),
          completer.future,
        ]);
        
        // 检查是否被取消
        if (completer.isCompleted) {
          throw await completer.future;
        }
      } catch (e) {
        _unregisterCancelToken(request.cancelToken, completer);
        rethrow;
      }
    }
    
    // 如果配置了错误，抛出错误
    if (config?.error != null) {
      var error = config!.error!;
      
      // 执行错误拦截器
      for (final interceptor in _interceptors) {
        final handler = ErrorInterceptorHandler();
         interceptor.onError(error, handler);
        
        if (handler.resolvedResponse != null) {
          _unregisterCancelToken(request.cancelToken, completer);
          return handler.resolvedResponse!;
        }
        if (handler.modifiedError != null) {
          error = handler.modifiedError!;
        }
      }
      
      _unregisterCancelToken(request.cancelToken, completer);
      throw error;
    }
    
    // 返回模拟响应
    var response = config?.response ?? _createDefaultResponse(modifiedRequest);
    
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
  }
  
  @override
  Future<AdapterResponse> download(
    AdapterRequest request,
    String savePath, {
    ProgressCallback? onProgress,
  }) async {
    // 记录请求历史
    _requestHistory.add(request);
    
    // 创建 Completer 用于取消
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
      // 获取模拟配置
      final config = _mockConfigs[request.path];
      
      // 应用延迟（支持取消）
      if (config?.delay != null) {
        try {
          await Future.any([
            Future.delayed(config!.delay!),
            completer.future,
          ]);
          
          // 检查是否被取消
          if (completer.isCompleted) {
            throw await completer.future;
          }
        } catch (e) {
          _unregisterCancelToken(request.cancelToken, completer);
          rethrow;
        }
      }
      
      // 模拟进度回调
      if (onProgress != null) {
        final total = 1024;
        for (var i = 0; i <= 10; i++) {
          await Future.delayed(const Duration(milliseconds: 10));
          onProgress((i * total / 10).toInt(), total);
        }
      }
      
      // 如果配置了错误，抛出错误
      if (config?.error != null) {
        _unregisterCancelToken(request.cancelToken, completer);
        throw config!.error!;
      }
      
      // 返回模拟响应
      _unregisterCancelToken(request.cancelToken, completer);
      return config?.response ?? _createDefaultResponse(request, data: savePath);
    } catch (e) {
      _unregisterCancelToken(request.cancelToken, completer);
      rethrow;
    }
  }
  
  @override
  Future<AdapterResponse> upload(
    AdapterRequest request, {
    ProgressCallback? onProgress,
  }) async {
    // 记录请求历史
    _requestHistory.add(request);
    
    // 创建 Completer 用于取消
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
      // 获取模拟配置
      final config = _mockConfigs[request.path];
      
      // 应用延迟（支持取消）
      if (config?.delay != null) {
        try {
          await Future.any([
            Future.delayed(config!.delay!),
            completer.future,
          ]);
          
          // 检查是否被取消
          if (completer.isCompleted) {
            throw await completer.future;
          }
        } catch (e) {
          _unregisterCancelToken(request.cancelToken, completer);
          rethrow;
        }
      }
      
      // 模拟进度回调
      if (onProgress != null) {
        final total = 1024;
        for (var i = 0; i <= 10; i++) {
          await Future.delayed(const Duration(milliseconds: 10));
          onProgress((i * total / 10).toInt(), total);
        }
      }
      
      // 如果配置了错误，抛出错误
      if (config?.error != null) {
        _unregisterCancelToken(request.cancelToken, completer);
        throw config!.error!;
      }
      
      // 返回模拟响应
      _unregisterCancelToken(request.cancelToken, completer);
      return config?.response ?? _createDefaultResponse(request);
    } catch (e) {
      _unregisterCancelToken(request.cancelToken, completer);
      rethrow;
    }
  }
  
  @override
  void cancel(CancelToken token) {
    // 取消所有使用此 token 的请求
    token.cancel();
  }
  
  /// 注册取消令牌
  void _registerCancelToken(CancelToken token, Completer completer) {
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
  void _unregisterCancelToken(CancelToken? token, Completer completer) {
    if (token != null && _pendingRequests.containsKey(token)) {
      _pendingRequests[token]!.remove(completer);
      if (_pendingRequests[token]!.isEmpty) {
        _pendingRequests.remove(token);
      }
    }
  }
  
  @override
  void addInterceptor(AdapterInterceptor interceptor) {
    _interceptors.add(interceptor);
  }
  
  @override
  void removeInterceptor(AdapterInterceptor interceptor) {
    _interceptors.remove(interceptor);
  }
  
  /// 创建默认响应
  AdapterResponse _createDefaultResponse(
    AdapterRequest request, {
    dynamic data,
  }) {
    return AdapterResponse(
      statusCode: 200,
      statusMessage: 'OK',
      data: data ?? {'mock': true, 'path': request.path},
      headers: {'content-type': ['application/json']},
      request: request,
    );
  }

  @override
  void setBaseUrl(String url) {
  }


  @override
  void applyBaseOptions(AdapterBaseOptions options) {
  }
}

/// 模拟配置
class _MockConfig {
  final AdapterResponse? response;
  final AdapterException? error;
  final Duration? delay;
  
  _MockConfig({
    this.response,
    this.error,
    this.delay,
  });
}
