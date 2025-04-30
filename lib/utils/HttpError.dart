
import 'package:dio/dio.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2021/6/9
/// create_time: 15:17
/// describe: HTTP 状态码
///
class HttpError {

  ///请求失败
  static const String REQUEST_FAILE = "REQUEST_FAILE";

  ///未知错误
  static const String UNKNOWN = "UNKNOWN";

  ///解析错误
  static const String PARSE_ERROR = "PARSE_ERROR";

  ///网络错误
  static const String NETWORK_ERROR = "NETWORK_ERROR";

  ///协议错误
  static const String HTTP_ERROR = "HTTP_ERROR";

  ///证书错误
  static const String SSL_ERROR = "SSL_ERROR";

  ///连接超时
  static const String CONNECT_TIMEOUT = "CONNECT_TIMEOUT";

  ///响应超时
  static const String RECEIVE_TIMEOUT = "RECEIVE_TIMEOUT";

  ///连接异常
  static const String CONNECT_ERROR = "CONNECT_ERROR";

  ///发送超时
  static const String SEND_TIMEOUT = "SEND_TIMEOUT";

  ///网络请求取消
  static const String CANCEL = "CANCEL";

  String? code;

  String? message;

  HttpError.dioError(DioException error) {
    message = error.message;
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        code = CONNECT_TIMEOUT;
        message = "网络连接超时，请检查网络设置";
        break;
      case DioExceptionType.receiveTimeout:
        code = RECEIVE_TIMEOUT;
        message = "服务器异常，请稍后重试！";
        break;
      case DioExceptionType.sendTimeout:
        code = SEND_TIMEOUT;
        message = "网络连接超时，请检查网络设置";
        break;
      case DioExceptionType.badResponse:
        code = HTTP_ERROR;
        message = "服务器异常，请稍后重试！";
        break;
      case DioExceptionType.cancel:
        code = CANCEL;
        message = "请求已被取消，请重新请求";
        break;
      case DioExceptionType.unknown:
        code = UNKNOWN;
        message = "网络异常，请稍后重试！";
        break;
      case DioExceptionType.badCertificate:
        code = SSL_ERROR;
        message = "证书异常，请稍后重试！";
        break;
      case DioExceptionType.connectionError:
        code = CONNECT_ERROR;
        message = "连接异常，请检查网络设置";
        break;
    }
  }

  @override
  String toString() {
    return 'HttpError{code: $code, message: $message}';
  }
}
