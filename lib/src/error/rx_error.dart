
///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2025-08-12
/// create_time: 16:17
/// describe: 定义已知异常的基类
/// The base class for all RxNet exceptions.
///
abstract class RxError implements Exception {
  final String message;
  final dynamic cause;

  RxError(this.message, [this.cause]);

  @override
  String toString() => '$runtimeType: $message' + (cause == null ? '' : '\nCause: $cause');
}

/// 网络异常
/// Thrown when a network-related error occurs.
class NetworkException extends RxError {
  NetworkException(String message, [dynamic cause]) : super(message, cause);
}

/// 获取缓存出错时的异常
/// Thrown when a cache-related error occurs.
class CacheException extends RxError {
  CacheException(String message, [dynamic cause]) : super(message, cause);
}

/// 数据解析出错时的异常
/// Thrown when an error occurs during data parsing or transformation.
class ParsingException extends RxError {
  ParsingException(String message, [dynamic cause]) : super(message, cause);
}

/// 请求被取消时的异常
/// Thrown when a request is cancelled.
class CancellationException extends RxError {
  CancellationException(String message, [dynamic cause]) : super(message, cause);
}

/// 当在web端使用了移动端api时的异常
/// Throw when the mobile api is used on the web.
class WebException extends RxError {
  WebException(String message, [dynamic cause]) : super(message, cause);
}
