import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

import '../logcat/debug_manager.dart';
import '../logcat/log_manager.dart';
import '../utils/rx_net_database.dart';
import 'concurrent/zip_request_impl.dart' as zip_impl;

/// author: ZhengZaiHong
/// email: 1096877329@qq.com
/// RxNet Plus - Flutter 网络请求库
/// 一个全平台兼容（Android / iOS / Windows / Linux / macOS / Web / HarmonyOS）的
/// 网络请求框架，支持缓存策略、多环境切换、并发请求等特性。
///
/// ## 快速开始
///
/// ```dart
/// // 1. 初始化（使用 RxNetConfig）
/// await RxNet.init(config:RxNetConfig(
///   baseUrl: "https://api.example.com",
///   cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
///   interceptors: [RxNetLogAdapterInterceptor()],
/// ));
///
/// // RESTful 请求 / RESTful request
/// await RxNet.get()
///   .setPath("/api/users/{id}/posts")
///   .setPathParam("id", "123")
///   .setQueryParam("page", 1)
///   .request();
///
/// // POST JSON 数据 / POST JSON data
/// await RxNet.post()
///   .setPath("/api/user")
///   .setBodyParams({"name": "John", "age": 25})
///   .asJson()
///   .request();
///
/// // 文件上传 / File upload
/// await RxNet.post()
///   .setPath("/api/upload")
///   .setBodyParam("file", multipartFile)
///   .asFormData()
///   .request();
/// ```
///
/// ## 初始化方式
///
/// ```dart
/// // 方式1：直接构造 RxNetConfig
/// await RxNet.init(config:RxNetConfig(
///   baseUrl: "https://api.example.com",
///   cacheMode: CacheMode.FIRST_USE_CACHE_THEN_REQUEST,
///   cacheMaxSize: 500,
///   cacheEvictionPolicy: CacheEvictionPolicy.lru,
///   interceptors: [RxNetLogAdapterInterceptor()],
/// ));
///
/// // 方式2：Builder 模式
/// await RxNet.init(config:RxNetConfig.builder()
///   .baseUrl("https://api.example.com")
///   .adapter(DioAdapter())
///   .cacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
///   .addInterceptor(RxNetLogAdapterInterceptor())
///   .cacheInvalidationTime(60 * 1000)
///   .cacheMaxSize(200)
///   .cacheEvictionPolicy(CacheEvictionPolicy.lfu)
///   .build());
/// ```
///
/// 示例：
/// async-await 方式
///
// void requestData() async {
//   final data = await RxNet.get()
//       .setPath("/api/weather/city/{id}")
//       .setPathParam("id", "101030100")  // Path parameter
//       .setQueryParam("lang", "zh")      // Query parameter
//       .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
//       .setJsonConvert(WeatherInfo.fromJson)
//       .request<WeatherInfo>();
//
//   setState(() {
//     var result = data.value;
//     content = jsonEncode(result?.toJson());
//     sourcesType = data.model;
//   });
// }

/// 回调方式
// void request()  {
//   RxNet.get()
//       .setPath('/api/weather/city/{id}')
//       .setPathParam("id", "101030100")  // Path parameter
//       .setQueryParam("lang", "zh")      // Query parameter
//       .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
//       .setJsonConvert(WeatherInfo.fromJson)
//       .setRetryCount(2, interval: const Duration(seconds: 7))
//       .execute<WeatherInfo>(
//        success: (data, source) {
//         setState(() {
//           content = jsonEncode(data);
//           sourcesType = source;
//         });
//       },
//       failure: (e) {
//         setState(() {
//           content = "empty data";
//         });
//       },
//       completed: (){
//         //Callback that is always executed after a request succeeds or fails, used to cancel loading animations, etc.
//       });
// }

/// ## 多环境切换
/// ```dart
/// await RxNet.init(config:RxNetConfig(
///   baseUrl: "https://api.example.com",
///   baseUrlEnv: {
///     'dev': 'https://dev.api.example.com',
///     'test': 'https://test.api.example.com',
///     'release': 'https://api.example.com',
///   },
/// ));
/// RxNet.setDefaultEnv('test');
/// ```
///
/// ## 并发请求
///
/// ```dart
/// final results = await RxNet.zipRequest([
///   ZipRequest<UserInfo>(request: () async => getUser(), tag: 'user'),
///   ZipRequest<UserSettings>(request: () async => getSettings(), tag: 'settings'),
/// ]);
/// ```
///

class RxNet {

  //单实例 -- 通常一个项目一个 RxNet 实例即可
  //Single instance-usually one RxNet instance per project is enough
  static final RxNet I = RxNet._internal();

  NetworkAdapter? _adapter;
  NetworkAdapter? get adapter => _adapter;

  RxNetConfig? _rxNetConfig;
  String get baseUrl => _rxNetConfig!.baseUrl;

  // 数据库实例 - 直接使用 RxNetDataBase
  // Database instance - directly use RxNetDataBase
  RxNetDataBase? _database;

  //全局请求头
  //global request header
  Map<String, dynamic> _globalHeader = {};

  /// 缓存管理器，提供缓存的读写、清理等高级操作
  late RxNetCache cacheManager;
  
  late final LogManager logManager;
  late final DebugManager debugManager;


  RxNet._internal() {
    logManager = LogManager();
    debugManager = DebugManager();
    cacheManager = RxNetCache();
  }

  //多实例时使用，通常不需要
  static RxNet create() {
    return RxNet._internal();
  }

  /// 使用 RxNetConfig 初始化（推荐方式）
  /// 
  /// ```dart
  /// await RxNet.init(config:RxNetConfig(
  ///   baseUrl: "https://api.example.com",
  ///   cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
  ///   interceptors: [RxNetLogAdapterInterceptor()],
  /// ));
  /// ```
  static Future<void> init({required RxNetConfig config}) async {
    if (!kIsWeb) {
      try {
        WidgetsFlutterBinding.ensureInitialized();
      } catch (_) {}
    }
    await I.initNet(config: config);
  }

  Future<void> initNet({required RxNetConfig config}) async {
    LogUtil.init(systemLog: config.systemLog,debug: config.isDebug);
    this._rxNetConfig = config;
    debugWindow = ValueNotifier(Size(config.debugWindowWidth, config.debugWindowHeight));

    // 如果提供了自定义适配器，使用它；否则使用默认的 DioAdapter
    // If custom adapter provided, use it; otherwise use default DioAdapter
    if (adapter != null) {
      _adapter = adapter;
    } else if (_adapter == null) {
      // 只在 _adapter 为 null 时创建默认适配器
      // Only create default adapter when _adapter is null
      _adapter = DioAdapter();
    }
    if (config.adapterBaseOptions != null) {
      _adapter?.applyBaseOptions(config.adapterBaseOptions!);
    }
    // 设置 baseUrl（所有适配器统一处理）
    _adapter?.setBaseUrl(baseUrl);
    
    // 添加适配器拦截器（适用于所有适配器）
    if (config.interceptors != null && config.interceptors!.isNotEmpty) {
      for (var interceptor in config.interceptors!) {
        _adapter?.addInterceptor(interceptor);
      }
    }
    
    _database = RxNetDataBase();
    // 立即绑定数据库引用，确保 init 期间的缓存操作也能通过 cacheManager 访问
    cacheManager.setDatabase(_database!);
    cacheManager.setCacheInvalidationTime(config.cacheInvalidationTime);
    cacheManager.setMaxCacheSize(config.cacheMaxSize);
    cacheManager.setEvictionPolicy(config.cacheEvictionPolicy);
    await _database!.init(
      databasePath: config.cachePath,
      databaseName: config.databaseName,
      cacheName: config.cacheName,
    );
  }

  NetworkAdapter? getAdapter() => _adapter;

  static NetworkAdapter? getDefaultAdapter() => I._adapter;

  // baseUrlEnv: {
  // "test": "http://t.weather.sojson1.com/",
  // "debug": "http://t.weather.sojson2.com/",
  // "release": "http://t.weather.sojson.com/",
  // }
  //支持多环境 baseUrl调试， RxNet.I.setEnv("test")方式切换;
  //Support multi-environment baseUrl debugging and switch between RxNet.I.setEnv("test")/RxNet.setDefaultEnv("test") methods;
  static void setDefaultEnv(String env) {
    final baseUrl = I._rxNetConfig?.baseUrlEnv?[env];
    if (baseUrl != null) {
      I._adapter?.setBaseUrl(baseUrl);
    }
  }
  
  void setEnv(String env) {
    final baseUrl = this._rxNetConfig?.baseUrlEnv?[env];
    if (baseUrl != null) {
      _adapter?.setBaseUrl(baseUrl);
    }
  }

  // ---- 提供的静态实例，用于全局使用，非多实例使用 ----
  // ---- Static methods for Singleton instance ----
  static BuildRequest<T> get<T>({String? path})=>I.getRequest<T>().setPath(path);
  static BuildRequest<T> post<T>({String? path})=>I.postRequest<T>().setPath(path);
  static BuildRequest<T> delete<T>({String? path})=>I.deleteRequest<T>().setPath(path);
  static BuildRequest<T> put<T>({String? path})=>I.putRequest<T>().setPath(path);
  static BuildRequest<T> patch<T>({String? path})=>I.patchRequest<T>().setPath(path);
  static BuildRequest<T> head<T>({String? path})=>I.headRequest<T>().setPath(path);
  static BuildRequest<T> options<T>({String? path})=>I.optionsRequest<T>().setPath(path);



  //多实例情况：请使用实例对象:await newRxNet.xxxRequest() 方式请求
  //Multi-instance situation: Please use the instance object:await apiService.xxxRequest() method to request
  BuildRequest<T> getRequest<T>()=>BuildRequest(HttpMethod.GET, this);
  BuildRequest<T> postRequest<T>() => BuildRequest(HttpMethod.POST,this);
  BuildRequest<T> deleteRequest<T>() => BuildRequest(HttpMethod.DELETE,this);
  BuildRequest<T> putRequest<T>() => BuildRequest(HttpMethod.PUT,this);
  BuildRequest<T> patchRequest<T>() => BuildRequest(HttpMethod.PATCH, this);
  BuildRequest<T> headRequest<T>() => BuildRequest(HttpMethod.HEAD, this);
  BuildRequest<T> optionsRequest<T>() => BuildRequest(HttpMethod.OPTIONS, this);

  //键值对存储数据 — 委托给 cacheManager
  static Future<void> saveCache(String key, dynamic value) async {
    await I.cacheManager.put(key, value);
  }

  //通过key获取缓存数据 — 委托给 cacheManager
  static Future<T?> readCache<T>(String key) async {
    return await I.cacheManager.get<T>(key);
  }
  
  //获取数据库实例
  //Get database instance
  RxNetDataBase? getDatabase() {
    return _database;
  }
  
  //获取默认数据库实例
  //Get default database instance
  static RxNetDataBase? getDefaultDatabase() {
    return I._database;
  }

  //默认实列的全局请求头，你也可以在拦截器中进行处理
  static void setGlobalHeaders(Map<String, dynamic> header) {
     I._globalHeader = header;
  }

  static Map<String, dynamic> getGlobalHeaders() {
    return I._globalHeader;
  }

  //多实例的全局请求头，你也可以在拦截器中进行处理
  //Global request headers, you can also process them in interceptors
  void setHeaders(Map<String, dynamic> header) {
    _globalHeader = header;
  }

  Map<String, dynamic> getHeaders() {
    return _globalHeader;
  }

  CheckNetWork? getCheckNetWork() {
    return this._rxNetConfig?.baseCheckNet;
  }

  CacheMode? getBaseCacheMode() {
    return this._rxNetConfig?.cacheMode;
  }

  int getCacheInvalidationTime() {
    return this._rxNetConfig!.cacheInvalidationTime;
  }

  List<String>? getIgnoreCacheKeys() {
    return this._rxNetConfig?.ignoreCacheKeys;
  }

  void setCollectLogs(bool collect) {
    logManager.setCollectLogs(collect);
  }

  ValueNotifier<List<String>> get logsNotifier => logManager.logsNotifier;

  static void showDebugWindow(BuildContext context){
    I.debugManager.showDebugWindow(context);
  }

  static ValueNotifier<Size> debugWindow = ValueNotifier(const Size(800, 600));

  /// 并发执行多个基于回调的请求并返回聚合结果。
  /// Executes multiple callback-based requests concurrently and returns aggregated results.
  static Future<ZipResults> zipRequest(
    List<ZipRequest> requests, {
    bool eagerError = true,
    CancelToken? cancelToken,
    Duration? timeout,
  }) {
    return I.zipRequestInstance(requests, 
      eagerError: eagerError, 
      cancelToken: cancelToken,
      timeout: timeout,
    );
  }
  
  /// 实例方法,用于执行具有多实例支持的并发请求。
  /// Instance method for executing concurrent requests with multi-instance support.
  /// 
  /// final results = await userService.zipRequestInstance([
  ///   ZipRequest<UserInfo>(request: getUserAsync, tag: 'user'),
  ///   ZipRequest<UserSettings>(request: getSettingsAsync, tag: 'settings'),
  /// ]);
  /// Parameters:
  /// - [requests]: List of [ZipRequest] instances to execute
  /// - [eagerError]: If `true`, fail immediately on first error (default: true)
  /// - [cancelToken]: Optional [CancelToken] to cancel all requests
  /// - [timeout]: Optional timeout duration for all requests
  ///
  /// See also:
  /// - [zipRequest] for the static method
  /// - [getInstance] for creating named instances
  Future<ZipResults> zipRequestInstance(
    List<ZipRequest> requests, {
    bool eagerError = true,
    CancelToken? cancelToken,
    Duration? timeout,
  }) async {
    return zip_impl.zipRequest(requests, 
      eagerError: eagerError, 
      cancelToken: cancelToken,
      timeout: timeout,
    );
  }
}
