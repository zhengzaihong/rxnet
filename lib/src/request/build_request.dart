import 'dart:async';
import 'dart:convert';
import 'dart:io' if (dart.library.html) '../adapter/implementations/http_adapter_web_stub.dart';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart';
import 'package:rxnet_plus/rxnet_lib.dart';
import 'package:rxnet_plus/src/type/request_body_type.dart';
import '../../utils/net_utils.dart';
import '../adapter/network_adapter.dart' as adapter;
import '../adapter/models/adapter_request.dart' as adapter_models;
import '../adapter/cancel_token.dart' as rxnet_cancel;

///
/// author: ZhengZaiHong
/// email: 1096877329@qq.com
/// date: 2025-08-12
/// describe: BuildRequest - 网络请求构建器 / Network Request Builder
///
/// ============================================================================
/// 类说明 / Class Description
/// ============================================================================
///
/// BuildRequest 是 RxNet Plus 的核心请求构建器，提供流畅的 API 来配置和执行网络请求。
/// 它将请求配置与 RxNet 主类分离，使代码更加清晰和易于维护。
///
/// BuildRequest is the core request builder of RxNet Plus, providing a fluent API
/// to configure and execute network requests. It separates request configuration
/// from the main RxNet class, making the code clearer and easier to maintain.
///
/// ============================================================================
/// 使用示例 / Usage Examples
/// ============================================================================
///
/// 1. 基础 GET 请求 / Basic GET Request:
/// ```dart
/// final result = await RxNet.get()
///   .setPath("/api/users")
///   .request();
/// ```
///
/// 2. RESTful 请求 / RESTful Request:
/// ```dart
/// final result = await RxNet.get()
///   .setPath("/api/users/{id}/posts")
///   .setPathParam("id", "123")
///   .setQueryParam("page", 1)
///   .request();
/// ```
///
/// 3. POST JSON 数据 / POST JSON Data:
/// ```dart
/// final result = await RxNet.post()
///   .setPath("/api/user")
///   .setBodyParams({"name": "John", "age": 25})
///   .asJson()
///   .request();
/// ```
///
/// 4. 文件上传 / File Upload:
/// ```dart
/// final file = await MultipartFile.fromFile("path/to/file.jpg");
/// final result = await RxNet.post()
///   .setPath("/api/upload")
///   .setBodyParam("file", file)
///   .asFormData()
///   .request();
/// ```
///
/// 5. 带缓存的请求 / Request with Cache:
/// ```dart
/// final result = await RxNet.get()
///   .setPath("/api/data")
///   .setCacheMode(CacheMode.FIRST_USE_CACHE_THEN_REQUEST)
///   .setCacheInvalidationTime(60000) // 60 seconds
///   .request();
/// ```
///
/// 6. 带重试的请求 / Request with Retry:
/// ```dart
/// final result = await RxNet.get()
///   .setPath("/api/data")
///   .setRetryCount(3, interval: Duration(seconds: 2))
///   .request();
/// ```
///
/// 7. 取消请求 / Cancel Request:
/// ```dart
/// final cancelToken = CancelToken();
///
/// RxNet.get()
///   .setPath("/api/data")
///   .setCancelToken(cancelToken)
///   .request();
///
/// // Later...
/// cancelToken.cancel("User cancelled");
/// ```
///
/// ============================================================================
/// 参数类型说明 / Parameter Types
/// ============================================================================
///
/// 1. **路径参数 / Path Parameters** (setPathParam/setPathParams)
///    - 用于 RESTful URL 中的占位符替换
///    - Used for placeholder replacement in RESTful URLs
///    - 例如：/users/{id} -> /users/123
///    - Example: /users/{id} -> /users/123
///
/// 2. **查询参数 / Query Parameters** (setQueryParam/setQueryParams)
///    - 拼接在 URL 后面的参数
///    - Parameters appended to the URL
///    - 例如：/users?page=1&size=20
///    - Example: /users?page=1&size=20
///
/// 3. **Body 参数 / Body Parameters** (setBodyParam/setBodyParams)
///    - POST/PUT/PATCH 请求的请求体参数
///    - Request body parameters for POST/PUT/PATCH
///    - 根据 bodyType 决定编码方式
///    - Encoding method determined by bodyType
///
/// 4. **原始 Body / Raw Body** (setRawBody)
///    - 自定义的原始请求体数据
///    - Custom raw request body data
///    - 优先级高于 bodyParams
///    - Takes precedence over bodyParams
///
/// ============================================================================
/// 请求体类型 / Request Body Types
/// ============================================================================
///
/// - **RequestBodyType.auto** - 自动判断（默认）/ Auto-detect (default)
/// - **RequestBodyType.json** - JSON 格式 / JSON format
/// - **RequestBodyType.formData** - FormData 格式 / FormData format
/// - **RequestBodyType.urlEncoded** - URL 编码 / URL-encoded
/// - **RequestBodyType.query** - 查询参数 / Query parameters
///
/// ============================================================================
/// 缓存模式 / Cache Modes
/// ============================================================================
///
/// - **ONLY_REQUEST** - 仅请求网络 / Network only
/// - **FIRST_USE_CACHE_THEN_REQUEST** - 先缓存后网络 / Cache first, then network
/// - **REQUEST_FAILED_READ_CACHE** - 请求失败读缓存 / Read cache on failure
/// - **CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST** - 缓存为空或过期时请求 / Request when cache is empty or expired
/// - **ONLY_CACHE** - 仅读缓存 / Cache only
///
/// ============================================================================
/// 注意事项 / Notes
/// ============================================================================
///
/// 1. BuildRequest 实例是一次性的，每次请求都会创建新实例
///    BuildRequest instances are disposable, a new instance is created for each request
///
/// 2. 参数设置方法可以链式调用
///    Parameter setting methods can be chained
///
/// 3. 请求执行后，BuildRequest 实例不应被重用
///    After request execution, BuildRequest instances should not be reused
///
/// ============================================================================
///
class BuildRequest<T> {
  final HttpMethod _httpMethod;
  final RxNet _rxNet;

  // 基础配置 / Basic Configuration
  rxnet_cancel.CancelToken? _cancelToken;
  String? _path;
  CacheMode? _cacheMode;

  // 参数管理 / Parameter Management
  // 优化：分离路径参数和查询参数 / Optimization: Separate path and query parameters
  Map<String, dynamic> _pathParams =
      {}; // RESTful 路径参数 / RESTful path parameters
  Map<String, dynamic> _queryParams = {}; // URL 查询参数 / URL query parameters
  Map<String, dynamic> _bodyParams = {}; // Body 参数 / Body parameters
  dynamic _rawBody; // 原始 body 数据（用于自定义 body）/ Raw body data (for custom body)

  // 请求体类型 / Request Body Type
  // 新增：明确的类型控制 / New: Explicit type control
  RequestBodyType _bodyType = RequestBodyType.auto;

  // 请求头 / Request Headers
  Map<String, dynamic> _headers = {};
  bool _enableGlobalHeader = true;

  // 请求配置
  Duration? _connectTimeout;
  Duration? _sendTimeout;
  Duration? _receiveTimeout;
  String? _contentType;
  ResponseType _responseType = ResponseType.json;

  // 缓存配置
  List<String> _ignoreCacheKeys = [];
  int? _cacheInvalidationTime;
  bool _requestIgnoreCacheTime = false;

  // 重试和轮询
  int _retryCount = 0;
  Duration _retryInterval = const Duration(seconds: 0);
  RetryPolicy? _retryPolicy;
  bool _isLoop = false;
  Duration _loopInterval = const Duration(seconds: 5);

  // JSON转换
  JsonTransformation? _jsonTransformation;

  // 回调
  CheckNetWork? checkNetWork;
  Function(AdapterResponse response)? onResponse;

  BuildRequest(this._httpMethod, this._rxNet);

  // ==================== 路径配置 ====================

  BuildRequest<T> setPath(String? path) {
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


  /// 设置请求体类型
  BuildRequest<T> setBodyType(RequestBodyType type) {
    _bodyType = type;
    return this;
  }

  /// 使用JSON格式发送（application/json）
  BuildRequest<T> asJson() {
    _bodyType = RequestBodyType.json;
    _contentType = ContentTypes.json;
    return this;
  }

  /// 使用FormData格式发送（multipart/form-data）
  BuildRequest<T> asFormData() {
    _bodyType = RequestBodyType.formData;
    _contentType = ContentTypes.multipartFormData;
    return this;
  }

  /// 使用URL编码格式发送（application/x-www-form-urlencoded）
  BuildRequest<T> asUrlEncoded() {
    _bodyType = RequestBodyType.urlEncoded;
    _contentType = ContentTypes.formUrlEncoded;
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
    _responseType = type;
    return this;
  }

  BuildRequest<T> setContentType(String type) {
    _contentType = type;
    return this;
  }

  BuildRequest<T> setSendTimeout(Duration timeout) {
    _sendTimeout = timeout;
    return this;
  }

  BuildRequest<T> setConnectTimeout(Duration timeout) {
    _connectTimeout = timeout;
    return this;
  }

  BuildRequest<T> setReceiveTimeout(Duration timeout) {
    _receiveTimeout = timeout;
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

  /// 设置取消令牌，支持两种方式：
  /// 1. 使用 RxNet 的 CancelToken（推荐）
  /// 2. 使用 Dio 的 CancelToken（向后兼容）
  BuildRequest<T> setCancelToken(dynamic cancelToken) {
    if (cancelToken is rxnet_cancel.CancelToken) {
      // RxNet CancelToken
      _cancelToken = cancelToken;
    } else if (cancelToken is dio.CancelToken) {
      // Dio CancelToken - 创建一个包装器
      final rxnetToken = rxnet_cancel.CancelToken();
      // 当 Dio token 被取消时，也取消 RxNet token
      cancelToken.whenCancel.then((_) {
        rxnetToken.cancel('Cancelled via Dio CancelToken');
      });
      _cancelToken = rxnetToken;
    } else {
      throw ArgumentError(
          'cancelToken must be either CancelToken or dio.CancelToken');
    }
    return this;
  }

  BuildRequest<T> setEnableGlobalHeader(bool enable) {
    _enableGlobalHeader = enable;
    return this;
  }

  BuildRequest<T> setCacheMode(CacheMode cacheMode) {
    _cacheMode = cacheMode;
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

  /// 设置高级重试策略（支持指数退避、抖动等）
  ///
  /// 使用此方法后，`setRetryCount` 设置的值将被忽略。
  ///
  /// ```dart
  /// RxNet.get()
  ///   .setPath("/api/data")
  ///   .setRetryPolicy(RetryPolicy.exponentialBackoff(
  ///     maxRetries: 3,
  ///     baseInterval: Duration(seconds: 1),
  ///   ))
  ///   .request();
  /// ```
  BuildRequest<T> setRetryPolicy(RetryPolicy policy) {
    _retryPolicy = policy;
    _retryCount = policy.maxRetries;
    return this;
  }

  BuildRequest<T> setCacheInvalidationTime(int millisecond) {
    _cacheInvalidationTime = millisecond;
    return this;
  }

  BuildRequest<T> setCheckNetwork(CheckNetWork checkNetWork) {
    this.checkNetWork = checkNetWork;
    return this;
  }

  BuildRequest<T> setResponseCallBack(
      Function(AdapterResponse response) responseCallBack) {
    this.onResponse = responseCallBack;
    return this;
  }

  BuildRequest<T> removeNullValueKeys() {
    _pathParams.removeWhere((key, value) => value == null);
    _queryParams.removeWhere((key, value) => value == null);
    _bodyParams.removeWhere((key, value) => value == null);
    return this;
  }

  BuildRequest<T> getParams(ParamCallback callBack) {
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

  /// 构建请求头
  Map<String, dynamic> _buildHeaders() {
    final headers = <String, dynamic>{};
    // 添加全局请求头
    if (_enableGlobalHeader) {
      headers.addAll(_rxNet.getHeaders());
    }
    // 添加自定义请求头
    headers.addAll(_headers);
    return headers;
  }

  /// 构建 AdapterRequest
  adapter_models.AdapterRequest _buildAdapterRequest({
    required String url,
    Map<String, dynamic>? queryParams,
    dynamic data,
    Map<String, dynamic>? headers,
    String? contentType,
    ResponseType? responseType,
  }) {
    // 从 RxNet 获取 baseUrl
    final baseUrl = _rxNet.baseUrl;

    return adapter_models.AdapterRequest(
      baseUrl: baseUrl,
      path: url,
      method: _httpMethod,
      queryParams: queryParams ?? {},
      bodyParams: _bodyParams, // 传递 bodyParams 以便拦截器可以访问
      headers: headers ?? _buildHeaders(),
      rawBody: data,
      contentType: contentType ?? _contentType,
      responseType: responseType ?? _responseType,
      connectTimeout: _connectTimeout,
      sendTimeout: _sendTimeout,
      receiveTimeout: _receiveTimeout,
      cancelToken: _cancelToken, // Use the actual cancel token
    );
  }


  RequestBodyType _resolveEffectiveBodyType() {
    if (_bodyType != RequestBodyType.auto || _rawBody != null) {
      return _bodyType;
    }

    final hasFile = _bodyParams.values
        .any((element) => element is MultipartFile || element is File);
    if (hasFile) {
      return RequestBodyType.formData;
    }

    if (_httpMethod == HttpMethod.GET || _httpMethod == HttpMethod.DELETE) {
      return RequestBodyType.query;
    }

    if (_httpMethod == HttpMethod.POST ||
        _httpMethod == HttpMethod.PUT ||
        _httpMethod == HttpMethod.PATCH) {
      return RequestBodyType.json;
    }

    return RequestBodyType.auto;
  }

  String? _resolveContentType(RequestBodyType bodyType) {
    if (_contentType != null) {
      return _contentType;
    }

    switch (bodyType) {
      case RequestBodyType.formData:
        return ContentTypes.multipartFormData;
      case RequestBodyType.urlEncoded:
        return ContentTypes.formUrlEncoded;
      case RequestBodyType.json:
        return _bodyType == RequestBodyType.json ? ContentTypes.json : null;
      case RequestBodyType.auto:
      case RequestBodyType.query:
        return null;
    }
  }

  _ResolvedRequestPayload _resolveRequestPayload({
    Map<String, dynamic>? baseQueryParams,
  }) {
    final queryParams =
        Map<String, dynamic>.from(baseQueryParams ?? _queryParams);
    final effectiveBodyType = _resolveEffectiveBodyType();

    dynamic requestBody = _rawBody;
    if (_rawBody == null && _bodyParams.isNotEmpty) {
      switch (effectiveBodyType) {
        case RequestBodyType.query:
          queryParams.addAll(_bodyParams);
          requestBody = null;
          break;
        case RequestBodyType.json:
        case RequestBodyType.formData:
        case RequestBodyType.urlEncoded:
        case RequestBodyType.auto:
          requestBody = _bodyParams;
          break;
      }
    }

    return _ResolvedRequestPayload(
      queryParams: queryParams,
      body: requestBody,
      contentType: _resolveContentType(effectiveBodyType),
    );
  }

  adapter.NetworkAdapter _requireAdapter() {
    final adapter = _rxNet.getAdapter();
    if (adapter == null) {
      throw NetworkException("NetworkAdapter is not initialized", null);
    }
    return adapter;
  }

  Stream<List<int>> _trackUploadProgress(
    Stream<List<int>> source, {
    required void Function(int chunkLength) onChunk,
  }) async* {
    await for (final chunk in source) {
      onChunk(chunk.length);
      yield chunk;
    }
  }

  Stream<List<int>>? _extractByteStream(dynamic data) {
    if (data is Stream<List<int>>) {
      return data;
    }
    if (data is Stream<Uint8List>) {
      return data;
    }
    if (data is dio.ResponseBody) {
      return data.stream;
    }
    if (data is Uint8List) {
      return Stream<List<int>>.value(data);
    }
    if (data is List<int>) {
      return Stream<List<int>>.value(data);
    }
    return null;
  }

  int? _parseContentRangeStart(String? contentRange) {
    if (contentRange == null) {
      return null;
    }

    final match =
        RegExp(r'bytes\s+(\d+)-(\d+)/(\d+|\*)').firstMatch(contentRange);
    if (match == null) {
      return null;
    }

    return int.tryParse(match.group(1)!);
  }

  int? _parseContentRangeTotal(String? contentRange) {
    if (contentRange == null) {
      return null;
    }

    final match =
        RegExp(r'bytes\s+(\d+)-(\d+)/(\d+|\*)').firstMatch(contentRange);
    if (match == null) {
      return null;
    }

    final total = match.group(3);
    if (total == null || total == '*') {
      return null;
    }

    return int.tryParse(total);
  }

  int _resolveBreakpointDownloadTotal(
    AdapterResponse response, {
    required bool isResumed,
    required int downloaded,
  }) {
    final totalFromRange = _parseContentRangeTotal(
      response.getHeader(HttpHeaders.contentRangeHeader),
    );
    if (totalFromRange != null && totalFromRange > 0) {
      return totalFromRange;
    }

    final contentLength = int.tryParse(
      response.getHeader(HttpHeaders.contentLengthHeader) ?? '',
    );
    if (contentLength != null && contentLength >= 0) {
      return isResumed ? downloaded + contentLength : contentLength;
    }

    return -1;
  }

  bool _isCancelledStreamError(Object error) {
    if (error is AdapterException) {
      return error.type == AdapterExceptionType.cancel;
    }
    if (error is dio.DioException) {
      return error.type == dio.DioExceptionType.cancel;
    }
    return false;
  }

  // ==================== 核心请求方法 -  ====================

  /// 执行请求的核心方法
  Future<RxResult<T>> _doRequest({bool cache = false}) async {
    final url = _buildFinalUrl();
    final payload = _resolveRequestPayload();

    try {
      LogUtil.v('$url, jsonConvert: ${_jsonTransformation != null}');

      // 构建 AdapterRequest
      final adapterRequest = _buildAdapterRequest(
        url: url,
        queryParams: payload.queryParams,
        data: payload.body,
        contentType: payload.contentType,
      );

      // 使用适配器发送请求
      final adapter = _requireAdapter();
      final AdapterResponse<dynamic> response =
          await adapter.request(adapterRequest);

      onResponse?.call(response);
      var responseData = response.data;

      if (response.isSuccess) {
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

        // 缓存处理 - 使用 await 确保数据写入完成
        if (cache) {
          await _saveCacheData(responseData);
        }

        return RxResult(value: data, model: SourcesType.net);
      } else {
        throw NetworkException(
            "Request failed with status code ${response.statusCode}", null);
      }
    } on AdapterException catch (e) {
      LogUtil.v('Request error: $e');
      if (e.type == AdapterExceptionType.cancel) {
        throw CancellationException("Request was cancelled", e);
      }
      throw NetworkException(e.message, e);
    } catch (e, s) {
      LogUtil.v('Request error: $e\n$s');
      if (e is RxError) {
        throw e;
      }
      throw NetworkException("Request failed: $e", e);
    }
  }

  /// 保存缓存数据
  Future<void> _saveCacheData(dynamic responseData) async {
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

    String cacheKey =
        NetUtils.getCacheKeyFromPath(_path, allParams, allIgnoreKeys);

    final map = <String, dynamic>{
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': responseData
    };
    await _rxNet.getDatabase()?.put(cacheKey, jsonEncode(map));
  }

  /// 读取缓存
  Future<RxResult<T>> _readCache() async {
    final database = _rxNet.getDatabase();
    if (database == null) {
      throw CacheException("Cache not available");
    }

    try {
      await database.ready;
    } catch (error) {
      throw CacheException("Cache not available", error);
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

    final cacheKey =
        NetUtils.getCacheKeyFromPath(_path, allParams, allIgnoreKeys);
    final cacheData = await database.get(cacheKey);

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
    // LogUtil.v("缓存数据时效:${_cacheInvalidationTime} || now - timestamp ：${now - timestamp }");
    if (now - timestamp >
        (_cacheInvalidationTime ?? _rxNet.getCacheInvalidationTime())) {
      LogUtil.v("缓存数据:超时效");
      throw CacheException("Cache expired");
    }
    if (dataValue != null) {
      return _parseLocalData(dataValue);
    } else {
      throw CacheException("Cache is empty");
    }
  }

  Future<RxResult<T>> _parseLocalData(dynamic cacheValue) async {
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
  void execute(
      {Success<T>? success, Failure? failure, Completed? completed}) {
    executeStream().listen((result) {
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
  Future<RxResult<T>> request() async {
    return await executeStream().first;
  }

  /// Stream方式（支持轮询）
  Stream<RxResult<T>> executeStream() async* {
    if (TextUtil.isEmpty(_path)) {
      yield RxResult.error(
          Exception("The request path cannot be empty path:$_path"));
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
          yield* _networkRequestStream(shouldCache: false);
          break;
        case CacheMode.FIRST_USE_CACHE_THEN_REQUEST:
          try {
            final cacheResult = await _readCache();
            yield cacheResult;
          } catch (e) {
            // Cache errors are ignored, proceed to network.
          }
          yield* _networkRequestStream(shouldCache: true);
          break;
        case CacheMode.REQUEST_FAILED_READ_CACHE:
          bool networkSucceeded = false;
          await for (final netResult
              in _networkRequestStream(shouldCache: true)) {
            if (netResult.isSuccess) {
              networkSucceeded = true;
            }
            yield netResult;
          }
          if (!networkSucceeded) {
            try {
              final cacheResult = await _readCache();
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
              final cacheResult = await _readCache();
              yield cacheResult;
              yieldedFromCache = true;
            } catch (e) {
              // Cache failed, proceed to network.
            }
          }
          //缓存超时间-失效，执行新请求
          if (!yieldedFromCache) {
            yield* _networkRequestStream(shouldCache: true);
          }
          break;
        case CacheMode.ONLY_CACHE:
          try {
            final cacheResult = await _readCache();
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

  Stream<RxResult<T>> _networkRequestStream(
      {required bool shouldCache}) async* {
    int attempt = 0;
    bool success = false;
    final effectiveRetryCount = _retryPolicy?.maxRetries ?? _retryCount;
    do {
      attempt++;
      try {
        final result = await _doRequest(cache: shouldCache);
        yield result;
        success = true;
        break;
      } catch (e) {
        yield RxResult.error(e);
        if (attempt <= effectiveRetryCount) {
          final delay = _retryPolicy != null
              ? _retryPolicy!.getDelay(attempt - 1)
              : _retryInterval;
          await Future.delayed(delay);
        }
      }
    } while (attempt <= effectiveRetryCount && !success);
  }

  // ==================== 下载上传方法 ====================

  /// 下载文件（Future 版本，支持 async/await）
  //    final result = await RxNet.get()
  //     .setPath("https://example.com/file.zip")
  //     .downloadFile(savePath: "/path/to/save/file.zip");
  //       if (result.isSuccess) {
  //       print("下载成功: ${result.value}");
  //   }

  Future<RxResult<String>> downloadFile({
    required String savePath,
    adapter.ProgressCallback? onReceiveProgress,
  }) async {
    if (!(await _checkNetWork())) {
      return RxResult.error(NetworkException("Network not available"));
    }

    final url = _buildFinalUrl();
    final payload = _resolveRequestPayload();
    final file = File(savePath);

    try {
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }

      final adapterRequest = _buildAdapterRequest(
        url: url,
        queryParams: payload.queryParams,
        data: payload.body,
        contentType: payload.contentType,
      );

      final adapter = _requireAdapter();
      final response = await adapter.download(
        adapterRequest,
        savePath,
        onProgress: (received, total) {
          onReceiveProgress?.call(received, total > 0 ? total : received);
        },
      );

      onResponse?.call(response);
      if (response.isSuccess) {
        return RxResult(value: savePath, model: SourcesType.net);
      } else {
        throw NetworkException(
            "Download failed with status code ${response.statusCode}", null);
      }
    } on AdapterException catch (e) {
      if (e.type == AdapterExceptionType.cancel) {
        throw CancellationException("Download was cancelled", e);
      }
      throw NetworkException(e.message, e);
    } catch (e) {
      if (e is RxError) rethrow;
      throw NetworkException("Download failed: $e", e);
    }
  }

  /// 下载文件（回调版本，保留向后兼容）
  void download({
    required String savePath,
    adapter.ProgressCallback? onReceiveProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
  }) async {
    if (!(await _checkNetWork())) {
      failure?.call(NetworkException("Network not available"));
      completed?.call();
      return;
    }

    final url = _buildFinalUrl();
    final payload = _resolveRequestPayload();
    final file = File(savePath);

    try {
      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }

      // 构建 AdapterRequest
      final adapterRequest = _buildAdapterRequest(
        url: url,
        queryParams: payload.queryParams,
        data: payload.body,
        contentType: payload.contentType,
      );

      // 使用适配器下载文件
      final adapter = _requireAdapter();
      final response = await adapter.download(
        adapterRequest,
        savePath,
        onProgress: (received, total) {
          onReceiveProgress?.call(received, total > 0 ? total : received);
        },
      );

      onResponse?.call(response);
      if (response.isSuccess) {
        success?.call(savePath, SourcesType.net);
      } else {
        failure?.call(response.data);
      }
    } on AdapterException catch (e) {
      failure?.call(e);
    } catch (e) {
      failure?.call(e);
    } finally {
      completed?.call();
    }
  }

  /// 断点下载
  void breakPointDownload({
    required String savePath,
    adapter.ProgressCallback? onReceiveProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
    Function()? cancelCallback,
  }) async {
    if (!(await _checkNetWork())) {
      failure?.call(NetworkException("Network not available"));
      completed?.call();
      return;
    }

    final file = File(savePath);

    try {
      final url = _buildFinalUrl();
      final payload = _resolveRequestPayload();

      if (!file.parent.existsSync()) {
        file.parent.createSync(recursive: true);
      }

      final requestedStart = file.existsSync() ? file.lengthSync() : 0;
      final headers = _buildHeaders();
      if (requestedStart > 0) {
        headers[HttpHeaders.rangeHeader] = 'bytes=$requestedStart-';
      }

      // 构建 AdapterRequest，内部会自动使用 stream 响应类型
      final adapterRequest = _buildAdapterRequest(
        url: url,
        queryParams: payload.queryParams,
        data: payload.body,
        headers: headers,
        contentType: payload.contentType,
        responseType: ResponseType.stream,
      );

      // 使用适配器发送请求
      final adapter = _requireAdapter();
      final response = await adapter.request(adapterRequest);
      onResponse?.call(response);

      final stream = _extractByteStream(response.data);
      if (stream == null) {
        throw NetworkException(
            'Breakpoint download requires a byte stream response', null);
      }

      final contentRange = response.getHeader(HttpHeaders.contentRangeHeader);
      final isResumed = requestedStart > 0 &&
          response.statusCode == HttpStatus.partialContent &&
          _parseContentRangeStart(contentRange) == requestedStart;
      var downloaded = isResumed ? requestedStart : 0;
      final total = _resolveBreakpointDownloadTotal(
        response,
        isResumed: isResumed,
        downloaded: downloaded,
      );

      final raf = file.openSync(
        mode: isResumed ? FileMode.append : FileMode.write,
      );
      try {
        await for (final chunk in stream) {
          raf.writeFromSync(chunk);
          downloaded += chunk.length;
          onReceiveProgress?.call(
            downloaded,
            total > 0 ? total : downloaded,
          );
        }
      } catch (error) {
        if (_isCancelledStreamError(error)) {
          cancelCallback?.call();
          return;
        }
        rethrow;
      } finally {
        await raf.close();
      }

      if (total > 0 && downloaded > total) {
        onReceiveProgress?.call(total, total);
      }
      success?.call(file, SourcesType.net);
    } on AdapterException catch (error) {
      if (error.type == AdapterExceptionType.cancel) {
        cancelCallback?.call();
      } else if (error.type == AdapterExceptionType.response &&
          error.statusCode == HttpStatus.requestedRangeNotSatisfiable) {
        final localLength = file.existsSync() ? file.lengthSync() : 0;
        final total = _parseContentRangeTotal(
          error.response?.getHeader(HttpHeaders.contentRangeHeader),
        );
        if (total != null && total == localLength) {
          onReceiveProgress?.call(total, total);
          success?.call(file, SourcesType.net);
        } else {
          failure?.call(error);
        }
      } else {
        failure?.call(error);
      }
    } catch (e) {
      failure?.call(e);
    } finally {
      completed?.call();
    }
  }

  // /// 上传文件（Future 版本，支持 async/await）
  // final result = await RxNet.post()
  //     .setPath("/api/upload")
  //     .setBodyParam("file", multipartFile)
  //     .asFormData()
  //     .uploadFile();
  // if (result.isSuccess) {
  // print("上传成功: ${result.value}");
  // }
  Future<RxResult<T>> uploadFile({
    adapter.ProgressCallback? onSendProgress,
  }) async {
    if (!(await _checkNetWork())) {
      return RxResult.error(NetworkException("Network not available"));
    }

    final url = _buildFinalUrl();
    final payload = _resolveRequestPayload();

    try {
      final adapterRequest = _buildAdapterRequest(
        url: url,
        queryParams: payload.queryParams,
        data: payload.body,
        contentType: payload.contentType,
      );

      final adapter = _requireAdapter();
      final response = await adapter.upload(
        adapterRequest,
        onProgress: onSendProgress,
      );

      onResponse?.call(response);
      if (response.isSuccess) {
        T data;
        if (_jsonTransformation != null) {
          data = await _jsonTransformation!.call(response.data) as T;
        } else {
          data = response.data as T;
        }
        return RxResult(value: data, model: SourcesType.net);
      } else {
        throw NetworkException(
            "Upload failed with status code ${response.statusCode}", null);
      }
    } on AdapterException catch (e) {
      if (e.type == AdapterExceptionType.cancel) {
        throw CancellationException("Upload was cancelled", e);
      }
      throw NetworkException(e.message, e);
    } catch (e) {
      if (e is RxError) rethrow;
      throw NetworkException("Upload failed: $e", e);
    }
  }

  /// 上传文件（回调版本，保留向后兼容）
  void upload({
    adapter.ProgressCallback? onSendProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
  }) async {
    if (!(await _checkNetWork())) {
      failure?.call(NetworkException("Network not available"));
      completed?.call();
      return;
    }

    final url = _buildFinalUrl();
    final payload = _resolveRequestPayload();

    try {
      final adapterRequest = _buildAdapterRequest(
        url: url,
        queryParams: payload.queryParams,
        data: payload.body,
        contentType: payload.contentType,
      );

      // 使用适配器上传文件
      final adapter = _requireAdapter();
      final response = await adapter.upload(
        adapterRequest,
        onProgress: onSendProgress,
      );

      onResponse?.call(response);
      if (response.isSuccess) {
        success?.call(response.data, SourcesType.net);
      } else {
        failure?.call(response.data);
      }
    } on AdapterException catch (e) {
      failure?.call(e);
    } catch (e) {
      failure?.call(e);
    } finally {
      completed?.call();
    }
  }

  /// 断点上传
  void breakPointUpload({
    required String filePath,
    adapter.ProgressCallback? onSendProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
    Function()? cancelCallback,
    int? start,
  }) async {
    if (!(await _checkNetWork())) {
      failure?.call(NetworkException("Network not available"));
      completed?.call();
      return;
    }

    final url = _buildFinalUrl();
    final payload = _resolveRequestPayload();
    final file = File(filePath);

    try {
      if (!file.existsSync()) {
        throw FileSystemException('Upload file does not exist', filePath);
      }

      final fileSize = file.lengthSync();
      var progress = start ?? 0;
      if (progress < 0 || progress > fileSize) {
        throw RangeError.range(progress, 0, fileSize, 'start');
      }

      if (progress > 0) {
        onSendProgress?.call(progress, fileSize);
      }

      if (progress == fileSize) {
        onSendProgress?.call(fileSize, fileSize);
        success?.call(file, SourcesType.net);
        return;
      }

      // 添加 Content-Range 头部
      final headers = _buildHeaders();
      headers[HttpHeaders.contentLengthHeader] = '${fileSize - progress}';
      headers['Content-Range'] = 'bytes $progress-${fileSize - 1}/$fileSize';

      final data = _trackUploadProgress(
        file.openRead(progress, fileSize),
        onChunk: (chunkLength) {
          progress += chunkLength;
          onSendProgress?.call(progress, fileSize);
        },
      );

      // 构建 AdapterRequest，内部会复用统一参数解析逻辑
      final adapterRequest = _buildAdapterRequest(
        url: url,
        queryParams: payload.queryParams,
        data: data,
        headers: headers,
        contentType: payload.contentType,
      );

      // 使用适配器发送请求
      final adapter = _requireAdapter();
      final response = await adapter.request(adapterRequest);
      onResponse?.call(response);

      final responseStream = _extractByteStream(response.data);
      if (responseStream != null) {
        try {
          await responseStream.drain<void>();
        } catch (error) {
          if (_isCancelledStreamError(error)) {
            cancelCallback?.call();
            return;
          }
          rethrow;
        }
      }

      if (response.isSuccess) {
        success?.call(file, SourcesType.net);
      } else {
        failure?.call(response.data);
      }
    } on AdapterException catch (error) {
      if (error.type == AdapterExceptionType.cancel) {
        cancelCallback?.call();
      } else {
        failure?.call(error);
      }
    } catch (e) {
      failure?.call(e);
    } finally {
      completed?.call();
    }
  }

  /// 获取内容长度（兼容方法）
  Future<String?> getContentLength(AdapterResponse<dynamic> response) async {
    try {
      return response.getHeader(HttpHeaders.contentRangeHeader) ??
          response.getHeader(HttpHeaders.contentLengthHeader);
    } catch (e) {
      return null;
    }
  }
}

class _ResolvedRequestPayload {
  const _ResolvedRequestPayload({
    required this.queryParams,
    required this.body,
    required this.contentType,
  });

  final Map<String, dynamic> queryParams;
  final dynamic body;
  final String? contentType;
}
