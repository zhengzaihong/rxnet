import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2022/8/9
/// create_time: 18:03
/// describe: 网络请求工具库，支持多种缓存模式（缓存策略目前只支持 android HarmonyOS 和 IOS MACOS平台）
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

  Map<String, dynamic> globalHeader ={};

  /// 创建 dio 实例对象
  RxNet._internal() {
    var options = BaseOptions(
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
    CheckNetWork? baseCheckNet,
    RequestCaptureError? requestCaptureError,
    CacheMode? baseCacheMode,
  }) {

    LogUtil.init(isDebug: isDebug);

    this.baseCheckNet = baseCheckNet;
    this.baseCacheMode = baseCacheMode;
    this.requestCaptureError = requestCaptureError;


    if (options != null) {
      _client?.options = options;
    }
    _client?.options.baseUrl = baseUrl;
    if (interceptors != null) {
      _client?.interceptors.addAll(interceptors);
    }
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        DatabaseUtil.initDatabase(dbName,tabName: tableName);
      }
    } catch (e) {
      LogUtil.v("数据缓存不支持的环境：web, windows");
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
  void setProxy(String address){
    if(isEnableProxy()){
      (_instance.client?.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate = (client) {
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
  void cacheLogToFile(String filePath) async{
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
  void cancel(String tag,{dynamic reason}) {
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

  JsonConvertAdapter<T>? _jsonConvertAdapter;

  Options? _options;

  bool _enableRestfulUrl = false;

  CheckNetWork? checkNetWork;

  BuildRequest(this._httpType, this._rxNet){
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

  BuildRequest setJsonConvert(Function(dynamic data) function) {
    setJsonConvertAdapter(JsonConvertAdapter((data) => function.call(data)));
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

  ///用于有些特殊的请求，无具体key等
  BuildRequest setFormParams(dynamic param) {
    _bodyData = param;
    return this;
  }

  BuildRequest setParam(String key, dynamic value) {
    if (_httpType == HttpType.get) {
      _params[key] = value;
    }else{
      _bodyData[key] = value;
    }
    return this;
  }


  BuildRequest setParams(Map<String, dynamic> params) {
    if (_httpType == HttpType.get) {
      _params = params;
    }else{
      _bodyData = params;
    }
    return this;
  }

  BuildRequest addParams(Map<String, dynamic> params) {
    if (_httpType == HttpType.get) {
      _params.addAll(params);
    }else{
      _bodyData ??= {};
      if(_bodyData is Map){
        _bodyData.addAll(params);
      }
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

  BuildRequest enableGlobalHeader(bool enable) {
    _enableGlobalHeader = enable;
    return this;
  }


  BuildRequest setCacheMode(CacheMode cacheMode) {
    _cacheMode = cacheMode;
    return this;
  }

  BuildRequest setOptionConfig(OptionConfig callBack) {
    callBack.call(_options!);
    return this;
  }

  ///提供一个检查网络的方法，外部需要自行实现
  BuildRequest setCheckNetwork(CheckNetWork checkNetWork){
    this.checkNetWork = checkNetWork;
    return this;
  }


  void _doWorkRequest({
    SuccessCallback? success,
    FailureCallback? failure,
    bool cache = false,
    Function? readCache,
  }) async {

    String url = _path.toString();
    if (getEnableRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = _httpType.name;

      ///局部头优先与全局
      if(_headers.isNotEmpty){
        _options?.headers = _headers;
      }
      if(_enableGlobalHeader){
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.globalHeader);
      }

      Response<T> response = await _rxNet.client!.request(
          url,
          data: _bodyData,
          queryParameters: getEnableRestfulUrl()?{}:_params,
          options: _options,
          cancelToken: _cancelTokens[getTag()]);

      ///成功
      if (response.statusCode == 200) {
        if (getJsonConvertAdapter() != null) {
          LogUtil.v("useJsonAdapter：true");
          var data = getJsonConvertAdapter()?.jsonTransformation.call(response.data);
          success?.call(data!, SourcesType.net);
        } else {
          LogUtil.v("useJsonAdapter：false");
          success?.call(response.data, SourcesType.net);
        }

        try {
          if (cache && (Platform.isIOS || Platform.isAndroid)) {
            String cacheKey = NetUtils.getCacheKeyFromPath("$_path", _params);
            /// 存储数据
            NetUtils.saveCache(cacheKey, response.data==null?"":jsonEncode(response.data));
          }
        } catch (e) {
          LogUtil.v("catch环境：web,windows");
        }
        return;
      }

      if (readCache != null) {
        readCache.call();
      } else {
        ///失败
        failure?.call(HttpError(HttpError.REQUEST_FAILE, "请求失败",response.data));
      }

    } on DioError catch (e, s) {
      LogUtil.v("网络请求出错,请检查网络：$e\n$s");
      _collectError(e);
      var error = HttpError.dioError(e);
      if (failure != null && e.type != DioErrorType.cancel) {
        error.bodyData = e;
      }
      if (readCache != null) {
        LogUtil.v("网络请求失败，开始读取缓存：");
        readCache.call();
      } else {
        ///失败
        failure?.call(HttpError(HttpError.REQUEST_FAILE, "请求失败",error));
      }
    } catch (e, s) {
      LogUtil.v("未知异常出错：$e\n$s");
      _collectError(e);
      if (readCache != null) {
        LogUtil.v("网络请求失败，开始读取缓存：");
        readCache.call();
      } else {
        ///失败
        failure?.call(HttpError(HttpError.UNKNOWN, "未知异常出错",e));
      }
    }
  }


  void _readCache(
      SuccessCallback? success,
      FailureCallback? failure,
      ){
    if(DatabaseUtil.isDatabaseReady){
      _readCacheAction(success,failure);
    }else{
      DatabaseUtil.setDataBaseReadListener((isOk){
        _readCacheAction(success,failure);
      });
    }
  }

  void _readCacheAction(
      SuccessCallback? success,
      FailureCallback? failure,
      ){

      NetUtils.getCache("$_path", _params).then((list) {
        if (list.isNotEmpty) {
          LogUtil.v("缓存数据:$list");
          _parseLocalData(success,failure,list);
        } else {
          failure?.call({});
        }
      });
  }

  ///解析本地缓存数据
  void _parseLocalData(
      SuccessCallback? success,
      FailureCallback? failure,
      List<Map<String,dynamic>> list,
      ){
    var datas = list[0]["value"];
    if (getJsonConvertAdapter() != null) {
      LogUtil.v("useJsonAdapter：true");
      var data = getJsonConvertAdapter()?.jsonTransformation.call(jsonDecode(datas));
      success?.call(data, SourcesType.cache);
    } else {
      LogUtil.v("useJsonAdapter：false");
      success?.call(datas, SourcesType.cache);
    }
  }


  Future<bool> _checkNetWork() async{

    ///如果设置了网络检查 请返回是否启用请求的状态。
    if(checkNetWork!=null){
      ///如果网络检查失败 或者 false 将不会执行请求。
      return await checkNetWork!.call();
    }

    ///局部网络检查优先级高于全局
    if(checkNetWork==null && _rxNet.baseCheckNet!=null){
    ///如果网络检查失败 或者 false 将不会执行请求。
      return await _rxNet.baseCheckNet!.call();
    }
    return true;
  }
  void execute({SuccessCallback? success, FailureCallback? failure}) async{

    if(!(await _checkNetWork())){
      return ;
    }
    _cacheMode = _cacheMode??(_rxNet.baseCacheMode??CacheMode.onlyRequest);
    if(_cacheMode == CacheMode.onlyRequest){
      _doWorkRequest(success: success, failure: failure);
      return;
    }

    if(_cacheMode == CacheMode.firstCacheThenRequest){
      _readCache(success,failure);
      _doWorkRequest(success: success, failure: failure, cache: true);
      return;
    }

    if(_cacheMode == CacheMode.requestFailedReadCache){
      _doWorkRequest(success: success, failure: failure, cache: true,
          readCache: () {
            _readCache(success,failure);
          });
      return;
    }
    if(_cacheMode == CacheMode.onlyCache){
      _readCache(success,failure);
      return;
    }
  }


  ///上传文件
  void upload({
    ProgressCallback? onSendProgress,
    SuccessCallback? success,
    FailureCallback? failure,
  }) async {

    if(!(await _checkNetWork())){
      return ;
    }

    String url = _path.toString();
    if (getEnableRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = _httpType.name;
      ///局部头优先与全局
      if(_headers.isNotEmpty){
        _options?.headers = _headers;
      }
      if(_enableGlobalHeader){
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.globalHeader);
      }


      Response<T> response = await _rxNet.client!.request(
          url,
          onSendProgress: onSendProgress,
          data: _bodyData,
          queryParameters: getEnableRestfulUrl()?{}:_params,
          options: _options,
          cancelToken: _cancelTokens[getTag()]);

      if(response.statusCode == 200){
        success?.call(response.data, SourcesType.net);
        return;
      }

      failure?.call(HttpError(HttpError.REQUEST_FAILE, "请求失败",response.data));
    } on DioError catch (e, s) {
      _collectError(e);
      LogUtil.v("请求出错：$e\n$s");
      if (e.type != DioErrorType.cancel) {
        var error = HttpError.dioError(e);
        error.bodyData = e;
        failure?.call(error);
      }
    } catch (e, s) {
      _collectError(e);
      LogUtil.v("未知异常出错：$e\n$s");
      failure?.call( HttpError(HttpError.UNKNOWN, "网络异常，请稍后重试！",e));
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

    if(!(await _checkNetWork())){
      return ;
    }
    String url = _path.toString();
    if (getEnableRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = _httpType.name;

      ///局部头优先与全局
      if(_headers.isNotEmpty){
        _options?.headers = _headers;
      }
      if(_enableGlobalHeader){
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.globalHeader);
      }

      Response<dynamic> response = await _rxNet.client!.download(
          url,
          savePath,
          onReceiveProgress: onReceiveProgress,
          queryParameters: getEnableRestfulUrl()?{}:_params,
          data: _bodyData,
          options: _options,
          cancelToken: _cancelTokens[getTag()]);
      ///成功
      if(response.statusCode==200){
        success?.call(response.data, SourcesType.net);
        return;
      }
      failure?.call(HttpError(HttpError.REQUEST_FAILE, "请求失败",response.data));
    } on DioError catch (e, s) {
      LogUtil.v("请求出错：$e\n$s");
      if (e.type != DioErrorType.cancel) {
        failure?.call(HttpError.dioError(e));
      }
      _collectError(e);
    } catch (e, s) {
      LogUtil.v("未知异常出错：$e\n$s");
      _collectError(e);
      failure?.call( HttpError(HttpError.UNKNOWN, "网络异常，请稍后重试！",e));
    }
  }

  void _collectError(dynamic e){
    if(_rxNet.requestCaptureError!=null){
      _rxNet.requestCaptureError!.call(e);
    }
  }
}
