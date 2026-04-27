import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:rxnet_plus/rxnet_lib.dart';
import 'package:rxnet_plus/src/request/request_body_type.dart';
import '../../net/type/response_type.dart' as rxnet_plus;
import '../../utils/net_utils.dart';
import '../../utils/rx_net_database.dart';
import '../adapter/network_adapter.dart' as adapter;
import '../adapter/models/adapter_request.dart' as adapter_models;
import '../adapter/cancel_token.dart' as rxnet_cancel;

///
/// BuildRequest - 网络请求构建器 / Network Request Builder
/// 
/// author: zhengzaihong
/// email: 1096877329@qq.com
/// date: 2025-08-12
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
/// 版本历史 / Version History
/// ============================================================================
/// 
/// 📦 Version 0.6.0 (2026-04-20) - 适配器架构支持 / Adapter Architecture Support
/// ----------------------------------------------------------------------------
/// 
/// 🎯 核心变更 / Core Changes:
/// 
/// 1. **适配器集成 / Adapter Integration**
///    - 重构为使用 NetworkAdapter 接口
///    - Refactored to use NetworkAdapter interface
///    - 支持多种网络库（Dio、http、自定义）
///    - Support for multiple network libraries (Dio, http, custom)
/// 
/// 2. **统一的取消令牌 / Unified Cancel Token**
///    - 使用 RxNet 的 CancelToken 替代 Dio 的 CancelToken
///    - Use RxNet's CancelToken instead of Dio's CancelToken
///    - 跨适配器的取消支持
///    - Cross-adapter cancellation support
/// 
/// 3. **改进的拦截器支持 / Improved Interceptor Support**
///    - 拦截器通过适配器执行
///    - Interceptors executed through adapters
///    - 支持请求、响应、错误拦截
///    - Support for request, response, and error interception
/// 
/// 📦 Version 0.5.0 (2025-10-03) - API 优化 / API Optimization
/// ----------------------------------------------------------------------------
/// 
/// 🎯 核心改进 / Core Improvements:
/// 
/// 1. **参数类型明确化 / Explicit Parameter Types**
///    - 引入 RequestBodyType 枚举
///    - Introduced RequestBodyType enum
///    - 分离路径参数、查询参数、Body 参数
///    - Separated path params, query params, and body params
/// 
/// 2. **RESTful 自动检测 / RESTful Auto-Detection**
///    - 自动识别路径中的 {placeholder}
///    - Automatically recognize {placeholder} in paths
///    - 无需手动调用 setRestfulUrl(true)
///    - No need to manually call setRestfulUrl(true)
/// 
/// 3. **请求体类型清晰化 / Clear Request Body Types**
///    - asJson() - JSON 格式
///    - asFormData() - FormData 格式
///    - asUrlEncoded() - URL 编码格式
/// 
/// 4. **改进的缓存键生成 / Improved Cache Key Generation**
///    - 更智能的缓存键生成逻辑
///    - Smarter cache key generation logic
///    - 支持忽略特定参数
///    - Support for ignoring specific parameters
/// 
/// 5. **统一的错误处理 / Unified Error Handling**
///    - 标准化的异常类型
///    - Standardized exception types
///    - 更清晰的错误信息
///    - Clearer error messages
/// 
/// 📦 Version 0.4.x - 初始版本 / Initial Version
/// ----------------------------------------------------------------------------
/// 
/// - 基础请求功能 / Basic request functionality
/// - 缓存支持 / Cache support
/// - 重试和轮询 / Retry and polling
/// - JSON 转换 / JSON conversion
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
/// 4. 缓存功能在 Web 平台不可用
///    Cache functionality is not available on Web platform
/// 
/// ============================================================================
/// 
class BuildRequest<T> {
  final HttpMethod _HttpMethod;
  final RxNet _rxNet;

  // 基础配置 / Basic Configuration
  rxnet_cancel.CancelToken? _cancelToken;
  String? _path;
  CacheMode? _cacheMode;

  // 参数管理 / Parameter Management
  // 优化：分离路径参数和查询参数 / Optimization: Separate path and query parameters
  Map<String, dynamic> _pathParams = {};  // RESTful 路径参数 / RESTful path parameters
  Map<String, dynamic> _queryParams = {}; // URL 查询参数 / URL query parameters
  Map<String, dynamic> _bodyParams = {};  // Body 参数 / Body parameters
  dynamic _rawBody;  // 原始 body 数据（用于自定义 body）/ Raw body data (for custom body)

  // 请求体类型 / Request Body Type
  // 新增：明确的类型控制 / New: Explicit type control
  RequestBodyType _bodyType = RequestBodyType.auto;

  // 请求头 / Request Headers
  Map<String, dynamic> _headers = {};
  bool _enableGlobalHeader = true;

  // 请求配置
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
  bool _isLoop = false;
  Duration _loopInterval = const Duration(seconds: 5);

  // JSON转换
  JsonTransformation? _jsonTransformation;

  // 回调
  CheckNetWork? checkNetWork;
  Function(AdapterResponse response)? onResponse;

  BuildRequest(this._HttpMethod, this._rxNet);

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
    if (_HttpMethod == HttpMethod.GET || _HttpMethod == HttpMethod.DELETE) {
      _queryParams[key] = value;
    } else {
      _bodyParams[key] = value;
    }
    return this;
  }

  /// 兼容旧API：setParams
  @Deprecated('使用 setPathParams/setQueryParams/setBodyParams 更明确')
  BuildRequest<T> setParams(Map<String, dynamic> params) {
    if (_HttpMethod == HttpMethod.GET || _HttpMethod == HttpMethod.DELETE) {
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

  /// 设置取消令牌
  /// 
  /// 支持两种方式：
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
      throw ArgumentError('cancelToken must be either CancelToken or dio.CancelToken');
    }
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


  BuildRequest<T> setCheckNetwork(CheckNetWork checkNetWork) {
    this.checkNetWork = checkNetWork;
    return this;
  }

  BuildRequest<T> setResponseCallBack(Function(AdapterResponse response) responseCallBack) {
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

  dio.CancelToken? getCancelToken() {
    // 为了兼容旧API，返回 null（因为我们现在使用字符串标识）
    return null;
  }


  /// 构建请求头
  Map<String, String> _buildHeaders() {
    final headers = <String, String>{};
    
    // 添加全局请求头
    if (_enableGlobalHeader) {
      _rxNet.getHeaders().forEach((key, value) {
        headers[key] = value.toString();
      });
    }
    
    // 添加自定义请求头
    _headers.forEach((key, value) {
      headers[key] = value.toString();
    });
    
    return headers;
  }

  /// 构建 AdapterRequest
  adapter_models.AdapterRequest _buildAdapterRequest({
    required String url,
    Map<String, dynamic>? queryParams,
    dynamic data,
  }) {
    // 从 RxNet 获取 baseUrl
    final baseUrl = _rxNet.baseUrl;
    
    return adapter_models.AdapterRequest(
      baseUrl: baseUrl,
      path: url,
      method: _HttpMethod,
      queryParams: queryParams ?? {},
      bodyParams: _bodyParams, // 传递 bodyParams 以便拦截器可以访问
      headers: _buildHeaders(),
      rawBody: data,
      contentType: _contentType,
      responseType: _convertResponseType(),
      sendTimeout: _sendTimeout,
      receiveTimeout: _receiveTimeout,
      cancelToken: _cancelToken, // Use the actual cancel token
    );
  }

  /// 转换 ResponseType 到 adapter ResponseType
  rxnet_plus.ResponseType _convertResponseType() {
    switch (_responseType) {
      case ResponseType.json:
        return rxnet_plus.ResponseType.json;
      case ResponseType.stream:
        return rxnet_plus.ResponseType.stream;
      case ResponseType.plain:
        return rxnet_plus.ResponseType.plain;
      case ResponseType.bytes:
        return rxnet_plus.ResponseType.bytes;
      default:
        return rxnet_plus.ResponseType.json;
    }
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
        } else if (_HttpMethod == HttpMethod.POST ||
            _HttpMethod == HttpMethod.PUT ||
            _HttpMethod == HttpMethod.PATCH) {
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
          // 对于 FormData，我们需要转换为 Map<String, dynamic>
          // 适配器会处理文件上传
          requestBody = _bodyParams;
          if (_contentType == null) {
            _contentType = ContentTypes.multipartFormData;
          }
          break;
        case RequestBodyType.urlEncoded:
          requestBody = _bodyParams;
          if (_contentType == null) {
            _contentType = ContentTypes.formUrlEncoded;
          }
          break;
        case RequestBodyType.auto:
        // GET/DELETE默认用query
          if (_HttpMethod == HttpMethod.GET || _HttpMethod == HttpMethod.DELETE) {
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

      // 构建 AdapterRequest
      final adapterRequest = _buildAdapterRequest(
        url: url,
        queryParams: queryParameters,
        data: requestBody,
      );

      // 使用适配器发送请求
      final adapter = _rxNet.getAdapter();
      if (adapter == null) {
        throw NetworkException("NetworkAdapter is not initialized", null);
      }

      final AdapterResponse<dynamic> response = await adapter.request(adapterRequest);

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

        // 缓存处理 - 优化：使用更清晰的缓存键生成
        if (cache && !RxNetPlatform.isWeb) {
          _saveCacheData(responseData);
        }

        return RxResult(value: data, model: SourcesType.net);
      } else {
        throw NetworkException("Request failed with status code ${response.statusCode}", null);
      }
    } on AdapterException catch (e) {
      LogUtil.v("请求出错：$e");
      // 转换 AdapterException 到 RxError
      if (e.type == AdapterExceptionType.cancel) {
        throw CancellationException("Request was cancelled", e);
      }
      throw NetworkException(e.message, e);
    } catch (e, s) {
      LogUtil.v("请求出错：$e\n$s");
      if (e is RxError) {
        throw e;
      }
      throw NetworkException("Request failed: $e", e);
    }
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
    // LogUtil.v("缓存数据时效:${_cacheInvalidationTime} || now - timestamp ：${now - timestamp }");
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
    adapter.ProgressCallback? onReceiveProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
  }) async {
    if (!(await _checkNetWork())) {
      return;
    }

    final url = _buildFinalUrl();

    try {
      // 准备请求体
      dynamic requestBody = _rawBody;
      if (_rawBody == null && _bodyParams.isNotEmpty) {
        if (_bodyType == RequestBodyType.formData) {
          requestBody = _bodyParams;
        } else if (_bodyType == RequestBodyType.json) {
          requestBody = _bodyParams;
        }
      }

      // 构建 AdapterRequest
      final adapterRequest = _buildAdapterRequest(
        url: url,
        queryParams: _queryParams,
        data: requestBody,
      );

      // 使用适配器下载文件
      final adapter = _rxNet.getAdapter();
      if (adapter == null) {
        throw NetworkException("NetworkAdapter is not initialized", null);
      }

      final response = await adapter.download(
        adapterRequest,
        savePath,
        onProgress: (received, total) {
          if (total != -1) {
            onReceiveProgress?.call(received, total);
          }
          if (received >= total) {
            success?.call(savePath, SourcesType.net);
          }
        },
      );

      onResponse?.call(response);
      if (!response.isSuccess) {
        failure?.call(response.data);
      }
    } on AdapterException catch (e) {
      failure?.call(e);
    } catch (e) {
      failure?.call(e);
    }
    completed?.call();
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
      return;
    }

    int downloadStart = 0;
    File file = File(savePath);

    try {
      final url = _buildFinalUrl();

      if (file.existsSync()) {
        downloadStart = file.lengthSync();
      }

      // 添加 Range 头部
      final headers = _buildHeaders();
      headers["Range"] = "bytes=$downloadStart-";

      // 准备请求体
      dynamic requestBody = _rawBody;
      if (_rawBody == null && _bodyParams.isNotEmpty) {
        if (_bodyType == RequestBodyType.formData) {
          requestBody = _bodyParams;
        } else if (_bodyType == RequestBodyType.json) {
          requestBody = _bodyParams;
        }
      }

      // 构建 AdapterRequest，外部通常需要将responseType设置为 stream 响应类型
      final adapterRequest = adapter_models.AdapterRequest(
        baseUrl: _rxNet.baseUrl,
        path: url,
        method: _HttpMethod,
        queryParams: _queryParams,
        headers: headers,
        rawBody: requestBody,
        contentType: _contentType,
        responseType: _convertResponseType(),
        sendTimeout: _sendTimeout,
        receiveTimeout: _receiveTimeout,
        cancelToken: _cancelToken, // Use the actual cancel token
      );

      // 使用适配器发送请求
      final adapter = _rxNet.getAdapter();
      if (adapter == null) {
        throw NetworkException("NetworkAdapter is not initialized", null);
      }

      final response = await adapter.request(adapterRequest);
      onResponse?.call(response);

      // 处理流式响应
      if (response.data is Stream<List<int>>) {
        RandomAccessFile raf = file.openSync(mode: FileMode.append);
        Stream<Uint8List> stream = (response.data as Stream<List<int>>).map((data) => Uint8List.fromList(data));

        // 获取总大小
        final contentRange = response.getHeader('content-range');
        final total = int.tryParse(contentRange?.split('/').last ?? "0") ?? 0;

        final subscription = stream.listen((data) {
          raf.writeFromSync(data);
          downloadStart = downloadStart + data.length;
          if (total > 0 && total < downloadStart) {
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

        // 处理取消（简化版本，因为我们现在使用字符串标识）
        // 实际的取消逻辑由适配器处理
      } else {
        // 如果不是流式响应，检查是否已完成
        final contentRange = response.getHeader('content-range');
        final total = int.tryParse(contentRange?.split('/').last ?? "0") ?? 0;
        if (total <= downloadStart) {
          onReceiveProgress?.call(total, total);
          success?.call(file, SourcesType.net);
        }
      }
    } on AdapterException catch (error) {
      if (error.type == AdapterExceptionType.cancel) {
        cancelCallback?.call();
      } else {
        failure?.call(error);
      }
    } catch (e) {
      failure?.call(e);
    }

    completed?.call();
  }

  /// 上传文件
  void upload({
    adapter.ProgressCallback? onSendProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
  }) async {
    if (!(await _checkNetWork())) {
      return;
    }

    final url = _buildFinalUrl();

    try {
      // 准备请求体
      dynamic requestBody = _rawBody;
      if (_rawBody == null && _bodyParams.isNotEmpty) {
        if (_bodyType == RequestBodyType.formData) {
          requestBody = _bodyParams;
        } else if (_bodyType == RequestBodyType.json) {
          requestBody = _bodyParams;
        }
      }

      // 构建 AdapterRequest
      final adapterRequest = _buildAdapterRequest(
        url: url,
        queryParams: _queryParams,
        data: requestBody,
      );

      // 使用适配器上传文件
      final adapter = _rxNet.getAdapter();
      if (adapter == null) {
        throw NetworkException("NetworkAdapter is not initialized", null);
      }

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
    }
    completed?.call();
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
      return;
    }

    final url = _buildFinalUrl();

    var progress = start ?? 0;
    int fileSize = 0;
    File file = File(filePath);

    if (file.existsSync()) {
      fileSize = file.lengthSync();
    }

    var data = file.openRead(progress, fileSize);

    try {
      // 添加 Content-Range 头部
      final headers = _buildHeaders();
      headers['Content-Range'] = 'bytes $progress-${fileSize - 1}/$fileSize';

      // 构建 AdapterRequest，外部通常需要将responseType设置为 stream 响应类型
      final adapterRequest = adapter_models.AdapterRequest(
        baseUrl: _rxNet.baseUrl,
        path: url,
        method: _HttpMethod,
        queryParams: _queryParams,
        headers: headers,
        rawBody: data,
        contentType: _contentType,
        responseType: _convertResponseType(),
        sendTimeout: _sendTimeout,
        receiveTimeout: _receiveTimeout,
        cancelToken: _cancelToken, // Use the actual cancel token
      );

      // 使用适配器发送请求
      final adapter = _rxNet.getAdapter();
      if (adapter == null) {
        throw NetworkException("NetworkAdapter is not initialized", null);
      }

      final response = await adapter.request(adapterRequest);
      onResponse?.call(response);

      // 处理流式响应
      if (response.data is Stream<List<int>>) {
        Stream<Uint8List> stream = (response.data as Stream<List<int>>).map((d) => Uint8List.fromList(d));

        final subscription = stream.listen((d) {
          progress = progress + d.length;
          onSendProgress?.call(progress, fileSize);
        }, onDone: () async {
          success?.call(file, SourcesType.net);
        }, onError: (e) async {
          failure?.call(e);
        }, cancelOnError: true);
      } else {
        // 如果不是流式响应，检查是否已完成
        if (progress <= fileSize) {
          onSendProgress?.call(progress, fileSize);
          success?.call(file, SourcesType.net);
        }
      }
    } on AdapterException catch (error) {
      if (error.type == AdapterExceptionType.cancel) {
        cancelCallback?.call();
      } else {
        failure?.call(error);
      }
    } catch (e) {
      failure?.call(e);
    }

    completed?.call();
  }

  /// 获取内容长度（兼容方法）
  Future<String?> getContentLength(AdapterResponse<dynamic> response) async {
    try {
      return response.getHeader(HttpHeaders.contentRangeHeader);
    } catch (e) {
      return null;
    }
  }
}
