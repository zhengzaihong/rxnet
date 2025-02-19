import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
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

class RxNet {

  Dio? _client;

  ///最大重试次数
  static int maxRetryCount = 100000;
  static final RxNet _instance = RxNet._internal();

  factory RxNet() => _instance;
  Dio? get client => _client;

  CheckNetWork? _baseCheckNet;

  ///请求拦截,可以拦截错误信息,也可以在你外部自定义拦截器中实现
  RequestCaptureError? _requestCaptureError;

  ///缓存模式
  CacheMode? _baseCacheMode;

  ///初始化默认 缓存失效时间（毫秒） 一年
  int _cacheInvalidationTime = 0;

  ///全局请求头
  Map<String, dynamic> _globalHeader = {};

  ///忽略缓存的校验的key
  List<String>? _baseIgnoreCacheKeys;

  ///本地缓存数据库
  RxNetDataBase? _dataBase;

  ///是否开启日志收集
  bool _isCollectLogs = false;

  ///调试窗口大小
  late ValueNotifier<Size> debugWindowSizeNotifier;

  ///收集的日志信息，用于界面呈现
  ValueNotifier<List<String>> logsNotifier = ValueNotifier([]);

  /// 支持多环境 baseUrl调试 ,
  /// 例如：
  /// test: http://192.168.1.100:8080/
  /// debug: http://192.168.1.100:8080/
  /// release: http://192.168.1.100:8080/
  /// 则 baseUrlEnv = {"test":"http://192.168.1.100:8080/","debug":"http://192.168.1.100:8080/","release":"http://192.168.1.100:8080/"}
  Map<String, dynamic> _baseUrlEnv = {};

  /// 创建 dio 实例对象
  RxNet._internal() {
    final options = BaseOptions(
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json);
    _client ??= Dio(options);
  }

  ///初始化公共属性
  /// [baseUrl] 地址前缀
  /// [interceptors] 基础拦截器
  ///
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
    List<String>? ignoreCacheKeys,
    RequestCaptureError? requestCaptureError,
    CacheMode? baseCacheMode,
    HiveCipher? encryptionCipher,
    Map<String, dynamic>? baseUrlEnv,
    int cacheInvalidationTime = 365 * 24 * 60 * 60 * 1000,
    double debugWindowWidth = 600,
    double debugWindowHeight = 500
  }) async{

    WidgetsFlutterBinding.ensureInitialized();
    LogUtil.init(isDebug: isDebug, tag: printTag, useSystemPrint: useSystemPrint);

    this._baseCheckNet = baseCheckNet;
    this._baseCacheMode = baseCacheMode;
    this._requestCaptureError = requestCaptureError;
    this._cacheInvalidationTime = cacheInvalidationTime;
    this._baseIgnoreCacheKeys = ignoreCacheKeys;

    if (baseOptions != null) {
      _client?.options = baseOptions;
    }
    /// 以最初 baseUrl 为准
    _client?.options.baseUrl = baseUrl;
    if (interceptors != null) {
      _client?.interceptors.addAll(interceptors);
    }
    if(baseUrlEnv!= null && baseUrlEnv.isNotEmpty){
      _baseUrlEnv.addAll(baseUrlEnv);
    }
    if(RxNetPlatform.isWeb){
      this._baseCacheMode = CacheMode.onlyRequest;
      LogUtil.v("RxNet 不支持缓存的环境：web");
      return;
    }
    _dataBase = RxNetDataBase();
    await RxNetDataBase.initDatabase(
        directory: cacheDir,
        hiveBoxName: cacheName,
        encryptionCipher: encryptionCipher);

    debugWindowSizeNotifier = ValueNotifier(Size(debugWindowWidth, debugWindowHeight));
  }


  Dio? getClient()=>_client;


  /// 切换环境
  /// [env] 环境名称 key
  /// 例如：debug,test,release
  void setEnv(String env){
    _client?.options.baseUrl = _baseUrlEnv[env];
  }


  /// 缓存
  /// [key] 缓存key
  /// [value] 缓存值
  Future saveCache(String key, dynamic value) async {
    return getDb()?.put(key,value);
  }

  /// 读取缓存
  /// [key] 缓存key
  Future readCache(String key) async {
    return getDb()?.get(key);
  }

  RxNetDataBase? getDb(){
    return _dataBase;
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
    ).setParamsToBodyData(true);
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
  void setHeaders(Map<String, dynamic> header) {
    _globalHeader = header;
  }

  Map<String, dynamic> getHeaders() {
    return _globalHeader;
  }


  bool get collectLogs => _isCollectLogs;
  void setCollectLogs(bool collect) {
    _isCollectLogs = collect;
  }


  void addLogs(String log) {
    if (collectLogs) {
      logsNotifier.value.add(log);
      logsNotifier.notifyListeners();
    }
  }
  void clearLogs() {
    logsNotifier.value = [];
    logsNotifier.notifyListeners();
  }


  OverlayEntry? _overlayEntry;
  void showDebugWindow(BuildContext context) {
    LogUtil.debug = true;
    _isCollectLogs = true;
    closeDebugWindow();
    OverlayState? overlayState = Overlay.of(context);
    Size size = MediaQuery.of(context).size;
    _overlayEntry = OverlayEntry(
      builder: (context) => SizedBox(
        width: size.width,
        height: size.height,
        child: Center(
          child: DragBox(child: ValueListenableBuilder<Size>(
            valueListenable: debugWindowSizeNotifier,
            builder: (context, value, child) {
              return SizedBox(
                width: value.width,
                height: value.height,
                child: const DebugPage(),
              );
            }
          )),
        ),
      ),
    );
    overlayState?.insert(_overlayEntry!);
  }

  //关闭调试窗口
  void closeDebugWindow() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}

class BuildRequest<T> {

  final HttpType _httpType;

  final RxNet _rxNet;

  CancelToken? _cancelToken;

  String? _path;

  CacheMode? _cacheMode;

  Map<String, dynamic> _params = {};

  ///忽略缓存的的校验参数 - 本地缓存不会校验
  List<String> _ignoreCacheKeys = [];

  Map<String, dynamic> _headers = {};

  bool _enableGlobalHeader = true;

  dynamic _bodyData;

  ///是否将参数转换为 FormData body 参数 请求
  bool _toFormData = false;

  ///是否将参数转换为  body 参数请求
  bool _toBodyData = false;

  JsonTransformation? _jsonTransformation;

  Options? _options;


  ///默认一年
  int? _cacheInvalidationTime;

  /// 当前请求是否取消缓存超时校验，即缓存时效未过期也触发网络请求
  bool _requestIgnoreCacheTime = false;

  ///重试次数
  int _retryCount = 0;

  ///请求间隔 默认1秒
  int _retryInterval = 1000;

  ///是否开启循环请求
  bool _isLoop = false;

  ///是否在失败时重试
  bool _failRetry = true;

  bool _enableRestfulUrl = false;

  CheckNetWork? checkNetWork;

  Function(Response response)? onResponse;

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

  BuildRequest setJsonConvert(JsonTransformation convert) {
    _jsonTransformation = convert;
    return this;
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


  BuildRequest setParam(String key, dynamic value) {
    _params[key] = value;
    return this;
  }

  BuildRequest setParams(Map<String, dynamic> params) {
    _params = params;
    return this;
  }

  BuildRequest addParams(Map<String, dynamic> params) {
    _params.addAll(params);
    return this;
  }

  BuildRequest setParamsToFormData(bool toFormData) {
    _toFormData = toFormData;
    _toBodyData = false;
    return this;
  }
  BuildRequest setParamsToBodyData(bool toBody) {
    _toBodyData = toBody;
    _toFormData = false;
    return this;
  }


  ///用于表单( FormData )。默认 raw json, 其它方式 setOptionConfig自行处理
  // eg:
  //     Map<String, dynamic> formData = {
  //       "file": MultipartFile.fromBytes(
  //         imageFileBytes,
  //         filename: "xxx.png",
  //         contentType: MediaType,
  //       ),
  //     };

  // ...
  // .setParams(formData)
  // .toFormData();

  BuildRequest toFormData() {
    setParamsToFormData(true);
    return this;
  }
  BuildRequest toBodyData() {
    setParamsToBodyData(true);
    return this;
  }

  ///用于表单( FormData )。 默认 raw json， 其它方式 setOptionConfig自行处理
  BuildRequest toUrlEncoded() {
    setParamsToFormData(true);
    _options?.contentType = Headers.formUrlEncodedContentType;
    return this;
  }

  BuildRequest removeNullValueKeys() {
    _params.removeWhere((key, value) =>  value == null);
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

  BuildRequest setCancelToken(CancelToken cancelToken) {
    _cancelToken= cancelToken;
    return this;
  }

  BuildRequest setEnableGlobalHeader(bool enable) {
    _enableGlobalHeader = enable;
    return this;
  }

  BuildRequest setCacheMode(CacheMode cacheMode) {
    _cacheMode = cacheMode;
    if(RxNetPlatform.isWeb){
      _cacheMode = CacheMode.onlyRequest;
    }
    return this;
  }

  ///开启则忽略缓存校验，直接请求
  ///通常用于 CacheMode.cacheNoneToRequest 在有下拉刷新等操作模式下
  BuildRequest setRequestIgnoreCacheTime(bool ignoreCache) {
    _requestIgnoreCacheTime = ignoreCache;
    return this;
  }

  BuildRequest setIgnoreCacheKeys(List<String> keys) {
    _ignoreCacheKeys.addAll(keys);
    return this;
  }

  BuildRequest setIgnoreCacheKey(String key) {
    _ignoreCacheKeys.add(key);
    return this;
  }

  BuildRequest setLoop(bool loop) {
    _isLoop = loop;
    return this;
  }


  ///设置重试次数
  BuildRequest setRetryCount(int count) {
    _retryCount = count;
    return this;
  }

  ///设置重试间隔 -- 毫秒
  BuildRequest setRetryInterval(int interval) {
    _retryInterval = interval;
    return this;
  }

  ///首次请求失败是否重试
  /// onlyRequest 模式
  BuildRequest setFailRetry(bool status) {
    _failRetry = status;
    return this;
  }


  ///设置缓存失效时间（毫秒）
  BuildRequest setCacheInvalidationTime(int millisecond) {
    _cacheInvalidationTime = millisecond;
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

  CancelToken? getCancelToken() {
    return _cancelToken;
  }

  /// 响应结果 一般情况不会使用
  BuildRequest setResponseCallBack(Function(Response response) responseCallBack) {
    this.onResponse = responseCallBack;
    return this;
  }

  Future<void> _doWorkRequest<T>({
    Success<T>? success,
    Failure<T>? failure,
    Completed? completed,
    bool cache = false,
    Function? readCache,
  }) async {
    String url = _path.toString();
    if (isRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    bool isFailure = false;
    try {
      _options?.method = _httpType.name;

      ///局部头优先与全局
      if (_headers.isNotEmpty) {
        _options?.headers = _headers;
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet._globalHeader);
      }
      if(_toFormData){
        _bodyData = FormData.fromMap(_params);
      }
      if(_toBodyData){
        _bodyData = _params;
      }

      if(_jsonTransformation!=null){
        LogUtil.v("$url，JsonConvert：true");
      }else{
        LogUtil.v("$url，JsonConvert：false");
      }
      Response<dynamic> response = await _rxNet.client!.request(
          url,
          data: _bodyData,
          queryParameters: (isRestfulUrl() || _toFormData || _toBodyData)? {} : _params,
          options: _options,
          cancelToken: _cancelToken);

      onResponse?.call(response);
      var responseData = response.data;

      ///成功
      if (response.statusCode == 200) {
        if (_jsonTransformation != null) {
          try {
            //先判断是不是原始字符串格式Map数据，是则先将字符串转json格式
            if(responseData is String){
              try{
                responseData = jsonDecode(responseData);
              }catch(e){
                LogUtil.v("JsonConvert：字符串转json失败，非Map格式数据");
                return;
              }
            }
            final data = await _jsonTransformation?.call(responseData);
            success?.call(data as T, SourcesType.net);
          }catch(e){
            LogUtil.v("RxNet：请检查json数据接收类是否正确");
            return;
          } finally {
            completed?.call();
          }
        }
        else {
          success?.call(responseData, SourcesType.net);
        }
        /// 存储数据
        if(cache && !RxNetPlatform.isWeb){
          if(_rxNet._baseIgnoreCacheKeys!=null){
            _ignoreCacheKeys.addAll(_rxNet._baseIgnoreCacheKeys!);
            _ignoreCacheKeys = _ignoreCacheKeys.toSet().toList();
          }
          String cacheKey = NetUtils.getCacheKeyFromPath(_path, _params,_ignoreCacheKeys);
          final map = <String, dynamic>{
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'data':responseData
          };
          _rxNet.saveCache(cacheKey, jsonEncode(map));
        }
        return;
      }

      ///失败
      isFailure = true;
      failure?.call(responseData);
    } catch (e, s) {
      isFailure = true;
      _catchError(success, failure, readCache, e, s);
    } finally {
      completed?.call();
      if (_isLoop) {
        Future.delayed(Duration(milliseconds: _retryInterval), () {
          _doWorkRequest(
              success: success,
              failure: failure,
              completed: completed,
              cache: cache,
              readCache: readCache);
        });
      } else {
        if (_retryCount > 0 && (isFailure && _failRetry)) {
          _retryCount--;
          Future.delayed(Duration(milliseconds: _retryInterval), () {
            _doWorkRequest(
                success: success,
                failure: failure,
                completed: completed,
                cache: cache,
                readCache: readCache);
          });
        }
      }
    }
  }


  void _readCache<T>(
      Success<T>? success,
      Failure<T>? failure,
      Completed? completed,{
      CacheInvalidationCallback? cacheInvalidationCallback
  }) async {
    if(RxNetPlatform.isWeb){
      return;
    }

    if(RxNetDataBase.isDatabaseReady){
      if(_rxNet._baseIgnoreCacheKeys!=null){
        _ignoreCacheKeys.addAll(_rxNet._baseIgnoreCacheKeys!);
        _ignoreCacheKeys = _ignoreCacheKeys.toSet().toList();
      }
      final cacheData = await _rxNet.readCache(NetUtils.getCacheKeyFromPath(_path, _params,_ignoreCacheKeys));
      // LogUtil.v("缓存数据:$cacheData");
      if (!TextUtil.isEmpty(cacheData)) {
        final data = jsonDecode(cacheData);
        final timestamp = data['timestamp'];
        final dataValue = data['data'];
        LogUtil.v("-->缓存数据:${jsonEncode(data)}");
        if (timestamp != null) {
          final now = DateTime.now().millisecondsSinceEpoch;
          if (now - timestamp > (_cacheInvalidationTime??_rxNet._cacheInvalidationTime)) {
            LogUtil.v("-->缓存数据:超时效");
            cacheInvalidationCallback?.call();
            return;
          }
        }
        //解析本地缓存
        if(dataValue is Map && dataValue.length>0){
          _parseLocalData<T>(success, failure,completed, dataValue);
          return;
        }
        // 无缓存内容
        cacheInvalidationCallback?.call();
        return;
      }
      failure?.call({});
      completed?.call();
      return;
    }

    RxNetDataBase.setDataBaseReadListener((isOk){
      _readCache(success,failure,completed);
    });
  }

  ///解析本地缓存数据
  void _parseLocalData<T>(
      Success<T>? success,
      Failure<T>? failure,
      Completed? completed,
      dynamic cacheValue,
      ) {

    try {
      if (_jsonTransformation != null) {
        LogUtil.v("JsonConvert：true");
        final data = _jsonTransformation?.call(cacheValue);
        success?.call(data, SourcesType.cache);
      } else {
        LogUtil.v("JsonConvert：false");
        success?.call(cacheValue, SourcesType.cache);
      }
    } catch (e) {
      failure?.call({});
      LogUtil.v("RxNet：请检查json数据接收类是否正确");
    } finally {
      completed?.call();
    }
  }

  Future<bool> _checkNetWork() async {
    ///如果设置了网络检查 请返回是否启用请求的状态。
    if (checkNetWork != null) {
      ///如果网络检查失败 或者 false 将不会执行请求。
      return await checkNetWork!.call();
    }

    ///局部网络检查优先级高于全局
    if (checkNetWork == null && _rxNet._baseCheckNet != null) {
      ///如果网络检查失败 或者 false 将不会执行请求。
      return await _rxNet._baseCheckNet!.call();
    }
    return true;
  }

  ///基于异步回调方式 支持同时请求和缓存策略
  ///对于外部可接收多种状态的数据 建议使用此方式。
  void execute<T>({Success<T>? success, Failure? failure, Completed? completed}) async {
    if (!(await _checkNetWork())) {
      completed?.call();
      return;
    }
    _cacheMode ??= (_rxNet._baseCacheMode ?? CacheMode.onlyRequest);
    if (_cacheMode == CacheMode.onlyRequest) {
      return _doWorkRequest(
          success: success,
          failure: failure,
          completed: completed);
    }

    if (_cacheMode == CacheMode.firstCacheThenRequest) {
      return _readCache(success, failure,(){
        _doWorkRequest(
            success: success,
            failure: failure,
            completed: completed,
            cache: true);
      });
    }

    if (_cacheMode == CacheMode.requestFailedReadCache) {
      return  _doWorkRequest(
          success: success,
          failure: failure,
          completed: completed,
          cache: true,
          readCache: () {
            _readCache(success, failure,completed);
          });
    }

    if (_cacheMode == CacheMode.cacheNoneToRequest) {
      if (_requestIgnoreCacheTime) {
        return _doWorkRequest(
            success: success,
            failure: failure,
            completed: completed,
            cache: true);
      }
      return _readCache(
          success, (e) {
             // 缓存读取错误，则发起请求
            _doWorkRequest(
                success: success,
                failure: failure,
                completed: completed,
                cache: true
            );
          },
          completed,
          cacheInvalidationCallback: () {
            //无缓存，或者缓存过期，发起请求
            _doWorkRequest(
                success: success,
                failure: failure,
                completed: completed,
                cache: true
            );
          });
    }
    if (_cacheMode == CacheMode.onlyCache) {
      return _readCache(success, failure,completed);
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
    _cacheMode??=(_rxNet._baseCacheMode ?? CacheMode.onlyRequest);
    if(_cacheMode == CacheMode.requestFailedReadCache || _cacheMode == CacheMode.cacheNoneToRequest){
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
      },null);
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
    Success? success,
    Failure? failure,
    Completed? completed,
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
        _options?.headers?.addAll(_rxNet._globalHeader);
      }
      if(_toFormData){
        _bodyData = FormData.fromMap(_params);
      }
      if(_toBodyData){
        _bodyData = _params;
      }

      Response response = await _rxNet.client!.request(
          url,
          data: _bodyData,
          queryParameters: (isRestfulUrl() || _toFormData || _toBodyData)? {} : _params,
          options: _options,
          cancelToken: _cancelToken);


      onResponse?.call(response);
      if (response.statusCode == 200) {
        success?.call(response.data, SourcesType.net);
        return;
      }
      failure?.call(response.data);
    } catch (e, s) {
      _catchError(success, failure, null, e, s);
    } finally {
      completed?.call();
    }
  }



  ///下载文件
  ///[savePath]  文件保存路径
   void download({
    required String savePath,
    ProgressCallback? onReceiveProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
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
        _options?.headers?.addAll(_rxNet._globalHeader);
      }
      if(_toFormData){
        _bodyData = FormData.fromMap(_params);
      }
      if(_toBodyData){
        _bodyData = _params;
      }

      final response = await _rxNet.client!.download(url, savePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              onReceiveProgress?.call(received, total);
            }
            ///下载完成
            if(received>=total){
              success?.call(savePath, SourcesType.net);
            }
          },
          queryParameters: (isRestfulUrl() || _toFormData || _toBodyData) ? {} : _params,
          data: _bodyData,
          options: _options,
          cancelToken: _cancelToken);
      onResponse?.call(response);
      ///失败
      if (response.statusCode != 200) {
        failure?.call(response.data);
        return;
      }
    } catch (e, s) {
      _catchError<T>(success, failure, null, e, s);
    }finally{
      completed?.call();
    }
  }


  ///下载文件 支持断点下载
  ///[savePath]  文件保存路径
  ///[cancelCallback]  取消下载时的回调
  ///下载成功 回调[success] 获取文件本身
  void breakPointDownload({
    required String savePath,
    ProgressCallback? onReceiveProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
    Function()? cancelCallback,
  }) async {

    if (!(await _checkNetWork())) {
      return;
    }

    int downloadStart = 0;
    File file = File(savePath);
    try{
      String url = _path.toString();
      if (isRestfulUrl()) {
        url = NetUtils.restfulUrl(_path.toString(), _params);
      }
      if (file.existsSync()) {
        // downloadStart = file.lengthSync();
        Stream<List<int>> streamFileSize = file.openRead();
        await for (var chunk in streamFileSize) {
          downloadStart += chunk.length;
        }
      }
      _options?.method = _httpType.name;
      /// 以流的方式接收响应数据
      _options = _options?.copyWith(
        responseType: ResponseType.stream,
      );
      ///局部头优先与全局
      if (_headers.isNotEmpty) {
        _options?.headers?.addAll(_headers);
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet._globalHeader);
      }
      _options?.headers?.addAll({"Range": "bytes=$downloadStart-"});
      if(_toFormData){
        _bodyData = FormData.fromMap(_params);
      }
      if(_toBodyData){
        _bodyData = _params;
      }

      final response = await  _rxNet.client!.request<ResponseBody>(
        url,
        options: _options,
        cancelToken: _cancelToken,
        data: _bodyData,
        queryParameters: (isRestfulUrl() || _toFormData || _toBodyData) ? {} : _params,
      );
      onResponse?.call(response);
      RandomAccessFile raf = file.openSync(mode: FileMode.append);
      Stream<Uint8List> stream = response.data!.stream;

      final content= await getContentLength(response);
      final total = int.tryParse(content?.split('/').last??"0")??0;

      final subscription =stream.listen((data) {
          raf.writeFromSync(data);
          downloadStart = downloadStart+data.length;
          if(total<downloadStart){
            onReceiveProgress?.call(total, total);
            return;
          }
          onReceiveProgress?.call(downloadStart, total);
        },
        onDone: () async {
          success?.call(file, SourcesType.net);
          await raf.close();
        },
        onError: (e) async {
           _collectError(e);
           failure?.call(e);
           await raf.close();
        },
        cancelOnError: true
      );

      _cancelToken?.whenCancel.then((_) async {
        await subscription.cancel();
        await raf.close();
        cancelCallback?.call();
      });

    }on DioException catch (error) {
      if(error.response!=null){
        final content= await getContentLength(error.response!);
        final total = int.tryParse(content?.split('/').last??"0")??0;
        if(total<=downloadStart){
          onReceiveProgress?.call(total, total);
          success?.call(file, SourcesType.net);
          return;
        }
      }
      _collectError(error);
      failure?.call(error);
      if (CancelToken.isCancel(error)) {
        cancelCallback?.call();
        return;
      }
    } finally {
      completed?.call();
    }
  }


  ///上传文件 支持断点上传
  ///[filePath]  上传文件的路径
  ///[cancelCallback]  取消下载时的回调
  ///下载成功 回调[success] 获取文件本身
  void breakPointUploadFile({
    required String filePath,
    ProgressCallback? onSendProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
    Function()? cancelCallback,
    int? start,
  }) async {

    if (!(await _checkNetWork())) {
      return;
    }
    String url = _path.toString();
    if (isRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    var progress = start ?? 0;
    int fileSize = 0;
    File file = File(filePath);
    if (file.existsSync()) {
      Stream<List<int>> streamFileSize = file.openRead();
      await for (var chunk in streamFileSize) {
        fileSize += chunk.length;
      }
    }
    var data = file.openRead(progress,fileSize-progress);
    try {

      _options?.method = _httpType.name;
      if (_headers.isNotEmpty) {
        _options?.headers?.addAll(_headers);
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet._globalHeader);
      }
      _options?.headers?.addAll({'Content-Range': 'bytes $progress-${fileSize - 1}/$fileSize'});

      if(_toFormData){
        _bodyData = FormData.fromMap(_params);
      }
      if(_toBodyData){
        _bodyData = _params;
      }
      final response = await _rxNet.client!.request<ResponseBody>(
        url,
        options: _options,
        cancelToken: _cancelToken,
        data: data,
        queryParameters: (isRestfulUrl() || _toFormData || _toBodyData) ? {} : _params,
      );
      onResponse?.call(response);
      Stream<Uint8List> stream = response.data!.stream;
      final subscription =stream.listen((data) {
           progress = progress+data.length;
           onSendProgress?.call(progress, fileSize);
         },
          onDone: () async {
            success?.call(file, SourcesType.net);
          },
          onError: (e) async {
            failure?.call(e);
            _collectError(e);
          },
           cancelOnError: true
      );
      _cancelToken?.whenCancel.then((_) async {
        await subscription.cancel();
        cancelCallback?.call();
      });
    } on DioException catch (error) {
      if(error.response!=null){
        if(progress<=fileSize){
          onSendProgress?.call(progress, fileSize);
          success?.call(file, SourcesType.net);
          return;
        }
      }
      _collectError(error);
      if (CancelToken.isCancel(error)) {
        cancelCallback?.call();
        return;
      }
      failure?.call(error);
    } finally {
      completed?.call();
    }
  }


  /// 获取下载的文件大小 (0 - max) 文件末尾长度
   Future<String?> getContentLength(Response<dynamic> response) async {
    try {
      return response.headers.value(HttpHeaders.contentRangeHeader);
    } catch (e) {
      return null;
    }
  }

  void _catchError<T>(Success<T>? success, Failure<T>? failure,
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
    _rxNet._requestCaptureError?.call(e);
  }
}
