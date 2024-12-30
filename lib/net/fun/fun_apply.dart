

import 'package:dio/dio.dart';

import '../type/sources_type.dart';

typedef JsonTransformation<E> = E Function(dynamic data);

///http请求成功回调
typedef SuccessCallback<T> = void Function(T data,SourcesType model);

///失败回调
typedef FailureCallback<T> = void Function(dynamic data);

/// 成功或失败都会执行的方法
typedef FinallyCallback<T> = void Function();

/// 缓存失效超时回调
typedef CacheInvalidationCallback<T> = void Function();

typedef ParamCallBack = void Function(Map<String, dynamic> params);

///检查网络的方法 是否有网络
typedef CheckNetWork = Future<bool> Function();


///全局捕获异常
typedef RequestCaptureError = void Function(dynamic error);

typedef OptionConfig = void Function(Options options);

typedef HandlerResponse = void Function(Response response, ResponseInterceptorHandler handler);

typedef HandlerRequest = void Function(RequestOptions options, RequestInterceptorHandler handler);

typedef HandlerError = void Function(Exception err, ErrorInterceptorHandler handler);
