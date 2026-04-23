import '../../rxnet_lib.dart';


/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2026-04-23 9:06
/// describe: 简易输出所有请求和响应信息

class RxnetSimpleLogInterceptor extends AdapterInterceptor {
  final bool logHeaders;
  final bool logBody;

  RxnetSimpleLogInterceptor({
    this.logHeaders = true,
    this.logBody = true,
  });

  @override
  void onRequest(
      AdapterRequest request,
      RequestInterceptorHandler handler,
      ) {
    LogUtil.v('┌─────────────────────────────────────────────────');
    LogUtil.v('│ 📤 REQUEST');
    LogUtil.v('├─────────────────────────────────────────────────');
    LogUtil.v('│ Method: ${request.method.value}');
    LogUtil.v('│ URL: ${request.buildFullUrl()}');

    if (logHeaders && request.headers.isNotEmpty) {
      LogUtil.v('│ Headers:');
      request.headers.forEach((key, value) {
        LogUtil.v('│   $key: $value');
      });
    }

    if (logBody) {
      if (request.queryParams.isNotEmpty) {
        LogUtil.v('│ Query Params: ${request.queryParams}');
      }
      if (request.bodyParams.isNotEmpty) {
        LogUtil.v('│ Body Params: ${request.bodyParams}');
      }
      if (request.rawBody != null) {
        LogUtil.v('│ Raw Body: ${request.rawBody}');
      }
    }

    LogUtil.v('└─────────────────────────────────────────────────');

    // 继续请求
    handler.next(request);
  }

  @override
  void onResponse(
      AdapterResponse response,
      ResponseInterceptorHandler handler,
      ) {
    LogUtil.v('┌─────────────────────────────────────────────────');
    LogUtil.v('│ 📥 RESPONSE');
    LogUtil.v('├─────────────────────────────────────────────────');
    LogUtil.v('│ Status Code: ${response.statusCode}');
    LogUtil.v('│ URL: ${response.request.buildFullUrl()}');

    if (logHeaders && response.headers.isNotEmpty) {
      LogUtil.v('│ Headers:');
      response.headers.forEach((key, values) {
        LogUtil.v('│   $key: ${values.join(', ')}');
      });
    }

    if (logBody && response.data != null) {
      final dataStr = response.data.toString();
      if (dataStr.length > 500) {
        LogUtil.v('│ Data: ${dataStr.substring(0, 500)}... (truncated)');
      } else {
        LogUtil.v('│ Data: $dataStr');
      }
    }

    LogUtil.v('└─────────────────────────────────────────────────');

    // 继续响应
    handler.next(response);
  }

  @override
  void onError(
      AdapterException error,
      ErrorInterceptorHandler handler,
      ) {
    LogUtil.v('┌─────────────────────────────────────────────────');
    LogUtil.v('│ ❌ ERROR');
    LogUtil.v('├─────────────────────────────────────────────────');
    LogUtil.v('│ Type: ${error.type}');
    LogUtil.v('│ Message: ${error.message}');
    if (error.statusCode != null) {
      LogUtil.v('│ Status Code: ${error.statusCode}');
    }
    if (error.response != null) {
      LogUtil.v('│ URL: ${error.response!.request.buildFullUrl()}');
    }
    LogUtil.v('└─────────────────────────────────────────────────');

    // 继续错误
    handler.next(error);
  }
}