import '../exceptions/adapter_exception.dart';
import '../interceptor/adapter_interceptor.dart';
import '../models/adapter_request.dart';


/// author:郑再红
/// email:1096877329@qq.com
/// date:2026-08-07 9:44
/// describe:请求限流/节流拦截器
/// 对请求进行频率限制，在指定时间窗口内相同 key 的请求只放行第一次。
class ThrottleInterceptor extends AdapterInterceptor {
  /// 节流时间窗口
  final Duration duration;

  /// 自定义 key 生成器，默认使用请求路径
  final String Function(AdapterRequest request)? keyBuilder;

  final Map<String, DateTime> _lastRequestTimes = {};

  ThrottleInterceptor({
    this.duration = const Duration(seconds: 1),
    this.keyBuilder,
  });

  @override
  void onRequest(AdapterRequest request, RequestInterceptorHandler handler) {
    final key = _getKey(request);
    final now = DateTime.now();
    final lastTime = _lastRequestTimes[key];

    if (lastTime != null && now.difference(lastTime) < duration) {
      handler.reject(AdapterException(
        message: 'Request throttled: $key',
        type: AdapterExceptionType.cancel,
        originalError: 'ThrottleInterceptor',
      ));
      return;
    }

    _lastRequestTimes[key] = now;
    handler.next(request);
  }

  String _getKey(AdapterRequest request) {
    if (keyBuilder != null) {
      return keyBuilder!(request);
    }
    return '${request.method.name}|${request.baseUrl}|${request.path}';
  }

  void clearAll() {
    _lastRequestTimes.clear();
  }
}
