import 'package:flutter/foundation.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

/// ============================================================================
/// 自定义拦截器示例
/// 
/// RxNet Plus 0.6.0 使用统一的 AdapterInterceptor 接口
/// 不再依赖 Dio 的 Interceptor
/// ============================================================================
///
/// 自动添加认证令牌到请求头
class AuthInterceptor extends AdapterInterceptor {
  String? _token;
  
  /// 设置认证令牌
  void setToken(String token) {
    _token = token;
  }
  
  /// 清除认证令牌
  void clearToken() {
    _token = null;
  }

  @override
  void onRequest(
    AdapterRequest request,
    RequestInterceptorHandler handler,
  ) {
    if (_token != null) {
      // 添加 Authorization 头
      final headers = Map<String, String>.from(request.headers);
      headers['Authorization'] = 'Bearer $_token';
      
      // 创建新的请求对象
      final newRequest = request.copyWith(headers: headers);
      
      debugPrint('🔐 Added Authorization header to ${request.buildFullUrl()}');
      
      // 使用修改后的请求继续
      handler.next(newRequest);
    } else {
      // 没有令牌，直接继续
      handler.next(request);
    }
  }

  @override
  void onResponse(
    AdapterResponse response,
    ResponseInterceptorHandler handler,
  ) {
    // 检查是否有新的令牌
    final newToken = response.headers['x-new-token']?.first;
    if (newToken != null) {
      debugPrint('🔐 Received new token, updating...');
      _token = newToken;
    }
    
    handler.next(response);
  }

  @override
  void onError(
    AdapterException error,
    ErrorInterceptorHandler handler,
  ) {
    // 如果是 401 错误，清除令牌
    if (error.statusCode == 401) {
      debugPrint('🔐 Unauthorized, clearing token...');
      clearToken();
    }
    
    handler.next(error);
  }
}

/// 示例 3: 重试拦截器
/// 
/// 自动重试失败的请求
class RetryInterceptor extends AdapterInterceptor {
  final int maxRetries;
  final Duration retryDelay;
  final Map<AdapterRequest, int> _retryCount = {};

  RetryInterceptor({
    this.maxRetries = 3,
    this.retryDelay = const Duration(seconds: 1),
  });

  @override
  void onRequest(
    AdapterRequest request,
    RequestInterceptorHandler handler,
  ) {
    // 重置重试计数
    _retryCount[request] = 0;
    handler.next(request);
  }

  @override
  void onResponse(
    AdapterResponse response,
    ResponseInterceptorHandler handler,
  ) {
    // 清除重试计数
    _retryCount.remove(response.request);
    handler.next(response);
  }

  @override
  void onError(
    AdapterException error,
    ErrorInterceptorHandler handler,
  ) async {
    // 从响应中获取请求对象
    final request = error.response?.request;
    if (request == null) {
      handler.next(error);
      return;
    }
    
    // 获取当前重试次数
    final retries = _retryCount[request] ?? 0;
    
    // 判断是否应该重试
    final shouldRetry = retries < maxRetries && 
                       _isRetryableError(error);
    
    if (shouldRetry) {
      _retryCount[request] = retries + 1;
      
      debugPrint('🔄 Retrying request (${retries + 1}/$maxRetries): ${request.buildFullUrl()}');
      
      // 等待一段时间后重试
      await Future.delayed(retryDelay);
      
      // 注意：这里需要重新发起请求
      // 实际实现中，你可能需要通过 handler.resolve() 来返回新的响应
      // 或者使用 handler.reject() 来继续错误
      
      // 这里我们只是演示概念，实际重试需要适配器支持
      debugPrint('⚠️ Retry mechanism needs adapter support');
      handler.next(error);
    } else {
      // 清除重试计数
      _retryCount.remove(request);
      
      if (retries >= maxRetries) {
        debugPrint('❌ Max retries reached for ${request.buildFullUrl()}');
      }
      
      handler.next(error);
    }
  }
  
  /// 判断错误是否可重试
  bool _isRetryableError(AdapterException error) {
    switch (error.type) {
      case AdapterExceptionType.connectTimeout:
      case AdapterExceptionType.sendTimeout:
      case AdapterExceptionType.receiveTimeout:
      case AdapterExceptionType.connectionError:
        return true;
      case AdapterExceptionType.response:
        // 5xx 错误可以重试
        return error.statusCode != null && error.statusCode! >= 500;
      case AdapterExceptionType.cancel:
      case AdapterExceptionType.unknown:
        return false;
    }
  }
}

/// 示例 4: 缓存拦截器
/// 
/// 简单的内存缓存实现
class CacheInterceptor extends AdapterInterceptor {
  final Duration cacheDuration;
  final Map<String, _CacheEntry> _cache = {};

  CacheInterceptor({
    this.cacheDuration = const Duration(minutes: 5),
  });

  @override
  void onRequest(
    AdapterRequest request,
    RequestInterceptorHandler handler,
  ) {
    // 只缓存 GET 请求
    if (request.method != HttpMethod.GET) {
      handler.next(request);
      return;
    }
    
    final cacheKey = _getCacheKey(request);
    final cachedEntry = _cache[cacheKey];
    
    if (cachedEntry != null && !cachedEntry.isExpired) {
      debugPrint('💾 Cache hit for ${request.buildFullUrl()}');
      
      // 从缓存返回响应
      // 注意：这需要使用 handler.resolve() 来直接返回响应
      // 这里只是演示概念
      debugPrint('⚠️ Cache resolution needs handler.resolve() support');
      handler.next(request);
    } else {
      if (cachedEntry != null) {
        debugPrint('💾 Cache expired for ${request.buildFullUrl()}');
        _cache.remove(cacheKey);
      }
      handler.next(request);
    }
  }

  @override
  void onResponse(
    AdapterResponse response,
    ResponseInterceptorHandler handler,
  ) {
    // 只缓存 GET 请求的成功响应
    if (response.request.method == HttpMethod.GET && 
        response.statusCode >= 200 && 
        response.statusCode < 300) {
      final cacheKey = _getCacheKey(response.request);
      _cache[cacheKey] = _CacheEntry(
        response: response,
        timestamp: DateTime.now(),
      );
      
      debugPrint('💾 Cached response for ${response.request.buildFullUrl()}');
    }
    
    handler.next(response);
  }

  @override
  void onError(
    AdapterException error,
    ErrorInterceptorHandler handler,
  ) {
    handler.next(error);
  }
  
  String _getCacheKey(AdapterRequest request) {
    return '${request.method.value}:${request.buildFullUrl()}';
  }
  
  /// 清除所有缓存
  void clearCache() {
    _cache.clear();
    debugPrint('💾 Cache cleared');
  }
  
  /// 清除过期缓存
  void clearExpiredCache() {
    _cache.removeWhere((key, entry) => entry.isExpired);
    debugPrint('💾 Expired cache cleared');
  }
}

class _CacheEntry {
  final AdapterResponse response;
  final DateTime timestamp;
  
  _CacheEntry({
    required this.response,
    required this.timestamp,
  });
  
  bool get isExpired {
    return DateTime.now().difference(timestamp) > const Duration(minutes: 5);
  }
}

/// 示例 5: 性能监控拦截器
/// 
/// 监控请求性能
class PerformanceInterceptor extends AdapterInterceptor {
  final Map<AdapterRequest, DateTime> _requestStartTimes = {};

  @override
  void onRequest(
    AdapterRequest request,
    RequestInterceptorHandler handler,
  ) {
    _requestStartTimes[request] = DateTime.now();
    handler.next(request);
  }

  @override
  void onResponse(
    AdapterResponse response,
    ResponseInterceptorHandler handler,
  ) {
    final startTime = _requestStartTimes[response.request];
    if (startTime != null) {
      final duration = DateTime.now().difference(startTime);
      _requestStartTimes.remove(response.request);
      
      debugPrint('⏱️ Request took ${duration.inMilliseconds}ms: ${response.request.buildFullUrl()}');
      
      // 如果请求太慢，发出警告
      if (duration.inSeconds > 3) {
        debugPrint('⚠️ Slow request detected (${duration.inSeconds}s)');
      }
    }
    
    handler.next(response);
  }

  @override
  void onError(
    AdapterException error,
    ErrorInterceptorHandler handler,
  ) {
    // 从响应中获取请求对象
    final request = error.response?.request;
    if (request != null) {
      final startTime = _requestStartTimes[request];
      if (startTime != null) {
        final duration = DateTime.now().difference(startTime);
        _requestStartTimes.remove(request);
        
        debugPrint('⏱️ Request failed after ${duration.inMilliseconds}ms: ${request.buildFullUrl()}');
      }
    }
    
    handler.next(error);
  }
}

/// 示例 6: 请求修改拦截器
/// 
/// 修改请求参数
class RequestModifierInterceptor extends AdapterInterceptor {
  final String apiVersion;
  final String platform;
  
  RequestModifierInterceptor({
    this.apiVersion = 'v1',
    this.platform = 'flutter',
  });

  @override
  void onRequest(
    AdapterRequest request,
    RequestInterceptorHandler handler,
  ) {
    // 添加公共查询参数
    final queryParams = Map<String, dynamic>.from(request.queryParams);
    queryParams['api_version'] = apiVersion;
    queryParams['platform'] = platform;
    queryParams['timestamp'] = DateTime.now().millisecondsSinceEpoch;
    
    // 添加公共请求头
    final headers = Map<String, String>.from(request.headers);
    headers['X-API-Version'] = apiVersion;
    headers['X-Platform'] = platform;
    headers['X-Request-ID'] = _generateRequestId();
    
    // 创建修改后的请求
    final newRequest = request.copyWith(
      queryParams: queryParams,
      headers: headers,
    );
    
    debugPrint('🔧 Modified request: ${newRequest.buildFullUrl()}');
    
    handler.next(newRequest);
  }

  @override
  void onResponse(
    AdapterResponse response,
    ResponseInterceptorHandler handler,
  ) {
    handler.next(response);
  }

  @override
  void onError(
    AdapterException error,
    ErrorInterceptorHandler handler,
  ) {
    handler.next(error);
  }
  
  String _generateRequestId() {
    return '${DateTime.now().millisecondsSinceEpoch}-${_randomString(8)}';
  }
  
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(length, (index) => chars[DateTime.now().microsecond % chars.length]).join();
  }
}

/// ============================================================================
/// 使用示例
/// ============================================================================

class InterceptorUsageExample {
  static Future<void> basicUsage() async {
    final authInterceptor = AuthInterceptor();
    
    // 初始化 RxNet 并添加拦截器
    await RxNet.init(
     config: const RxNetConfig( baseUrl: "https://api.example.com")
    );
    
    // 添加拦截器到适配器
    final adapter = RxNet.getDefaultAdapter();
    adapter?.addInterceptor(authInterceptor);
    
    // 设置认证令牌
    authInterceptor.setToken('your-auth-token-here');
    
    // 发起请求
    final response = await RxNet.get()
        .setPath("/users")
        .request();
    
    debugPrint('Response: ${response.value}');
  }
  
  static Future<void> multipleInterceptors() async {
    // 创建多个拦截器
    final interceptors = [
      AuthInterceptor()..setToken('token-123'),
      PerformanceInterceptor(),
      RequestModifierInterceptor(apiVersion: 'v2'),
      RetryInterceptor(maxRetries: 3),
    ];
    
    // 初始化并添加所有拦截器
    await RxNet.init(
        config: const RxNetConfig( baseUrl: "https://api.example.com")
    );
    
    final adapter = RxNet.getDefaultAdapter();
    for (final interceptor in interceptors) {
      adapter?.addInterceptor(interceptor);
    }
    
    // 发起请求
    final response = await RxNet.get()
        .setPath("/data")
        .request();
    
    debugPrint('Response: ${response.value}');
  }
  

  static Future<void> perInstanceInterceptors() async {
    // 创建多个实例，每个实例有不同的拦截器
    
    // API 1: 主 API（带认证和日志）
    final mainApi = RxNet.create();
    await mainApi.initNet(config: const RxNetConfig(baseUrl: "https://api.main.com"));
    mainApi.getAdapter()?.addInterceptor(AuthInterceptor()..setToken('main-token'));
    
    // API 2: 分析 API（只有性能监控）
    final analyticsApi = RxNet.create();
    await analyticsApi.initNet(config: const RxNetConfig(baseUrl: "https://analytics.example.com"));
    analyticsApi.getAdapter()?.addInterceptor(PerformanceInterceptor());
    
    // 使用不同的实例
    await mainApi.getRequest().setPath("/users").request();
    await analyticsApi.getRequest().setPath("/events").request();
  }
}
