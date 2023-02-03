import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_rxnet_forzzh/utils/LogUtil.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2021/6/9
/// create_time: 16:16
/// describe: 自定义日志拦截器   适配dio 4.0
///

void log2Console(Object object) {
  LogUtil.v(object);
}

class CustomLogInterceptor extends Interceptor {
  CustomLogInterceptor({
    this.request = true,
    this.requestHeader = true,
    this.requestBody = true,
    this.responseHeader = true,
    this.responseBody = true,
    this.error = true,
    this.logPrint = log2Console,
  });

  /// 是否打印请求参数
  bool request;

  /// 是否打印请求头
  bool requestHeader;

  /// 是否打印请求参数 post
  bool requestBody;

  /// 是否打印响应数据
  bool responseBody;

  /// 是否打印响应头
  bool responseHeader;

  /// 是否打印错误信息
  bool error;

  void Function(Object object) logPrint;

  final Map<String, DateTime> _requestMaps = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    super.onRequest(options, handler);
    logPrint('*** Request ***');
    _requestMaps[options.uri.toString()] = DateTime.now();
    printKV('uri', options.uri);
    if (request) {
      printKV('method', options.method);
      printKV('responseType', options.responseType.toString());
      printKV('followRedirects', options.followRedirects);
      printKV('connectTimeout', options.connectTimeout);
      printKV('receiveTimeout', options.receiveTimeout);
      printKV('extra', options.extra);
    }
    if (requestHeader) {
      logPrint('headers:');
      options.headers.forEach((key, v) => printKV(" $key", v));
    }
    if (requestBody) {
      logPrint("data:");
      printAll(jsonEncode(options.data));
    }
    logPrint("");
  }

  @override
  void onError(DioError err, ErrorInterceptorHandler handler) {
    if (error) {
      logPrint('*** DioError ***:');
      logPrint("uri: ${err.requestOptions.uri}");
      logPrint("$err");
      if (err.response != null) {
        _printResponse(err.response);
      }
      logPrint("");
    }
    super.onError(err, handler);
  }

  @override
  Future onResponse(
      Response response, ResponseInterceptorHandler handler) async {
    logPrint("*** Response ***");
    _printResponse(response);

    return super.onResponse(response, handler);
  }

  void _printResponse(Response? response) {
    if (responseHeader) {
      printKV('statusCode', response?.statusCode ?? "");
      if (response?.isRedirect == true) {
        printKV('redirect', response!.realUri);
      }
      if (response?.headers != null) {
        logPrint("headers:");
        response?.headers.forEach((key, v) => printKV(" $key", v.join(",")));
      }
    }
    if (responseBody) {
      logPrint("Response Text:");
      printAll(response.toString());
    }

    DateTime oldTime =
        _requestMaps[response?.requestOptions?.uri?.toString()] ??
            DateTime.now();
    DateTime responseTime = DateTime.now();
    Duration duration = responseTime.difference(oldTime);
    logPrint('useTime:${duration.inMinutes}:${duration.inSeconds}:${duration.inMilliseconds}');
    logPrint('Response end url :${response?.requestOptions?.uri}');
  }

  printKV(String key, Object v) {
    logPrint('$key: $v');
  }

  printAll(msg) {
    msg.toString().split("\n").forEach(logPrint);
  }
}
