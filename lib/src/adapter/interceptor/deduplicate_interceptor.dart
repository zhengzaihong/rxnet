import 'dart:async';
import '../../../rxnet_lib.dart';


/// author:郑再红
/// email:1096877329@qq.com
/// date:2026-08-07 9:42
/// describe:请求去重拦截器
/// 对相同路径+参数的并发请求进行去重，避免重复发起相同请求。
/// 适用于用户快速点击按钮等场景。
class DeduplicateInterceptor extends AdapterInterceptor {
  /// 去重时间窗口，默认 3 秒
  final Duration duration;

  /// 自定义去重 key 生成器
  final String Function(AdapterRequest request)? keyBuilder;

  final Map<String, Completer<void>> _pendingRequests = {};
  final Map<String, Timer> _timers = {};

  DeduplicateInterceptor({
    this.duration = const Duration(seconds: 3),
    this.keyBuilder,
  });

  @override
  void onRequest(AdapterRequest request, RequestInterceptorHandler handler) {
    final key = _generateKey(request);

    if (_pendingRequests.containsKey(key) && _timers.containsKey(key)) {
      handler.reject(AdapterException(
        message: 'Duplicate request blocked: $key',
        type: AdapterExceptionType.cancel,
        originalError: 'DeduplicateInterceptor',
      ));
      return;
    }

    _pendingRequests[key] = Completer<void>();
    _timers[key]?.cancel();
    _timers[key] = Timer(duration, () {
      _cleanup(key);
    });

    handler.next(request);
  }

  @override
  void onResponse(AdapterResponse response, ResponseInterceptorHandler handler) {
    handler.next(response);
  }

  @override
  void onError(AdapterException error, ErrorInterceptorHandler handler) {
    handler.next(error);
  }

  String _generateKey(AdapterRequest request) {
    if (keyBuilder != null) {
      return keyBuilder!(request);
    }
    final params = request.queryParams.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&');
    return '${request.method.name}|${request.baseUrl}|${request.path}|$params';
  }

  void _cleanup(String key) {
    _pendingRequests.remove(key);
    _timers[key]?.cancel();
    _timers.remove(key);
  }

  void clearAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    _pendingRequests.clear();
  }
}
