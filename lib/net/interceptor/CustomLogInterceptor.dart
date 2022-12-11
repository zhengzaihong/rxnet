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


  ///  这里提供一个收集日字的方法，便于后期排查
  ///  var file=File("./log.txt");
  ///  var sink=file.openWrite();
  ///  dio.interceptors.add(LogInterceptor(logPrint: sink.writeln));
  ///  await sink.close();
  ///
  void Function(Object object) logPrint;

  final Map<String,int> _requestMaps = {};

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    super.onRequest(options, handler);
    logPrint('*** Request ***');
    _requestMaps[options.uri.toString()] =DateTime.now().millisecondsSinceEpoch;
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
  Future onResponse(Response response ,  ResponseInterceptorHandler handler) async {
    logPrint("*** Response ***");
    _printResponse(response);

    return super.onResponse(response, handler);
  }

  void _printResponse(Response? response) {
    printKV('uri', response?.requestOptions?.uri??"");
    if (responseHeader) {
      printKV('statusCode', response?.statusCode??"");
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

    int time =  DateTime.now().millisecondsSinceEpoch - (_requestMaps[response?.requestOptions?.uri?.toString()]??0);
    logPrint('useTime:${millisecondsConvertToDHMS(time)}');
    logPrint('url:${response?.requestOptions?.uri}');

  }

  printKV(String key, Object v) {
    logPrint('$key: $v');
  }

  printAll(msg) {
    msg.toString().split("\n").forEach(logPrint);
  }


}


String millisecondsConvertToDHMS(int milliseconds) {

  String daysStr;
  String hoursStr;
  String minutesStr;
  String secondsStr;
  //天
  double day = (milliseconds / 1000) / (24 * 3600);
  if (day < 10) {
    daysStr = "0${day.toInt()}";
  } else {
    daysStr = day.toString();
  }
  //时
  double hour = ((milliseconds / 1000) % (24 * 3600)) / 3600;
  if (hour < 10) {
    hoursStr = "0${hour.toInt()}";
  } else {
    hoursStr = hour.toString();
  }
  //分
  double minute = ((milliseconds / 1000) % 3600) / 60;
  if (minute < 10) {
    minutesStr = "0${minute.toInt()}";
  } else {
    minutesStr = minute.toString();
  }
  //秒
  double second = (milliseconds / 1000) % 60;
  if (second < 10) {
    secondsStr = "0${second.toInt()}";
  } else {
    secondsStr = second.toString();
  }

  return "耗时：$daysStr天$hoursStr:$minutesStr:$secondsStr";
}
