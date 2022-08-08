
import 'dart:collection';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:rxnet/net/json_convert_adapter.dart';
import 'package:rxnet/utils/HttpError.dart';
import 'package:rxnet/utils/LogUtil.dart';
import 'package:rxnet/utils/NetUtils.dart';

import '../utils/DatabaseUtil.dart';
import '../utils/TextUtil.dart';
import 'cache_mode.dart';

typedef JsonTransformation<T> = T? Function(Map<String,dynamic> data);


///http请求成功回调
typedef HttpSuccessCallback<Dynamic,DataModel> = void Function(dynamic data,DataModel model);

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
  RxNet init({
    required String baseUrl,
    String dbName = "dataMapper",
    List<Interceptor>? interceptors,
    BaseOptions? options,
   }) {
    /// 全局属性：请求前缀、连接超时时间、响应超时时间

    options ??= BaseOptions(
           baseUrl: baseUrl ,
          connectTimeout: connectTimeout,
          receiveTimeout: receiveTimeout,
          contentType: Headers.jsonContentType,
          responseType: ResponseType.json);

    _client?.options = options;
    if (interceptors != null) {
      _client?.interceptors.addAll(interceptors);
    }
    print("_client:${_client == null}");
    print("options:${_client?.options == null}");

    try{
      if(Platform.isAndroid || Platform.isIOS){
        DatabaseUtil.initDatabase(dbName);
      }
    }catch(e){
      LogUtil.v("环境：web");
    }

    return this;
  }
  static BuildRequest get(){
    return  BuildRequest(
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

class BuildRequest{

  RequestType requestType;
  String? _baseUrl;
  final RxNet _rxNet;
  String? _cancleTag;

  String? _path;

  CacheMode? _cacheMode = CacheMode.noCache;

  Map<String,dynamic> _params = HashMap();

  Map<String,dynamic> _headers = HashMap();

  Map<String,dynamic> _bodyData = HashMap();

  bool _useJsonAdapter = true;
  JsonConvertAdapter? _jsonConvertAdapter;

  BaseOptions? _options;

  BuildRequest(this.requestType,this._rxNet){
    _options = _rxNet.client?.options;
    _baseUrl = _options?.baseUrl;
    print("0000000${_baseUrl}");
  }


  BuildRequest setUseJsonAdapter(bool use) {
    _useJsonAdapter = use;
    return this;
  }


  BuildRequest setJsonConvertAdapter(JsonConvertAdapter adapter){
    _jsonConvertAdapter = adapter;
    return this;
  }
  JsonConvertAdapter? getJsonConvertAdapter(){
    return _jsonConvertAdapter;
  }



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

  BuildRequest setOptions(BaseOptions options) {
    _options = options;
    return this;
  }



  void doWorkRequest({
    HttpSuccessCallback? success,
    HttpFailureCallback? failure,
    bool cache =false,
    Function? readCache,
   }){

    Request().request(
        url:_path!,
        method: requestType.name,
        tag: "$_cancleTag",
        client: _rxNet.client,
        params: _params,
        data: _bodyData,
        options: _options,
        successCallback: success,
        errorCallback: failure,
        cache: cache,
        readCache: readCache,
        useJsonAdapter: _useJsonAdapter,
        adapter: getJsonConvertAdapter()

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
            cache: true,
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
      default:
        doWorkRequest(
            success: success,
            failure: failure,
            cache: true
        );
        break;
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



class Request{

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
    BaseOptions? options,
    HttpSuccessCallback? successCallback,
    HttpFailureCallback? errorCallback,
    required String? tag,
    required Dio? client,
    bool cache =false,
    Function? readCache,
    bool useJsonAdapter = true,
    JsonConvertAdapter? adapter,
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

    params = params ?? {};
    options?.method = method;
    print("options:${options==null}");

    url = NetUtils.restfulUrl(url, params);
    print("url:${options?.baseUrl}$url");
    try {
      client?.options.method = method;
      Response<Map<String,dynamic>> response = await client!.request(url,
          data: data,
          queryParameters: params,
          cancelToken: _cancelTokens[tag]);

       ///成功
      if(response.statusCode ==200){
        if(useJsonAdapter && adapter!=null){
          LogUtil.v("useJsonAdapter：true");
          var data = adapter.jsonTransformation.call(response.data!);
          successCallback?.call(data,DataModel.net);
        }else{
          LogUtil.v("useJsonAdapter：false");
          successCallback?.call(response.data,DataModel.net);
        }

        /// 数据库目前只支持 android 和 ios
        try{
          if(cache && (Platform.isIOS || Platform.isAndroid)){
            /// 存储数据

          }
        }catch(e){
          LogUtil.v("catch环境：web");
        }

      }else{
        if(readCache!=null){
          readCache.call();
        }else{
          ///失败
          errorCallback?.call(response.data);
        }
      }
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
