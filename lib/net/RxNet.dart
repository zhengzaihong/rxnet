
import 'dart:async';
import 'dart:collection';
import 'dart:core';
import 'dart:core';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:rxdart/rxdart.dart';
import 'package:rxnet/callback/NetCallBack.dart';
import 'package:rxnet/utils/NetUtils.dart';

import '../utils/DatabaseUtil.dart';
import '../utils/TextUtil.dart';
import 'cache_mode.dart';
typedef JsonTransformation<T> = T Function(String);


///http请求成功回调
typedef HttpSuccessCallback<T> = void Function(T data);

///失败回调
typedef HttpFailureCallback = void Function(dynamic data);


class RxNet {

  ///超时时间
  static const int connectTimeout = 30 * 1000;
  static const int receiveTimeout = 30 * 1000;

  Dio? _client;

  static final RxNet _instance = RxNet._internal();

  factory RxNet() => _instance;


  Dio? get client => _client;

  /// 创建 dio 实例对象
  RxNet._internal() {
    if (_client == null) {
      /// 全局属性：请求前缀、连接超时时间、响应超时时间
      BaseOptions options = BaseOptions(
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json);
      _client = Dio(options);
    }
  }

  ///初始化公共属性
  /// [baseUrl] 地址前缀
  /// [interceptors] 基础拦截器
  void init({required String baseUrl, List<Interceptor>? interceptors}) {
    _client?.options.baseUrl = baseUrl;
    if (interceptors != null) {
      _client?.interceptors.addAll(interceptors);
    }
  }

  static BuildRequest get<T>(){
    return  BuildRequest<T>(
        RequestType.GET,
        RxNet().client?.options?.baseUrl);
  }


}

typedef ParamCallBack = void Function(Map<String, dynamic> params);
class BuildRequest<T>{

  RequestType requestType;
  String? baseUrl;
  BuildRequest(this.requestType,this.baseUrl);

  JsonTransformation<T> _jsonTransformation = (data) {
    return data as T;
  };

  static Future initDatabase() {
    return DatabaseUtil.initDatabase();
  }

  static bool isDatabaseReady() {
    return DatabaseUtil.isDatabaseReady;
  }


  String? _path;

  CacheMode? _cacheMode = CacheMode.noCache;

  Map<String,dynamic> _params = HashMap();


  BuildRequest setPath(String path) {
    if (TextUtil.isEmpty(path)) {
      throw Exception("path can not be null!");
    }
    _path = path;
    return this;
  }

  BuildRequest setParam(String key,dynamic value) {
    _params[key] = value;
    return this;
  }

  BuildRequest setNewParams(Map<String,dynamic> param) {
    _params = param;
    return this;
  }

  BuildRequest addParams(Map<String,dynamic> param) {
    _params.addAll(param);
    return this;
  }

  BuildRequest getParams(ParamCallBack callBack) {
    callBack.call(_params);
    return this;
  }



  BuildRequest setCacheMode(CacheMode cacheMode) {
    _cacheMode = cacheMode;
    return this;
  }

  BuildRequest setJsonTransFrom(JsonTransformation<T> jsonTransformation) {
    _jsonTransformation = jsonTransformation;
    return this;
  }



  void doWorkRequest({Function? work}){
    switch(requestType){
      case RequestType.GET:
        ///todo
        break;
      case RequestType.POST:


        break;
    }

    work?.call();
  }


  BuildRequest call({
    HttpSuccessCallback? success,
    HttpFailureCallback? failure}) {

    if (_cacheMode == CacheMode.noCache) {
      //只获取网络
     doWorkRequest();

    } else if (_cacheMode == CacheMode.firstCacheThenRequest) {
       ///先获取缓存，在获取网络

        NetUtils.getCache("$baseUrl$_path", _params).then((list) {
          if (list.isNotEmpty) {

          } else {

          }
        });
      doWorkRequest(work: (){
        NetUtils.postNet<String>("$baseUrl$_path", _params).then((response) {

        });
      });

    } else if (_cacheMode == CacheMode.requestFailedReadCache) {
      if (_requestMethord == REQUEST_METHORD.GET) {
        NetUtils.getNet<String>(_baseurl + _path, _params).then((response) {
          if (response.statusCode == 200) {
            controller.add(new RequestData(
                requestType: RequestType.NET,
                data: _jsonTransformation(response.data)));
          } else {
            NetUtils.getCache(_baseurl + _path, _params).then((list) {
              if (list.length > 0) {
                controller.add(new RequestData(
                    requestType: RequestType.CACHE,
                    data: _jsonTransformation(
                        json.decoder.convert(list[0]["value"])),
                    statusCode: 200));
              } else {
                controller.add(new RequestData(
                    requestType: RequestType.CACHE,
                    data: null,
                    statusCode: 400));
              }
            });
          }
        });
      } else if (_requestMethord == REQUEST_METHORD.POST) {
        NetUtils.postNet<String>(_baseurl + _path, _params).then((response) {
          if (response.statusCode == 200) {
            controller.add(RequestData(
                requestType: RequestType.NET,
                data: _jsonTransformation(response.data)));
          } else {
            NetUtils.getCache(_baseurl + _path, _params).then((list) {
              if (list.length > 0) {
                controller.add(new RequestData(
                    requestType: RequestType.CACHE,
                    data: _jsonTransformation(
                        json.decoder.convert(list[0]["value"])),
                    statusCode: 200));
              } else {
                controller.add(new RequestData(
                    requestType: RequestType.CACHE,
                    data: null,
                    statusCode: 400));
              }
            });
          }
        });
      }
    } else if (_cacheMode == CacheMode.DEFAULT) {}

    return this;
  }

}

enum RequestType {
  GET,
  POST,
}
