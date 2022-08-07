
import 'dart:collection';
import 'dart:core';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:rxnet/bean/base_bean.dart';
import 'package:rxnet/utils/HttpError.dart';
import 'package:rxnet/utils/LogUtil.dart';
import 'package:rxnet/utils/NetUtils.dart';

import '../utils/DatabaseUtil.dart';
import '../utils/TextUtil.dart';
import 'cache_mode.dart';
typedef JsonTransformation<T> = T Function(String);


///http请求成功回调
typedef HttpSuccessCallback<T,DataModel> = void Function(T data,DataModel model);

///失败回调
typedef HttpFailureCallback = void Function(dynamic data);


///同一个CancelToken可以用于多个请求，当一个CancelToken取消时，所有使用该CancelToken的请求都会被取消，一个页面对应一个CancelToken。
final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};

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
    _client ??= Dio();
  }

  ///初始化公共属性
  /// [baseUrl] 地址前缀
  /// [interceptors] 基础拦截器
  void init({required String baseUrl,
    List<Interceptor>? interceptors,
    BaseOptions? options,
   }) {
    /// 全局属性：请求前缀、连接超时时间、响应超时时间

    options ??= BaseOptions(
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json);

    _client?.options = options;
    _client?.options.baseUrl = baseUrl;
    if (interceptors != null) {
      _client?.interceptors.addAll(interceptors);
    }
    DatabaseUtil.initDatabase();
  }

  static BuildRequest get<T>(){
    return  BuildRequest<T>(
        RequestType.get,
        RxNet._internal(),
    );
  }


  ///取消网络请求
  void cancel(String tag) {
    if (_cancelTokens.containsKey(tag)) {
      if (!_cancelTokens[tag]!.isCancelled) {
        _cancelTokens[tag]?.cancel();
      }
      _cancelTokens.remove(tag);
    }
  }


}

typedef ParamCallBack = void Function(Map<String, dynamic> params);

class BuildRequest<T>{

  RequestType requestType;
  String? _baseUrl;
  final RxNet _rxNet;
  String? _cancleTag;

  BuildRequest(this.requestType,this._rxNet){
    _baseUrl = _rxNet.client?.options.baseUrl;
  }

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

  Map<String,dynamic> _headers = HashMap();

  Map<String,dynamic> _bodyData = HashMap();


  BuildRequest setPath(String path) {
    if (TextUtil.isEmpty(path)) {
      throw Exception("path can not be null!");
    }
    _path = path;
    return this;
  }

  BuildRequest setBodyData(Map<String,dynamic> param) {
    _bodyData = param;
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



  BuildRequest setHeaders(Map<String, dynamic> headers) {
    _headers = headers;
    return this;
  }

  BuildRequest setHeader(String key,dynamic value) {
    _headers[key] = value;
    return this;
  }


  BuildRequest setTag(String tag) {
    _cancleTag = tag;
    _cancelTokens[tag] =  CancelToken();
    return this;
  }

  BuildRequest covertParamToBody() {
    _bodyData.addAll(_params);
    _params.clear();
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



  void doWorkRequest({
    HttpSuccessCallback? success,
    HttpFailureCallback? failure,
    Function? work,
    bool cache =false,
    Function? readCache,
   }){

    Request<T>().request(
        url: _path!,
        method: requestType.name,
        tag: "$_cancleTag",
        client: _rxNet.client,
        params: _params,
        data: _bodyData,
        successCallback: success,
        errorCallback: failure,
        cache: cache,
        readCache: readCache,

    );

  }


  BuildRequest call({
    HttpSuccessCallback? success,
    HttpFailureCallback? failure}) {

    switch(_cacheMode){
      case CacheMode.noCache:{
        ///只获取网络
        doWorkRequest(
          success: success,
          failure: failure
        );
        break;
      }
      case CacheMode.firstCacheThenRequest:{
        ///先获取缓存，在获取网络
        NetUtils.getCache("$_baseUrl$_path", _params).then((list) {
          if (list.isNotEmpty) {
            success?.call(list,DataModel.cache);
          }
        });
        doWorkRequest(
            success: success,
            failure: failure,
            /// 存储数据
            cache: true
        );
        break;
      }

      case CacheMode.requestFailedReadCache:{
        ///先请求网络，如果请求网络失败，则读取缓存，如果读取缓存失败，本次请求失败
        doWorkRequest(
            success: success,
            failure: failure,
            readCache: (){
              NetUtils.getCache("$_baseUrl$_path", _params).then((list) {
                if (list.isNotEmpty) {
                  success?.call(list,DataModel.cache);
                }else{
                  failure?.call({});
                }
              });
            }
        );
        break;
      }
    }


    return this;
  }

}

enum RequestType {
  get,
  post,
}

enum DataModel {
  cache,
  net,
}



class Request<T>{

  ///统一网络请求
  ///
  ///[url] 网络请求地址不包含域名
  ///[data] post 请求参数
  ///[params] url请求参数支持restful
  ///[options] 请求配置
  ///[successCallback] 请求成功回调
  ///[errorCallback] 请求失败回调
  ///[tag] 请求统一标识，用于取消网络请求
  void request({
    required String url,
    required String method,
    dynamic  data,
    Map<String, dynamic>? params,
    Options? options,
    HttpSuccessCallback<T,DataModel>? successCallback,
    HttpFailureCallback? errorCallback,
    required String? tag,
    required Dio? client,
    bool cache =false,
    Function? readCache,
    Function? work,
  }) async {
    ///检查网络是否连接
    ConnectivityResult connectivityResult =
    await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      if (errorCallback != null) {
        errorCallback(HttpError(HttpError.NETWORK_ERROR, "网络异常，请稍后重试！"));
      }
      LogUtil.v("请求网络异常，请稍后重试！");
      return;
    }

    print("-------------1");

    params = params ?? {};
    options?.method = method;
    options = options ??
        Options(
          method: method,
        );

    url = NetUtils.restfulUrl(url, params);
    try {
      client?.options.method = method;
      Response<Map<String, dynamic>> response = await client!.request(url,
          data: data,
          queryParameters: params,
          options: options,
          cancelToken: _cancelTokens[tag]);


      if(response.statusCode ==200){
        print("-------------122");
        ///成功
        successCallback?.call(response.data as T,DataModel.net);

        if(cache){
          /// 存储数据

        }
        work?.call();
      }else{
        if(readCache!=null){
          readCache.call();
        }else{
          ///失败
          errorCallback?.call(response);
        }
      }
      // ParseJson<T>(response, successCallback, errorCallback, url: url).parse();
    } on DioError catch (e, s) {
      LogUtil.v("请求出错：$e\n$s");
      if (errorCallback != null && e.type != DioErrorType.cancel) {
        errorCallback(HttpError.dioError(e));
      }
    } catch (e, s) {
      LogUtil.v("未知异常出错：$e\n$s");
      if (errorCallback != null) {
        errorCallback(HttpError(HttpError.UNKNOWN, "网络异常，请稍后重试！"));
      }
    }
  }
}
