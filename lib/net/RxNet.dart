import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'package:dio/adapter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2022/8/9
/// create_time: 18:03
/// describe: 网络请求工具库，支持多种缓存模式（目前只支持 android 和 IOS 平台，因为数据缓存基于sqlite）

///同一个CancelToken可以用于多个请求，当一个CancelToken取消时，所有使用该CancelToken的请求都会被取消。
final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};

class RxNet {

  Dio? _client;

  static final RxNet _instance = RxNet._internal();

  /// 是否使用代理
  bool _isProxyEnable = false;

  factory RxNet() => _instance;

  Dio? get client => _client;

  /// 创建 dio 实例对象
  RxNet._internal() {
    var options = BaseOptions(
        // connectTimeout: connectTimeout,
        // receiveTimeout: receiveTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json);

    _client ??= Dio(options);
  }

  ///初始化公共属性
  /// [baseUrl] 地址前缀
  /// [interceptors] 基础拦截器
  RxNet init({
    required String baseUrl,
    String dbName = "dataMapper",
    String? tableName,
    List<Interceptor>? interceptors,
    BaseOptions? options,
    bool isDebug = true,
  }) {

    LogUtil.init(isDebug: isDebug);
    if (options != null) {
      _client?.options = options;
    }
    _client?.options.baseUrl = baseUrl;
    if (interceptors != null) {
      _client?.interceptors.addAll(interceptors);
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        DatabaseUtil.initDatabase(dbName,tabname: tableName);
      }
    } catch (e) {
      LogUtil.v("不支持的环境：web, windows");
    }
    return this;
  }

  RxNet setEnableProxy(bool enable){
    _isProxyEnable = enable;
    return this;
  }
  bool isEnableProxy(){
    return _isProxyEnable;
  }

  /// isProxyEnable 为true 才会生效
  /// 前置方法 setEnableProxy
  void setProxy(String ip,int port){
    if(isEnableProxy()){
      (_instance.client?.httpClientAdapter as DefaultHttpClientAdapter).onHttpClientCreate = (client) {
        client.findProxy = (uri) {
          return "PROXY $ip:$port";
        };
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
      };
    }
  }

  static BuildRequest get<T>() {
    return BuildRequest(
      HttpType.get,
      RxNet(),
    );
  }
  static BuildRequest post<T>() {
    return BuildRequest(
      HttpType.post,
      RxNet(),
    );
  }

  static BuildRequest delete<T>() {
    return BuildRequest(
      HttpType.delete,
      RxNet(),
    );
  }

  static BuildRequest put<T>() {
    return BuildRequest(
      HttpType.put,
      RxNet(),
    );
  }

  static BuildRequest patch<T>() {
    return BuildRequest(
      HttpType.patch,
      RxNet(),
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



class BuildRequest<T> {

  final HttpType _httpType;

  final RxNet _rxNet;

  String? _cancleTag;

  String? _path;

  CacheMode _cacheMode = CacheMode.onlyRequest;

  Map<String, dynamic> _params = {};

  Map<String, dynamic> _headers = {};

  dynamic _bodyData;

  bool _useJsonAdapter = true;

  JsonConvertAdapter<T>? _jsonConvertAdapter;

  Options? _options;

  bool _enableRestfulUrl = false;

  BuildRequest(this._httpType, this._rxNet);

  BuildRequest setUseJsonAdapter(bool use) {
    _useJsonAdapter = use;
    return this;
  }

  BuildRequest setJsonConvertAdapter(JsonConvertAdapter<T> adapter) {
    _jsonConvertAdapter = adapter;
    return this;
  }

  JsonConvertAdapter<T>? getJsonConvertAdapter() {
    return _jsonConvertAdapter;
  }

  /// 处理 RestfulUrl格式请求
  /// 如：xxxx/xxx/weather?city=101030100
  /// 结果：xxxx/xxx/weather/city/101030100
  BuildRequest setEnableRestfulUrl(bool restful) {
    _enableRestfulUrl = restful;
    return this;
  }

  bool getEnableRestfulUrl() {
    return _enableRestfulUrl;
  }

  BuildRequest setPath(String path) {
    if (TextUtil.isEmpty(path)) {
      throw Exception("请求路径不能为空 path:$_path");
    }
    _path = path;
    return this;
  }

  BuildRequest setBodyData(dynamic param) {
    _bodyData = param;
    return this;
  }

  BuildRequest setParam(String key, dynamic value) {
    _params[key] = value;
    return this;
  }

  BuildRequest setNewParams(Map<String, dynamic> param) {
    _params = param;
    return this;
  }

  BuildRequest addParams(Map<String, dynamic> param) {
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

  BuildRequest setHeader(String key, dynamic value) {
    _headers[key] = value;
    return this;
  }

  BuildRequest setTag(String tag) {
    _cancleTag = tag;
    _cancelTokens[tag] = CancelToken();
    return this;
  }

  String? getTag() {
    return _cancleTag;
  }

  BuildRequest covertParamToBody() {
    _bodyData = _params;
    _params.clear();
    return this;
  }

  BuildRequest setCacheMode(CacheMode cacheMode) {
    _cacheMode = cacheMode;
    return this;
  }

  BuildRequest setOptions(Options options) {
    _options = options;
    return this;
  }

  ///提供一个检查网络的方法，外部需要自行实现
  BuildRequest setCheckNetwork(CheckNetwork? checkNetwork){
    checkNetwork?.call();
    return this;
  }


  void _doWorkRequest({
    HttpSuccessCallback? success,
    HttpFailureCallback? failure,
    bool cache = false,
    Function? readCache,
  }) async {

    String url = _path.toString();
    if (getEnableRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = _httpType.name;
      if(_headers.isNotEmpty){
        _options?.headers = _headers;
      }
      // Response<Map<String, dynamic>> response = await _rxNet.client!.request(
      Response<T> response = await _rxNet.client!.request(
          url,
          data: _bodyData,
          queryParameters: getEnableRestfulUrl()?{}:_params,
          options: _options,
          cancelToken: _cancelTokens[getTag()]);

      ///成功
      if (response.statusCode == 200)
      {
        if (_useJsonAdapter && getJsonConvertAdapter() != null) {
          LogUtil.v("useJsonAdapter：true");
          var data = getJsonConvertAdapter()?.jsonTransformation.call(response.data);
          success?.call(data!, SourcesType.net);
        } else {
          LogUtil.v("useJsonAdapter：false");
          success?.call(response.data, SourcesType.net);
        }

        /// 数据库目前只支持 android 和 ios
        try {
          if (cache && (Platform.isIOS || Platform.isAndroid)) {
            String cacheKey = NetUtils.getCacheKeyFromPath("$_path", _params);
            /// 存储数据
            NetUtils.saveCache(cacheKey, response.data==null?"":jsonEncode(response.data));
          }
        } catch (e) {
          LogUtil.v("catch环境：web");
        }
      }
      else {
        if (readCache != null) {
          readCache.call();
        } else {
          ///失败
          failure?.call(HttpError(HttpError.REQUEST_FAILE, "请求失败",response.data));
        }
      }

    } on DioError catch (e, s) {
      LogUtil.v("请求出错：$e\n$s");
      if (failure != null && e.type != DioErrorType.cancel) {
        var error = HttpError.dioError(e);
        error.bodyData = e;
        failure(error);
      }
    } catch (e, s) {
      LogUtil.v("未知异常出错：$e\n$s");
      if (failure != null) {
        failure.call(HttpError(HttpError.UNKNOWN, "未知异常出错",e));
      }
    }
  }


  ///解析本地缓存数据
  void _parseLocalData(
      HttpSuccessCallback? success,
      HttpFailureCallback? failure,
      List<Map<String,dynamic>> list,
      ){
    var datas = list[0]["value"];
    if (_useJsonAdapter && getJsonConvertAdapter() != null) {
      LogUtil.v("useJsonAdapter：true");
      var data = getJsonConvertAdapter()?.jsonTransformation.call(jsonDecode(datas));
      success?.call(data, SourcesType.cache);
    } else {
      LogUtil.v("useJsonAdapter：false");
      success?.call(datas, SourcesType.cache);
    }
  }


  void _readCache(
      HttpSuccessCallback? success,
      HttpFailureCallback? failure,
      ){
    DatabaseUtil.setDataBaseReadListener((isOk){
      NetUtils.getCache("$_path", _params).then((list) {
        if (list.isNotEmpty) {
          _parseLocalData(success,failure,list);
        } else {
          failure?.call({});
        }
      });
    });
  }

  BuildRequest execute({HttpSuccessCallback? success, HttpFailureCallback? failure}) {
    switch (_cacheMode) {
      case CacheMode.onlyRequest:
        {
          _doWorkRequest(success: success, failure: failure);
          break;
        }
      case CacheMode.firstCacheThenRequest:
        {
          _readCache(success,failure);
          _doWorkRequest(
              success: success,
              failure: failure,
              cache: true);
          break;
        }
      case CacheMode.requestFailedReadCache:
        {
          _doWorkRequest(
              success: success,
              failure: failure,
              cache: true,
              readCache: () {
                _readCache(success,failure);
              });
          break;
        }

      case CacheMode.onlyCache:
        {
          _readCache(success,failure);
          break;
        }

      case CacheMode.requestAndSaveCache:
        {
          _doWorkRequest(success: success, failure: failure, cache: true);
          break;
        }
    }
    return this;
  }


  ///上传文件
  void upload({
    ProgressCallback? onSendProgress,
    HttpSuccessCallback? success,
    HttpFailureCallback? failure,
  }) async {
    String url = _path.toString();
    if (getEnableRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = _httpType.name;
      if(_headers.isNotEmpty){
        _options?.headers = _headers;
      }
      Response<T> response = await _rxNet.client!.request(
      // Response<Map<String, dynamic>> response = await _rxNet.client!.request(
          url,
          onSendProgress: onSendProgress,
          data: _bodyData,
          queryParameters: getEnableRestfulUrl()?{}:_params,
          options: _options,
          cancelToken: _cancelTokens[getTag()]);

      if(response.statusCode == 200){
        success?.call(response.data, SourcesType.net);
      }else{
        failure?.call(HttpError(HttpError.REQUEST_FAILE, "请求失败",response.data));
      }

    } on DioError catch (e, s) {
      LogUtil.v("请求出错：$e\n$s");
      if (failure != null && e.type != DioErrorType.cancel) {
        var error = HttpError.dioError(e);
        error.bodyData = e;
        failure(error);
      }
    } catch (e, s) {
      LogUtil.v("未知异常出错：$e\n$s");
      if (failure != null) {
        failure(HttpError(HttpError.UNKNOWN, "网络异常，请稍后重试！",e));
      }
    }
  }


  ///下载文件
  ///[savePath]  文件保存路径
  void download({
    required String savePath,
    ProgressCallback? onReceiveProgress,
    HttpSuccessCallback? success,
    HttpFailureCallback? failure,
  }) async {

    ///0代表不设置超时
    int receiveTimeout = 0;
    var options = _options??Options(
      receiveTimeout: receiveTimeout
    );

    String url = _path.toString();
    if (getEnableRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = _httpType.name;
      if(_headers.isNotEmpty){
        options.headers = _headers;
      }
      Response<dynamic> response = await _rxNet.client!.download(
          url,
          savePath,
          onReceiveProgress: onReceiveProgress,
          queryParameters: getEnableRestfulUrl()?{}:_params,
          data: _bodyData,
          options: options,
          cancelToken: _cancelTokens[getTag() ]);
      ///成功
      if(response.statusCode==200){
        if (success != null) {
          success(response.data,SourcesType.net);
        }
      }else{
        failure?.call(HttpError(HttpError.REQUEST_FAILE, "请求失败",response.data));
      }
    } on DioError catch (e, s) {
      LogUtil.v("请求出错：$e\n$s");
      if (failure != null && e.type != DioErrorType.cancel) {
        failure(HttpError.dioError(e));
      }
    } catch (e, s) {
      LogUtil.v("未知异常出错：$e\n$s");
      if (failure != null) {
        failure(HttpError(HttpError.UNKNOWN, "网络异常，请稍后重试！",e));
      }
    }
  }

}
