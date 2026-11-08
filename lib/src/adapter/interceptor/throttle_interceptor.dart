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

  /// 最大记录数，超过后按时间窗口/最旧记录自动回收
  final int maxEntries;

  final Map<String, DateTime> _lastRequestTimes = {};

  ThrottleInterceptor({
    this.duration = const Duration(seconds: 1),
    this.keyBuilder,
    this.maxEntries = 1000,
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

    if (_lastRequestTimes.length >= maxEntries) {
      _prune(now);
    }

    _lastRequestTimes[key] = now;
    handler.next(request);
  }

  /// 清理过期记录；仍然超限时移除最旧的一条
  void _prune(DateTime now) {
    final expiredBefore = now.subtract(duration);
    _lastRequestTimes.removeWhere(
      (_, lastTime) => lastTime.isBefore(expiredBefore),
    );

    if (_lastRequestTimes.length < maxEntries) {
      return;
    }

    String? oldestKey;
    DateTime? oldestTime;
    _lastRequestTimes.forEach((key, time) {
      if (oldestTime == null || time.isBefore(oldestTime!)) {
        oldestTime = time;
        oldestKey = key;
      }
    });
    if (oldestKey != null) {
      _lastRequestTimes.remove(oldestKey);
    }
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
