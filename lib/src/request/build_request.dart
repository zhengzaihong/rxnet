import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:rxnet_plus/rxnet_lib.dart';
import 'package:rxnet_plus/src/request/request_body_type.dart';
import '../../utils/net_utils.dart';
import '../../utils/rx_net_database.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2025-08-12
/// create_time: 17:22
/// describe: 优化 RxNet职责，将BuildRequest从RxNet中分离出来，
/// update_date: 2025-10-03
/// 主要改进：
/// 1. 引入RequestBodyType枚举，明确参数发送方式
/// 2. 优化RESTful参数处理，支持路径参数和查询参数分离
/// 3. 改进缓存键生成逻辑
/// 4. 统一错误处理
/// 5. 更流畅的API设计
///
class BuildRequest<T> {
  final HttpType _httpType;
  final RxNet _rxNet;

  // 基础配置
  CancelToken? _cancelToken;
  String? _path;
  CacheMode? _cacheMode;
  Options? _options;

  // 参数管理 - 优化：分离路径参数和查询参数
  Map<String, dynamic> _pathParams = {};  // RESTful路径参数
  Map<String, dynamic> _queryParams = {}; // URL查询参数
  Map<String, dynamic> _bodyParams = {};  // Body参数
  dynamic _rawBody;  // 原始body数据（用于自定义body）

  // 请求体类型 - 新增：明确的类型控制
  RequestBodyType _bodyType = RequestBodyType.auto;

  // 请求头
  Map<String, dynamic> _headers = {};
  bool _enableGlobalHeader = true;

  // 缓存配置
  List<String> _ignoreCacheKeys = [];
  int? _cacheInvalidationTime;
  bool _requestIgnoreCacheTime = false;

  // 重试和轮询
  int _retryCount = 0;
  Duration _retryInterval = const Duration(seconds: 0);
  bool _isLoop = false;
  Duration _loopInterval = const Duration(seconds: 5);

  // JSON转换
  JsonTransformation? _jsonTransformation;

  // 回调
  CheckNetWork? checkNetWork;
  Function(Response response)? onResponse;

  BuildRequest(this._httpType, this._rxNet) {
    BaseOptions? op = _rxNet.client?.options;
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

  // ==================== 路径配置 ====================

  BuildRequest<T> setPath(String path) {
    _path = path;
    return this;
  }

  // ==================== 参数配置 -  ====================

  /// 设置路径参数（用于RESTful风格）
  /// 例如：setPathParam("id", "123") 会将 /user/{id} 替换为 /user/123
  BuildRequest<T> setPathParam(String key, dynamic value) {
    _pathParams[key] = value;
    return this;
  }

  /// 批量设置路径参数
  BuildRequest<T> setPathParams(Map<String, dynamic> params) {
    _pathParams.addAll(params);
    return this;
  }

  /// 设置查询参数（拼接在URL后）
  /// 例如：setQueryParam("page", 1) 会生成 ?page=1
  BuildRequest<T> setQueryParam(String key, dynamic value) {
    _queryParams[key] = value;
    return this;
  }

  /// 批量设置查询参数
  BuildRequest<T> setQueryParams(Map<String, dynamic> params) {
    _queryParams.addAll(params);
    return this;
  }

  /// 设置Body参数（用于POST/PUT/PATCH）
  BuildRequest<T> setBodyParam(String key, dynamic value) {
    _bodyParams[key] = value;
    return this;
  }

  /// 批量设置Body参数
  BuildRequest<T> setBodyParams(Map<String, dynamic> params) {
    _bodyParams.addAll(params);
    return this;
  }

  /// 设置原始Body数据（用于自定义body）
  BuildRequest<T> setRawBody(dynamic body) {
    _rawBody = body;
    return this;
  }

  /// 兼容旧API：setParam - 根据HTTP方法自动判断参数类型
  @Deprecated('使用 setPathParam/setQueryParam/setBodyParam 更明确')
  BuildRequest<T> setParam(String key, dynamic value) {
    // 自动判断：GET/DELETE用query，POST/PUT/PATCH用body
    if (_httpType == HttpType.get || _httpType == HttpType.delete) {
      _queryParams[key] = value;
    } else {
      _bodyParams[key] = value;
    }
    return this;
  }

  /// 兼容旧API：setParams
  @Deprecated('使用 setPathParams/setQueryParams/setBodyParams 更明确')
  BuildRequest<T> setParams(Map<String, dynamic> params) {
    if (_httpType == HttpType.get || _httpType == HttpType.delete) {
      _queryParams.addAll(params);
    } else {
      _bodyParams.addAll(params);
    }
    return this;
  }

  /// 兼容旧API：addParams
  @Deprecated('使用 setPathParams/setQueryParams/setBodyParams 更明确')
  BuildRequest<T> addParams(Map<String, dynamic> params) {
    return setParams(params);
  }

  // ==================== 请求体类型配置 - 新增 ====================

  /// 设置请求体类型
  BuildRequest<T> setBodyType(RequestBodyType type) {
    _bodyType = type;
    return this;
  }

  /// 使用JSON格式发送（application/json）
  BuildRequest<T> asJson() {
    _bodyType = RequestBodyType.json;
    _options?.contentType = ContentTypes.json;
    return this;
  }

  /// 使用FormData格式发送（multipart/form-data）
  BuildRequest<T> asFormData() {
    _bodyType = RequestBodyType.formData;
    _options?.contentType = ContentTypes.multipartFormData;
    return this;
  }

  /// 使用URL编码格式发送（application/x-www-form-urlencoded）
  BuildRequest<T> asUrlEncoded() {
    _bodyType = RequestBodyType.urlEncoded;
    _options?.contentType = ContentTypes.formUrlEncoded;
    return this;
  }

  /// 兼容旧API：toFormData
  @Deprecated('使用 asFormData() 更简洁')
  BuildRequest<T> toFormData() {
    return asFormData();
  }

  /// 兼容旧API：toBodyData
  @Deprecated('使用 asJson() 更明确')
  BuildRequest<T> toBodyData() {
    return asJson();
  }

  /// 兼容旧API：toUrlEncoded
  @Deprecated('使用 asUrlEncoded() 更简洁')
  BuildRequest<T> toUrlEncoded() {
    return asUrlEncoded();
  }

  // ==================== RESTful 支持 -  ====================

  /// 兼容旧API：setRestfulUrl
  /// 新版本会自动检测路径中的占位符，无需手动设置
  @Deprecated('框架会自动检测RESTful路径，无需手动设置')
  BuildRequest<T> setRestfulUrl(bool restful) {
    // 保留方法体以兼容旧代码，不做任何事了
    return this;
  }

  /// 检测路径是否包含RESTful占位符
  bool _hasRestfulPlaceholders() {
    return _path?.contains(RegExp(r'\{[^}]+\}')) ?? false;
  }

  /// 构建最终的URL（处理RESTful参数）
  String _buildFinalUrl() {
    String url = _path ?? '';

    // 如果路径包含占位符，自动进行RESTful替换
    if (_hasRestfulPlaceholders()) {
      // 创建副本避免修改原始数据
      final pathParamsCopy = Map<String, dynamic>.from(_pathParams);
      url = NetUtils.restfulUrl(url, pathParamsCopy);
    }

    return url;
  }

  // ==================== 其他配置方法 ====================

  BuildRequest<T> setJsonConvert(JsonTransformation convert) {
    _jsonTransformation = convert;
    return this;
  }

  BuildRequest<T> setResponseType(ResponseType type) {
    _options?.responseType = type;
    return this;
  }

  BuildRequest<T> setContentType(String type) {
    _options?.contentType = type;
    return this;
  }

  BuildRequest<T> setHeader(String key, dynamic value) {
    _headers[key] = value;
    return this;
  }

  BuildRequest<T> addHeaders(Map<String, dynamic> headers) {
    _headers.addAll(headers);
    return this;
  }

  BuildRequest<T> setCancelToken(CancelToken cancelToken) {
    _cancelToken = cancelToken;
    return this;
  }

  BuildRequest<T> setEnableGlobalHeader(bool enable) {
    _enableGlobalHeader = enable;
    return this;
  }

  BuildRequest<T> setCacheMode(CacheMode cacheMode) {
    _cacheMode = cacheMode;
    if (RxNetPlatform.isWeb) {
      _cacheMode = CacheMode.ONLY_REQUEST;
    }
    return this;
  }

  BuildRequest<T> setRequestIgnoreCacheTime(bool ignoreCache) {
    _requestIgnoreCacheTime = ignoreCache;
    return this;
  }

  BuildRequest<T> setIgnoreCacheKeys(List<String> keys) {
    _ignoreCacheKeys.addAll(keys);
    return this;
  }

  BuildRequest<T> setIgnoreCacheKey(String key) {
    _ignoreCacheKeys.add(key);
    return this;
  }

  BuildRequest<T> setLoop(bool loop, {Duration? interval}) {
    _isLoop = loop;
    if (interval != null) {
      _loopInterval = interval;
    }
    return this;
  }

  BuildRequest<T> setRetryCount(int count, {Duration? interval}) {
    _retryCount = count;
    if (interval != null) {
      _retryInterval = interval;
    }
    return this;
  }

  BuildRequest<T> setCacheInvalidationTime(int millisecond) {
    _cacheInvalidationTime = millisecond;
    return this;
  }

  BuildRequest<T> setOptionConfig(OptionConfig callBack) {
    callBack.call(_options!);
    return this;
  }

  BuildRequest<T> setCheckNetwork(CheckNetWork checkNetWork) {
    this.checkNetWork = checkNetWork;
    return this;
  }

  BuildRequest<T> setResponseCallBack(Function(Response response) responseCallBack) {
    this.onResponse = responseCallBack;
    return this;
  }

  BuildRequest<T> removeNullValueKeys() {
    _pathParams.removeWhere((key, value) => value == null);
    _queryParams.removeWhere((key, value) => value == null);
    _bodyParams.removeWhere((key, value) => value == null);
    return this;
  }

  BuildRequest<T> getParams(ParamCallBack callBack) {
    // 合并所有参数供回调使用
    final allParams = <String, dynamic>{}
      ..addAll(_pathParams)
      ..addAll(_queryParams)
      ..addAll(_bodyParams);
    callBack.call(allParams);
    return this;
  }

  CancelToken? getCancelToken() {
    return _cancelToken;
  }

  // ==================== 核心请求方法 -  ====================

  /// 执行请求的核心方法
  Future<RxResult<T>> _doRequest<T>({bool cache = false}) async {
    final url = _buildFinalUrl();

    // 准备查询参数
    Map<String, dynamic> queryParameters = Map.from(_queryParams);

    // 准备请求体
    dynamic requestBody = _rawBody;

    // 根据bodyType决定如何处理参数
    if (_rawBody == null && _bodyParams.isNotEmpty) {
      // 检测是否包含文件
      bool hasFile = _bodyParams.values.any((element) =>
      element is MultipartFile || element is File);

      // 自动判断body类型
      if (_bodyType == RequestBodyType.auto) {
        if (hasFile) {
          _bodyType = RequestBodyType.formData;
        } else if (_httpType == HttpType.post ||
            _httpType == HttpType.put ||
            _httpType == HttpType.patch) {
          _bodyType = RequestBodyType.json;
        }
      }

      // 根据类型处理参数
      switch (_bodyType) {
        case RequestBodyType.query:
          queryParameters.addAll(_bodyParams);
          requestBody = null;
          break;
        case RequestBodyType.json:
          requestBody = _bodyParams;
          break;
        case RequestBodyType.formData:
          requestBody = FormData.fromMap(_bodyParams);
          break;
        case RequestBodyType.urlEncoded:
          requestBody = FormData.fromMap(_bodyParams);
          _options?.contentType = ContentTypes.formUrlEncoded;
          break;
        case RequestBodyType.auto:
        // GET/DELETE默认用query
          if (_httpType == HttpType.get || _httpType == HttpType.delete) {
            queryParameters.addAll(_bodyParams);
            requestBody = null;
          } else {
            requestBody = _bodyParams;
          }
          break;
      }
    }

    try {
      LogUtil.v("$url，JsonConvert：${_jsonTransformation != null}");

      _options?.method = _httpType.name;
      if (_headers.isNotEmpty) {
        _options?.headers = _headers;
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.getHeaders());
      }

      Response<dynamic> response = await _rxNet.client!.request(url,
          data: requestBody,
          queryParameters: queryParameters,
          options: _options,
          cancelToken: _cancelToken);

      onResponse?.call(response);
      var responseData = response.data;

      if (response.statusCode == 200) {
        T data;
        try {
          if (_jsonTransformation != null) {
            if (responseData is String) {
              responseData = jsonDecode(responseData);
            }
            data = await _jsonTransformation?.call(responseData) as T;
          } else {
            data = responseData as T;
          }
        } catch (e) {
          throw ParsingException("Data parsing failed", e);
        }

        // 缓存处理 - 优化：使用更清晰的缓存键生成
        if (cache && !RxNetPlatform.isWeb) {
          _saveCacheData(responseData);
        }

        return RxResult(value: data, model: SourcesType.net);
      } else {
        throw NetworkException("Request failed with status code ${response.statusCode}", response);
      }
    } catch (e, s) {
      LogUtil.v("请求出错：$e\n$s");
      if (e is DioException && CancelToken.isCancel(e)) {
        throw CancellationException("Request was cancelled", e);
      }
      if (e is RxError) {
        throw e;
      }
    }
    throw NetworkException("Request failed", null);
  }

  /// 保存缓存数据
  void _saveCacheData(dynamic responseData) {
    // 合并全局和本地忽略键
    final allIgnoreKeys = <String>[];
    if (_rxNet.getIgnoreCacheKeys() != null) {
      allIgnoreKeys.addAll(_rxNet.getIgnoreCacheKeys()!);
    }
    allIgnoreKeys.addAll(_ignoreCacheKeys);

    // 生成缓存键：合并所有参数
    final allParams = <String, dynamic>{}
      ..addAll(_pathParams)
      ..addAll(_queryParams)
      ..addAll(_bodyParams);

    String cacheKey = NetUtils.getCacheKeyFromPath(_path, allParams, allIgnoreKeys);

    final map = <String, dynamic>{
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': responseData
    };
    _rxNet.cacheManager.saveCache(cacheKey, jsonEncode(map));
  }

  /// 读取缓存
  Future<RxResult<T>> _readCache<T>() async {
    if (RxNetPlatform.isWeb || !await RxNetDataBase.isDatabaseReady) {
      throw CacheException("Cache not available");
    }

    // 合并全局和本地忽略键
    final allIgnoreKeys = <String>[];
    if (_rxNet.getIgnoreCacheKeys() != null) {
      allIgnoreKeys.addAll(_rxNet.getIgnoreCacheKeys()!);
    }
    allIgnoreKeys.addAll(_ignoreCacheKeys);

    // 生成缓存键
    final allParams = <String, dynamic>{}
      ..addAll(_pathParams)
      ..addAll(_queryParams)
      ..addAll(_bodyParams);

    final cacheKey = NetUtils.getCacheKeyFromPath(_path, allParams, allIgnoreKeys);
    final cacheData = await _rxNet.cacheManager.readCache(cacheKey);

    if (TextUtil.isEmpty(cacheData)) {
      throw CacheException("Cache is empty");
    }

    dynamic data;
    try {
      data = jsonDecode(cacheData);
    } catch (e) {
      throw ParsingException("Failed to decode cache data", e);
    }

    final timestamp = data['timestamp'];
    final dataValue = data['data'];
    LogUtil.v("缓存数据:${jsonEncode(data)}");

    final now = DateTime.now().millisecondsSinceEpoch;
    LogUtil.v("缓存数据时效:${_cacheInvalidationTime} now - timestamp ：${now - timestamp }");
    if (now - timestamp > (_cacheInvalidationTime ?? _rxNet.getCacheInvalidationTime())) {
      LogUtil.v("缓存数据:超时效");
      throw CacheException("Cache expired");
    }
    if (dataValue != null) {
      return _parseLocalData<T>(dataValue);
    } else {
      throw CacheException("Cache is empty");
    }
  }

  Future<RxResult<T>> _parseLocalData<T>(dynamic cacheValue) async {
    try {
      if (_jsonTransformation != null) {
        LogUtil.v("JsonConvert：true");
        final data = await _jsonTransformation?.call(cacheValue) as T;
        return RxResult(value: data, model: SourcesType.cache);
      } else {
        LogUtil.v("JsonConvert：false");
        return RxResult(value: cacheValue as T, model: SourcesType.cache);
      }
    } catch (e) {
      LogUtil.v("RxNet：请检查json数据接收类是否正确: $e");
      throw ParsingException("Failed to parse cached data", e);
    }
  }

  Future<bool> _checkNetWork() async {
    if (checkNetWork != null) {
      return await checkNetWork!.call();
    }
    if (checkNetWork == null && _rxNet.getCheckNetWork() != null) {
      return await _rxNet.getCheckNetWork()!.call();
    }
    return true;
  }

  // ==================== 公共请求方法 ====================

  /// 使用回调的方式
  void execute<T>({Success<T>? success, Failure? failure, Completed? completed}) {
    executeStream<T>().listen((result) {
      if (result.isSuccess) {
        success?.call(result.value as T, result.model);
      } else {
        failure?.call(result.error as Object);
      }
    }, onError: (e) {
      failure?.call(e);
    }, onDone: completed);
  }

  /// async/await方式
  Future<RxResult<T>> request<T>() async {
    return await executeStream<T>().first;
  }

  /// Stream方式（支持轮询）
  Stream<RxResult<T>> executeStream<T>() async* {
    if (TextUtil.isEmpty(_path)) {
      yield RxResult.error(Exception("The request path cannot be empty path:$_path"));
      return;
    }

    if (!(await _checkNetWork())) {
      yield RxResult.error(NetworkException("Network not available"));
      return;
    }

    _cacheMode ??= (_rxNet.getBaseCacheMode() ?? CacheMode.ONLY_REQUEST);

    bool keepLooping;
    do {
      keepLooping = _isLoop;
      switch (_cacheMode!) {
        case CacheMode.ONLY_REQUEST:
          yield* _networkRequestStream<T>(shouldCache: false);
          break;
        case CacheMode.FIRST_USE_CACHE_THEN_REQUEST:
          try {
            final cacheResult = await _readCache<T>();
            yield cacheResult;
          } catch (e) {
            // Cache errors are ignored, proceed to network.
          }
          yield* _networkRequestStream<T>(shouldCache: true);
          break;
        case CacheMode.REQUEST_FAILED_READ_CACHE:
          bool networkSucceeded = false;
          await for (final netResult in _networkRequestStream<T>(shouldCache: true)) {
            if (netResult.isSuccess) {
              networkSucceeded = true;
            }
            yield netResult;
          }
          if (!networkSucceeded) {
            try {
              final cacheResult = await _readCache<T>();
              yield cacheResult;
            } catch (e) {
              // If cache also fails, the last network error is already emitted.
            }
          }
          break;
        case CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST:
          bool yieldedFromCache = false;
          if (!_requestIgnoreCacheTime) {
            try {
              final cacheResult = await _readCache<T>();
              yield cacheResult;
              yieldedFromCache = true;
            } catch (e) {
              // Cache failed, proceed to network.
            }
          }
          if (!yieldedFromCache) {
            yield* _networkRequestStream<T>(shouldCache: true);
          }
          break;
        case CacheMode.ONLY_CACHE:
          try {
            final cacheResult = await _readCache<T>();
            yield cacheResult;
          } catch (e) {
            yield RxResult.error(e);
          }
          break;
      }

      if (keepLooping) {
        await Future.delayed(_loopInterval);
      }
    } while (keepLooping);
  }

  Stream<RxResult<T>> _networkRequestStream<T>({required bool shouldCache}) async* {
    int attempt = 0;
    bool success = false;
    do {
      attempt++;
      try {
        final result = await _doRequest<T>(cache: shouldCache);
        yield result;
        success = true;
        break;
      } catch (e) {
        yield RxResult.error(e);
        if (attempt <= _retryCount) {
          await Future.delayed(_retryInterval);
        }
      }
    } while (attempt <= _retryCount && !success);
  }

  // ==================== 下载上传方法 ====================

  /// 下载文件
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

    final url = _buildFinalUrl();

    try {
      _options?.method = _httpType.name;
      if (_headers.isNotEmpty) {
        _options?.headers = _headers;
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.getHeaders());
      }

      // 准备请求体
      dynamic requestBody = _rawBody;
      if (_rawBody == null && _bodyParams.isNotEmpty) {
        if (_bodyType == RequestBodyType.formData) {
          requestBody = FormData.fromMap(_bodyParams);
        } else if (_bodyType == RequestBodyType.json) {
          requestBody = _bodyParams;
        }
      }

      final response = await _rxNet.client!.download(
          url,
          savePath,
          onReceiveProgress: (received, total) {
            if (total != -1) {
              onReceiveProgress?.call(received, total);
            }
            if (received >= total) {
              success?.call(savePath, SourcesType.net);
            }
          },
          queryParameters: _queryParams,
          data: requestBody,
          options: _options,
          cancelToken: _cancelToken
      );

      onResponse?.call(response);
      if (response.statusCode != 200) {
        failure?.call(response.data);
      }
    } catch (e) {
      failure?.call(e);
    }
    completed?.call();
  }

  /// 断点下载
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

    try {
      final url = _buildFinalUrl();

      if (file.existsSync()) {
        downloadStart = file.lengthSync();
      }

      _options?.method = _httpType.name;
      _options = _options?.copyWith(
        responseType: ResponseType.stream,
      );

      if (_headers.isNotEmpty) {
        _options?.headers?.addAll(_headers);
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.getHeaders());
      }
      _options?.headers?.addAll({"Range": "bytes=$downloadStart-"});

      // 准备请求体
      dynamic requestBody = _rawBody;
      if (_rawBody == null && _bodyParams.isNotEmpty) {
        if (_bodyType == RequestBodyType.formData) {
          requestBody = FormData.fromMap(_bodyParams);
        } else if (_bodyType == RequestBodyType.json) {
          requestBody = _bodyParams;
        }
      }

      final response = await _rxNet.client!.request<ResponseBody>(
        url,
        options: _options,
        cancelToken: _cancelToken,
        data: requestBody,
        queryParameters: _queryParams,
      );

      onResponse?.call(response);
      RandomAccessFile raf = file.openSync(mode: FileMode.append);
      Stream<Uint8List> stream = response.data!.stream;

      final content = await getContentLength(response);
      final total = int.tryParse(content?.split('/').last ?? "0") ?? 0;

      final subscription = stream.listen((data) {
        raf.writeFromSync(data);
        downloadStart = downloadStart + data.length;
        if (total < downloadStart) {
          onReceiveProgress?.call(total, total);
          return;
        }
        onReceiveProgress?.call(downloadStart, total);
      }, onDone: () async {
        success?.call(file, SourcesType.net);
        await raf.close();
      }, onError: (e) async {
        failure?.call(e);
        await raf.close();
      }, cancelOnError: true);

      _cancelToken?.whenCancel.then((_) async {
        await subscription.cancel();
        await raf.close();
        cancelCallback?.call();
      });
    } on DioException catch (error) {
      if (error.response != null) {
        final content = await getContentLength(error.response!);
        final total = int.tryParse(content?.split('/').last ?? "0") ?? 0;
        if (total <= downloadStart) {
          onReceiveProgress?.call(total, total);
          success?.call(file, SourcesType.net);
        }
      }
      if (CancelToken.isCancel(error)) {
        cancelCallback?.call();
      } else {
        failure?.call(error);
      }
    }

    completed?.call();
  }

  /// 上传文件
  void upload({
    ProgressCallback? onSendProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
  }) async {
    if (!(await _checkNetWork())) {
      return;
    }

    final url = _buildFinalUrl();

    try {
      _options?.method = _httpType.name;
      if (_headers.isNotEmpty) {
        _options?.headers = _headers;
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.getHeaders());
      }

      // 准备请求体
      dynamic requestBody = _rawBody;
      if (_rawBody == null && _bodyParams.isNotEmpty) {
        if (_bodyType == RequestBodyType.formData) {
          requestBody = FormData.fromMap(_bodyParams);
        } else if (_bodyType == RequestBodyType.json) {
          requestBody = _bodyParams;
        }
      }

      Response response = await _rxNet.client!.request(
        url,
        data: requestBody,
        queryParameters: _queryParams,
        options: _options,
        cancelToken: _cancelToken,
        onSendProgress: onSendProgress,
      );

      onResponse?.call(response);
      if (response.statusCode == 200) {
        success?.call(response.data, SourcesType.net);
      }
    } catch (e) {
      failure?.call(e);
    }
    completed?.call();
  }

  /// 断点上传
  void breakPointUpload({
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

    final url = _buildFinalUrl();

    var progress = start ?? 0;
    int fileSize = 0;
    File file = File(filePath);

    if (file.existsSync()) {
      fileSize = file.lengthSync();
    }

    var data = file.openRead(progress, fileSize - progress);

    try {
      _options?.method = _httpType.name;
      if (_headers.isNotEmpty) {
        _options?.headers?.addAll(_headers);
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.getHeaders());
      }
      _options?.headers?.addAll({
        'Content-Range': 'bytes $progress-${fileSize - 1}/$fileSize'
      });

      // 准备请求体（如果有额外的body参数）
      // dynamic requestBody = _rawBody;
      // if (_rawBody == null && _bodyParams.isNotEmpty) {
      //   if (_bodyType == RequestBodyType.formData) {
      //     requestBody = FormData.fromMap(_bodyParams);
      //   } else if (_bodyType == RequestBodyType.json) {
      //     requestBody = _bodyParams;
      //   }
      // }

      final response = await _rxNet.client!.request<ResponseBody>(
        url,
        options: _options,
        cancelToken: _cancelToken,
        data: data,
        queryParameters: _queryParams,
      );

      onResponse?.call(response);
      Stream<Uint8List> stream = response.data!.stream;

      final subscription = stream.listen((data) {
        progress = progress + data.length;
        onSendProgress?.call(progress, fileSize);
      }, onDone: () async {
        success?.call(file, SourcesType.net);
      }, onError: (e) async {
        failure?.call(e);
      }, cancelOnError: true);

      _cancelToken?.whenCancel.then((_) async {
        await subscription.cancel();
        cancelCallback?.call();
      });
    } on DioException catch (error) {
      if (error.response != null) {
        if (progress <= fileSize) {
          onSendProgress?.call(progress, fileSize);
          success?.call(file, SourcesType.net);
        }
      }
      if (CancelToken.isCancel(error)) {
        cancelCallback?.call();
      } else {
        failure?.call(error);
      }
    }

    completed?.call();
  }

  /// 获取内容长度
  Future<String?> getContentLength(Response<dynamic> response) async {
    try {
      return response.headers.value(HttpHeaders.contentRangeHeader);
    } catch (e) {
      return null;
    }
  }
}
