

import 'package:dio/dio.dart';

typedef JsonTransformation<T> = dynamic Function(dynamic data);

///http请求成功回调
typedef HttpSuccessCallback<Dynamic,SourcesType> = void Function(dynamic data,SourcesType model);

///失败回调
typedef HttpFailureCallback = void Function(dynamic data);


typedef ParamCallBack = void Function(Map<String, dynamic> params);

///检查网络的方法 是否有网络
typedef CheckNetWork = Future<bool> Function();


///全局捕获异常
typedef RequestCaptureError = void Function(dynamic error);

typedef OptionConfig = void Function(Options options);

typedef HandlerResponse = void Function(Response response, ResponseInterceptorHandler handler);

typedef HandlerRequest = void Function(RequestOptions options, RequestInterceptorHandler handler);

typedef HandlerError = void Function(DioError err, ErrorInterceptorHandler handler);
