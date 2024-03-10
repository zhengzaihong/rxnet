import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rxnet_forzzh/net/rx_result.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';
import 'package:hive/hive.dart';
import '../utils/RxNetDataBase.dart';


///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2022/8/9
/// create_time: 18:03
/// describe: 网络请求工具库，支持多种缓存模式
///同一个CancelToken可以用于多个请求，当一个CancelToken取消时，所有使用该CancelToken的请求都会被取消。
final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};

class RxNet {
  Dio? _client;

  static final RxNet _instance = RxNet._internal();

  /// 是否使用代理
  bool _isProxyEnable = false;

  factory RxNet() => _instance;

  Dio? get client => _client;

  CheckNetWork? baseCheckNet;

  RequestCaptureError? requestCaptureError;

  CacheMode? baseCacheMode;

  Map<String, dynamic> globalHeader = {};

  RxNetDataBase? _dataBase;

  /// 创建 dio 实例对象
  RxNet._internal() {
    var options = BaseOptions(
        contentType: Headers.jsonContentType, responseType: ResponseType.json);
    _client ??= Dio(options);
  }

  ///初始化公共属性
  /// [baseUrl] 地址前缀
  /// [interceptors] 基础拦截器
  Future<void> init({
    required String baseUrl,
    Directory? cacheDir,
    String cacheName = 'app_local_data',
    List<Interceptor>? interceptors,
    BaseOptions? baseOptions,
    bool isDebug = false,
    bool useSystemPrint = false,
    String? printTag,
    CheckNetWork? baseCheckNet,
    RequestCaptureError? requestCaptureError,
    CacheMode? baseCacheMode,
    HiveCipher? encryptionCipher,
  }) async{

    WidgetsFlutterBinding.ensureInitialized();
    LogUtil.init(isDebug: isDebug, tag: printTag, useSystemPrint: useSystemPrint);

    this.baseCheckNet = baseCheckNet;
    this.baseCacheMode = baseCacheMode;
    this.requestCaptureError = requestCaptureError;


    if (baseOptions != null) {
      _client?.options = baseOptions;
    }
    /// 已最初baseUrl 为准
    _client?.options.baseUrl = baseUrl;
    if (interceptors != null) {
      _client?.interceptors.addAll(interceptors);
    }


    if(PlatformTools.isWeb){
      LogUtil.v("RxNet 不支持缓存的环境：web");
      return;
    }
    _dataBase = RxNetDataBase();
    await RxNetDataBase.initDatabase(
        directory: cacheDir,
        hiveBoxName: cacheName,
        encryptionCipher: encryptionCipher);
  }


  Dio? getClient()=>_client;

  Future saveCache(String key, dynamic value) async {
    return getDb()?.put(key,value);
  }

  Future readCache(String key) async {
    return getDb()?.get(key);
  }

  RxNetDataBase? getDb(){
    return _dataBase;
  }

  RxNet setEnableProxy(bool enable) {
    _isProxyEnable = enable;
    return this;
  }

  bool isEnableProxy() {
    return _isProxyEnable;
  }

  /// isProxyEnable 为true 才会生效
  /// 前置方法 setEnableProxy
  void setProxy(String address) {
    if (isEnableProxy()) {
      (_instance.client?.httpClientAdapter as DefaultHttpClientAdapter)
          .onHttpClientCreate = (client) {
        client.findProxy = (uri) {
          ///ip:prort
          return address;
        };
        client.badCertificateCallback = (X509Certificate cert, String host, int port) => true;
        return null;
      };
    }
  }

  ///这里提供一个收集日字的方法，便于后期排查
  ///文件需要有写的权限，eg:xxx/xxx/log.txt
  void cacheLogToFile(String filePath) async {
    var file = File(filePath);
    var sink = file.openWrite();
    _client?.interceptors.add(LogInterceptor(logPrint: sink.writeln));
    await sink.close();
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

  ///设置全局请求头
  void setGlobalHeader(Map<String, dynamic> header) {
    globalHeader = header;
  }

  Map<String, dynamic> getGlobalHeader() {
    return globalHeader;
  }

  ///取消网络请求
  void cancel(String tag, {dynamic reason}) {
    if (_cancelTokens.containsKey(tag)) {
      if (!_cancelTokens[tag]!.isCancelled) {
        _cancelTokens[tag]?.cancel(reason);
      }
      _cancelTokens.remove(tag);
    }
  }
}

class BuildRequest<T> {
  final HttpType _httpType;

  final RxNet _rxNet;

  String? _cancelTag;

  String? _path;

  CacheMode? _cacheMode;

  Map<String, dynamic> _params = {};

  Map<String, dynamic> _headers = {};

  bool _enableGlobalHeader = true;

  dynamic _bodyData;

  JsonConvertAdapter? _jsonConvertAdapter;

  Options? _options;

  bool _enableRestfulUrl = false;

  CheckNetWork? checkNetWork;

  BuildRequest(this._httpType, this._rxNet) {
    BaseOptions? op = _rxNet._client?.options;
    _options = Options(
      method: op?.method,
      sendTimeout: op?.sendTimeout,
      receiveTimeout: op?.receiveTimeout,
      extra: op?.extra,
      headers: op?.headers,
      responseType: op?.responseType,
      contentType: op?.contentType,
      validateStatus: op?.validateStatus,
      receiveDataWhenStatusError: op?.receiveDataWhenStatusError,
      followRedirects: op?.followRedirects,
      maxRedirects: op?.maxRedirects,
      requestEncoder: op?.requestEncoder,
      responseDecoder: op?.responseDecoder,
      listFormat: op?.listFormat,
    );
  }

  BuildRequest setJsonConvert(JsonTransformation jsonTransformation) {
    setJsonConvertAdapter(JsonConvertAdapter(jsonTransformation));
    return this;
  }

  BuildRequest setJsonConvertAdapter(JsonConvertAdapter adapter) {
    _jsonConvertAdapter = adapter;
    return this;
  }

  JsonConvertAdapter? getJsonConvertAdapter() {
    return _jsonConvertAdapter;
  }

  /// 处理 RestfulUrl格式请求
  /// 如：xxxx/xxx/weather?city=101030100
  /// 结果：xxxx/xxx/weather/city/101030100
  BuildRequest setRestfulUrl(bool restful) {
    _enableRestfulUrl = restful;
    return this;
  }

  bool isRestfulUrl() {
    return _enableRestfulUrl;
  }

  BuildRequest setPath(String path) {
    if (TextUtil.isEmpty(path)) {
      throw Exception("请求路径不能为空 path:$_path");
    }
    _path = path;
    return this;
  }

  ///用于有些特殊的请求，无具体key等
  BuildRequest setFormParams(dynamic param) {
    _bodyData = param;
    return this;
  }

  BuildRequest setParam(String key, dynamic value) {
    if (_httpType == HttpType.post) {
      _bodyData ??= {};
      _bodyData[key] = value;
    } else {
      _params[key] = value;
    }
    return this;
  }

  BuildRequest setParams(Map<String, dynamic> params) {
    if (_httpType == HttpType.post) {
      _bodyData = params;
    } else {
      _params = params;
    }
    return this;
  }

  BuildRequest addParams(Map<String, dynamic> params) {
    if(_httpType == HttpType.post) {
      _bodyData ??= {};
      if (_bodyData is Map) {
        _bodyData.addAll(params);
      }
    }else{
      _params.addAll(params);
    }
    return this;
  }

  BuildRequest getParams(ParamCallBack callBack) {
    callBack.call(_params);
    return this;
  }

  BuildRequest addHeaders(Map<String, dynamic> headers) {
    _headers = headers;
    return this;
  }

  BuildRequest setHeader(String key, dynamic value) {
    _headers[key] = value;
    return this;
  }

  BuildRequest setTag(String tag) {
    _cancelTag = tag;
    _cancelTokens[tag] = CancelToken();
    return this;
  }

  String? getTag() {
    return _cancelTag;
  }

  BuildRequest setEnableGlobalHeader(bool enable) {
    _enableGlobalHeader = enable;
    return this;
  }

  BuildRequest setCacheMode(CacheMode cacheMode) {
    _cacheMode = cacheMode;
    return this;
  }

  ///提供一个设置配置的方法，遇到需要额外处理的时候配置
  BuildRequest setOptionConfig(OptionConfig callBack) {
    callBack.call(_options!);
    return this;
  }

  ///提供一个检查网络的方法，外部需要自行实现
  BuildRequest setCheckNetwork(CheckNetWork checkNetWork) {
    this.checkNetWork = checkNetWork;
    return this;
  }

  void _doWorkRequest<T>({
    SuccessCallback<T>? success,
    FailureCallback<T>? failure,
    bool cache = false,
    Function? readCache,
  }) async {
    String url = _path.toString();
    if (isRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = _httpType.name;

      ///局部头优先与全局
      if (_headers.isNotEmpty) {
        _options?.headers = _headers;
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.globalHeader);
      }

      Response response = await _rxNet.client!.request(url,
          data: _bodyData,
          queryParameters: isRestfulUrl() ? {} : _params,
          options: _options,
          cancelToken: _cancelTokens[getTag()]);

      ///成功
      if (response.statusCode == 200) {
        if (getJsonConvertAdapter() != null) {
          LogUtil.v("useJsonAdapter：true");
          var data =
          getJsonConvertAdapter()?.jsonTransformation.call(response.data);
          success?.call(data as T, SourcesType.net);
        } else {
          LogUtil.v("useJsonAdapter：false");
          success?.call(response.data as T, SourcesType.net);
        }

        /// 存储数据
        if(cache && !PlatformTools.isWeb){
          String cacheKey = NetUtils.getCacheKeyFromPath("$_path", _params);
          _rxNet.saveCache(cacheKey, jsonEncode(response.data));
        }
        return;
      }

      ///失败
      failure?.call(response.data);
    } catch (e, s) {
      _catchError(success, failure, readCache, e, s);
    }
  }


  void _readCache<T>(
      SuccessCallback<T>? success,
      FailureCallback<T>? failure,
      ) async {
    if(PlatformTools.isWeb){
      return;
    }

    if(RxNetDataBase.isDatabaseReady){
      var value =
      await _rxNet.readCache(NetUtils.getCacheKeyFromPath('$_path', _params));
      if (value != null) {
        _parseLocalData<T>(success, failure, value);
      } else {
        failure?.call({});
      }
      LogUtil.v("缓存数据:$value");
      return;
    }

    RxNetDataBase.setDataBaseReadListener((isOk){
      _readCache(success,failure);
    });
  }

  ///解析本地缓存数据
  void _parseLocalData<T>(
      SuccessCallback<T>? success,
      FailureCallback<T>? failure,
      dynamic cacheValue,
      ) {
    if (getJsonConvertAdapter() != null) {
      LogUtil.v("useJsonAdapter：true");
      var data = getJsonConvertAdapter()
          ?.jsonTransformation
          .call(jsonDecode(cacheValue));
      success?.call(data, SourcesType.cache);
    } else {
      LogUtil.v("useJsonAdapter：false");
      success?.call(cacheValue, SourcesType.cache);
    }
  }

  Future<bool> _checkNetWork() async {
    ///如果设置了网络检查 请返回是否启用请求的状态。
    if (checkNetWork != null) {
      ///如果网络检查失败 或者 false 将不会执行请求。
      return await checkNetWork!.call();
    }

    ///局部网络检查优先级高于全局
    if (checkNetWork == null && _rxNet.baseCheckNet != null) {
      ///如果网络检查失败 或者 false 将不会执行请求。
      return await _rxNet.baseCheckNet!.call();
    }
    return true;
  }

  ///基于异步回调方式 支持同时请求和缓存策略
  ///对于外部需要可接收多种状态的数据 建议使用此方式。
  void execute<T>({SuccessCallback<T>? success, FailureCallback? failure}) async {
    if (!(await _checkNetWork())) {
      return;
    }
    _cacheMode = _cacheMode ?? (_rxNet.baseCacheMode ?? CacheMode.onlyRequest);
    if (_cacheMode == CacheMode.onlyRequest) {
      return  _doWorkRequest(success: success, failure: failure);
    }

    if (_cacheMode == CacheMode.firstCacheThenRequest) {
      _readCache(success, failure);
      return _doWorkRequest(success: success, failure: failure, cache: true);
    }

    if (_cacheMode == CacheMode.requestFailedReadCache) {
      return  _doWorkRequest(
          success: success,
          failure: failure,
          cache: true,
          readCache: () {
            _readCache(success, failure);
          });
    }
    if (_cacheMode == CacheMode.onlyCache) {
      return _readCache(success, failure);
    }
  }

  /// 外部使用 await 方式调用此方法。
  /// 结果从 RxResult 中获取
  /// 此方式不支持 同时请求和读取缓存策略。
  Future<RxResult<T>> executeAsync<T>() async  {
    Completer<RxResult<T>> completer = Completer();
    if (!(await _checkNetWork())) {
      return completer.future;
    }
    _cacheMode = _cacheMode ?? (_rxNet.baseCacheMode ?? CacheMode.onlyRequest);
    if(_cacheMode == CacheMode.requestFailedReadCache){
      _cacheMode = CacheMode.onlyRequest;
    }
    if(_cacheMode == CacheMode.firstCacheThenRequest){
      _cacheMode = CacheMode.onlyCache;
    }
    if (_cacheMode == CacheMode.onlyRequest) {
      _doWorkRequest<T>(success: (data,model){
        _successHandler<T>(completer, data: data, model: model);
      }, failure: (e){
        _errorHandler<T>(completer,model:SourcesType.net, error: e);
      });
    }

    if (_cacheMode == CacheMode.onlyCache) {
      _readCache<T>((data, model){
        _successHandler<T>(completer, data: data, model: model);
      }, (e){
        _errorHandler<T>(completer,model:SourcesType.cache, error: e);
      });
    }
    return completer.future;
  }

  void _errorHandler<T>(Completer<RxResult<T>> completer,
      {SourcesType model = SourcesType.net,
        dynamic error,
        bool isError = true}) {
    completer.complete(RxResult(error: error, isError: isError));
  }

  void _successHandler<T>(Completer<RxResult<T>> completer,
      {T? data,
        SourcesType model = SourcesType.net,
        dynamic error,
        bool isError = false}) {
    completer.complete(RxResult<T>(
        value: data, model: model, error: error, isError: isError));
  }

  ///上传文件
  void upload({
    ProgressCallback? onSendProgress,
    SuccessCallback? success,
    FailureCallback? failure,
  }) async {
    if (!(await _checkNetWork())) {
      return;
    }

    String url = _path.toString();
    if (isRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = _httpType.name;

      ///局部头优先与全局
      if (_headers.isNotEmpty) {
        _options?.headers = _headers;
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.globalHeader);
      }

      Response<T> response = await _rxNet.client!.request(url,
          onSendProgress: onSendProgress,
          data: _bodyData,
          queryParameters: isRestfulUrl() ? {} : _params,
          options: _options,
          cancelToken: _cancelTokens[getTag()]);

      if (response.statusCode == 200) {
        success?.call(response.data, SourcesType.net);
        return;
      }

      failure?.call(response.data);
    } catch (e, s) {
      _catchError(success, failure, null, e, s);
    }
  }



  ///下载文件
  ///[savePath]  文件保存路径
  void download({
    required String savePath,
    ProgressCallback? onReceiveProgress,
    SuccessCallback? success,
    FailureCallback? failure,
  }) async {
    if (!(await _checkNetWork())) {
      return;
    }
    String url = _path.toString();
    if (isRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = _httpType.name;

      ///局部头优先与全局
      if (_headers.isNotEmpty) {
        _options?.headers = _headers;
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.globalHeader);
      }

      Response<dynamic> response = await _rxNet.client!.download(url, savePath,
          onReceiveProgress: onReceiveProgress,
          queryParameters: isRestfulUrl() ? {} : _params,
          data: _bodyData,
          options: _options,
          cancelToken: _cancelTokens[getTag()]);

      ///成功
      if (response.statusCode == 200) {
        success?.call(response.data, SourcesType.net);
        return;
      }
      failure?.call(response.data);
    } catch (e, s) {
      _catchError<T>(success, failure, null, e, s);
    }
  }

  void _catchError<T>(SuccessCallback<T>? success, FailureCallback<T>? failure,
      Function? readCache, e, s) {
    _collectError(e);
    LogUtil.v("请求出错：$e\n$s");
    if (readCache != null) {
      LogUtil.v("网络请求失败，开始读取缓存：");
      readCache.call();
    } else {
      ///失败
      failure?.call(e);
    }
  }

  void _collectError(dynamic e) {
    _rxNet.requestCaptureError?.call(e);
  }
}
