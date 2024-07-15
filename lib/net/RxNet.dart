import 'dart:async';
import 'dart:convert';
import 'dart:core';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/io.dart';
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

  static final RxNet _instance = RxNet._internal();

  factory RxNet() => _instance;

  Dio? get client => _client;

  CheckNetWork? baseCheckNet;

  RequestCaptureError? requestCaptureError;

  CacheMode? baseCacheMode;

  Map<String, dynamic> globalHeader = {};

  RxNetDataBase? _dataBase;

  /// 支持多环境 baseUrl调试 ,
  /// 例如：
  /// test: http://192.168.1.100:8080/
  /// debug: http://192.168.1.100:8080/
  /// release: http://192.168.1.100:8080/
  /// 则 baseUrlEnv = {"test":"http://192.168.1.100:8080/","debug":"http://192.168.1.100:8080/","release":"http://192.168.1.100:8080/"}
  Map<String, dynamic> baseUrlEnv = {};

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
    Map<String, dynamic>? baseUrlEnv,
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
    if(baseUrlEnv!= null && baseUrlEnv.isNotEmpty){
      baseUrlEnv.addAll(baseUrlEnv);
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


  /// 切换环境
  /// [env] 环境名称 key
  /// 例如：debug,test,release
  void setEnv(String env){
    _client?.options.baseUrl = baseUrlEnv[env];
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
  void setHeaders(Map<String, dynamic> header) {
    globalHeader = header;
  }

  Map<String, dynamic> getHeaders() {
    return globalHeader;
  }
}

class BuildRequest<T> {

  final HttpType _httpType;

  final RxNet _rxNet;

  CancelToken? _cancelToken;

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

  BuildRequest removeNullValueKeys() {
    if(_httpType == HttpType.post) {
      if (_bodyData is Map) {
        _bodyData.removeWhere((key, value) => value == null);
      }
    }else{
      _params.removeWhere((key, value) =>  value == null);
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
          cancelToken: _cancelToken);

      ///成功
      if (response.statusCode == 200) {
        if (getJsonConvertAdapter() != null) {
          LogUtil.v("useJsonAdapter：true");
          try {
            var data = getJsonConvertAdapter()?.jsonTransformation.call(response.data);
            success?.call(data as T, SourcesType.net);
          }catch(e){
            LogUtil.v("RxNet：请检查json数据结构类型转化类是否正确");
          }
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
          cancelToken: _cancelToken);

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
          cancelToken: _cancelToken);
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


  ///下载文件 支持断点下载
  ///[savePath]  文件保存路径
  ///[cancelCallback]  取消下载时的回调
  ///下载成功 回调[success] 获取文件本身
  void breakPointDownload({
    required String savePath,
    ProgressCallback? onReceiveProgress,
    SuccessCallback? success,
    FailureCallback? failure,
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
        followRedirects: false,
      );
      ///局部头优先与全局
      if (_headers.isNotEmpty) {
        _options?.headers?.addAll(_headers);
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.globalHeader);
      }
      _options?.headers?.addAll({"Range": "bytes=$downloadStart-"});
      final response = await  _rxNet.client!.request<ResponseBody>(
        url,
        options: _options,
        cancelToken: _cancelToken,
        data: _bodyData,
        queryParameters: isRestfulUrl() ? {} : _params,
      );
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

      _cancelToken?.whenCancel?.then((_) async {
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
    }
  }


  ///上传文件 支持断点上传
  ///[filePath]  上传文件的路径
  ///[cancelCallback]  取消下载时的回调
  ///下载成功 回调[success] 获取文件本身
  void breakPointUploadFile({
    required String filePath,
    ProgressCallback? onSendProgress,
    SuccessCallback? success,
    FailureCallback? failure,
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
        _options?.headers?.addAll(_rxNet.globalHeader);
      }
      _options?.headers?.addAll({'Content-Range': 'bytes $progress-${fileSize - 1}/$fileSize'});
      final response = await _rxNet.client!.request<ResponseBody>(
        url,
        options: _options,
        cancelToken: _cancelToken,
        data: data,
        queryParameters: isRestfulUrl() ? {} : _params,
      );

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
        await subscription?.cancel();
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
