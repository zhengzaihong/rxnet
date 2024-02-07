import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_rxnet_forzzh/utils/LogUtil.dart';

import '../fun/fun_apply.dart';

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
    this.handlerError,
    this.handlerRequest,
    this.handlerResponse,
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

  /// 外部实现了这几个方法 ，请勿调用 super.xxx方法
  HandlerResponse? handlerResponse;

  HandlerError? handlerError;
  HandlerRequest? handlerRequest;


  final Map<String, DateTime> _requestMaps = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {

    logPrint('***************** Request Start *****************');
    _requestMaps[options.uri.toString()] = DateTime.now();
    printKV('uri', options.uri);
    if (request) {
      printKV('method', options.method);
      printKV('responseType', options.responseType.toString());
      printKV('followRedirects', options.followRedirects);
      printKV('connectTimeout', options.connectTimeout?.inMicroseconds??"");
      printKV('receiveTimeout', options.receiveTimeout?.inMicroseconds??"");
      printKV('extra', options.extra);
    }
    if (requestHeader) {
      logPrint('Request Headers:');
      // options.headers.forEach((key, v) => printKV(" $key", v));
      printAll(jsonEncode(options.headers));
    }
    if (requestBody) {
      logPrint("data:");
      printAll(jsonEncode(options.data));
    }
    logPrint('***************** Request End *****************');
    handlerRequest?.call(options, handler);
    super.onRequest(options, handler);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (error) {
      logPrint('***************** DioException Info Start *****************:');
      logPrint("uri: ${err.requestOptions.uri}");
      logPrint("$err");
      if (err.response != null) {
        _printResponse(err.response);
      }
      logPrint('***************** DioException Info End *****************:');
    }
    handlerError?.call(err, handler);
    super.onError(err, handler);
  }

  @override
  Future onResponse(
      Response response, ResponseInterceptorHandler handler) async {
    logPrint("***************** Response Start *****************");
    _printResponse(response);
    handlerResponse?.call(response, handler);
    return super.onResponse(response, handler);
  }

  void _printResponse(Response? response) {
    if (responseHeader) {
      printKV('statusCode', response?.statusCode ?? "");
      if (response?.isRedirect == true) {
        printKV('redirect', response!.realUri);
      }
      if (response?.headers != null) {
        logPrint("Response Headers:");
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
    logPrint('useTime:${duration.inMinutes}分:${duration.inSeconds}秒:${duration.inMilliseconds}毫秒');
    logPrint('Response url :${response?.requestOptions?.uri}');

    logPrint("***************** Response End *****************");
  }

  printKV(String key, Object v) {
    logPrint('$key: $v');
  }

  printAll(msg) {
    msg.toString().split("\n").forEach(logPrint);
  }
}
