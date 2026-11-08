import '../../../rxnet_lib.dart';
import '../../../utils/log_redactor.dart';


/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2026-04-23 9:06
/// describe: 简易输出所有请求和响应信息

class RxnetSimpleLogInterceptor extends AdapterInterceptor {
  final bool logHeaders;
  final bool logBody;

  /// 是否输出敏感字段原文（默认 false）
  final bool logSensitiveData;

  RxnetSimpleLogInterceptor({
    this.logHeaders = true,
    this.logBody = true,
    this.logSensitiveData = false,
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
    LogUtil.v('│ URL: ${LogRedactor.redactUrl(request.buildFullUrl())}');

    if (logHeaders && request.headers.isNotEmpty) {
      LogUtil.v('│ Headers:');
      request.headers.forEach((key, value) {
        final display = logSensitiveData || !LogRedactor.isSensitiveKey(key)
            ? value
            : LogRedactor.mask;
        LogUtil.v('│   $key: $display');
      });
    }

    if (logBody) {
      if (request.queryParams.isNotEmpty) {
        LogUtil.v(
          '│ Query Params: '
          '${logSensitiveData ? request.queryParams : LogRedactor.toSafeJson(request.queryParams)}',
        );
      }
      if (request.bodyParams.isNotEmpty) {
        LogUtil.v(
          '│ Body Params: '
          '${logSensitiveData ? request.bodyParams : LogRedactor.toSafeJson(request.bodyParams)}',
        );
      }
      if (request.rawBody != null) {
        LogUtil.v(
          '│ Raw Body: '
          '${logSensitiveData ? request.rawBody : LogRedactor.toSafeJson(request.rawBody)}',
        );
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
    LogUtil.v(
      '│ URL: ${LogRedactor.redactUrl(response.request.buildFullUrl())}',
    );

    if (logHeaders && response.headers.isNotEmpty) {
      LogUtil.v('│ Headers:');
      response.headers.forEach((key, values) {
        final display = logSensitiveData || !LogRedactor.isSensitiveKey(key)
            ? values.join(', ')
            : LogRedactor.mask;
        LogUtil.v('│   $key: $display');
      });
    }

    if (logBody && response.data != null) {
      final dataStr = logSensitiveData
          ? response.data.toString()
          : LogRedactor.toSafeJson(response.data);
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
      LogUtil.v(
        '│ URL: ${LogRedactor.redactUrl(error.response!.request.buildFullUrl())}',
      );
    }
    LogUtil.v('└─────────────────────────────────────────────────');

    // 继续错误
    handler.next(error);
  }
}