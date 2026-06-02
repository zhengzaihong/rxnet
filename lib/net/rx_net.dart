import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxnet_plus/rxnet_lib.dart';
import '../logcat/debug_manager.dart';
import '../src/logging/log_manager.dart';
import '../utils/rx_net_database.dart';
import 'concurrent/zip_request.dart';
import 'concurrent/zip_results.dart';
import 'concurrent/zip_request_impl.dart' as zip_impl;

///
/// RxNet Plus - Flutter 网络请求库 / Flutter Network Request Library
/// 
/// author: ZhengZaiHong
/// email: 1096877329@qq.com
/// date: 2025-08-12
/// ============================================================================
/// 版本历史 / Version History
/// ============================================================================
/// 
/// 📦 Version 0.6.0 (2026-04-23) - 适配器架构重构 / Adapter Architecture Refactoring
/// ============================================================================
/// 
/// 🎯 核心变更 / Core Changes:
/// 
/// 1. **可插拔适配器架构 / Pluggable Adapter Architecture**
///    - 引入 NetworkAdapter 接口，支持多种 HTTP 客户端库
///    - Introduced NetworkAdapter interface, supporting multiple HTTP client libraries
///    - 三种内置适配器：DioAdapter（默认）、HttpAdapter（轻量级）、MockAdapter（测试）
///    - Three built-in adapters: DioAdapter (default), HttpAdapter (lightweight), MockAdapter (testing)
///    - 支持自定义适配器实现
///    - Support for custom adapter implementations
/// 
/// 2. **统一的拦截器系统 / Unified Interceptor System**
///    - AdapterInterceptor 接口，与具体网络库解耦
///    - AdapterInterceptor interface, decoupled from specific network libraries
///    - 拦截器可在不同适配器间复用
///    - Interceptors can be reused across different adapters
///    - RxNetLogAdapterInterceptor 替代 RxNetLogInterceptor
///    - RxNetLogAdapterInterceptor replaces RxNetLogInterceptor
/// 
/// 3. **改进的取消令牌 / Improved Cancel Token**
///    - 新的 CancelToken 类，独立于 Dio
///    - New CancelToken class, independent of Dio
///    - 支持回调通知和状态查询
///    - Support for callback notifications and status queries
/// 
/// 4. **枚举类型优化 / Enum Type Optimization**
///    - HttpMethod 和 ResponseType 使用大写枚举值
///    - HttpMethod and ResponseType use uppercase enum values
///    - 更符合 Dart 3.0+ 规范
///    - More compliant with Dart 3.0+ specifications
/// 
/// 🔄 迁移指南 / Migration Guide:
/// 详见 MIGRATION_GUIDE_0.6.0.md
/// See MIGRATION_GUIDE_0.6.0.md for details
/// 
/// 💡 使用示例 / Usage Examples:
/// 
/// ```dart
/// // 1. 使用默认适配器（DioAdapter）
/// // Using default adapter (DioAdapter)
/// await RxNet.init(
///   baseUrl: "https://api.example.com",
///   interceptors: [RxNetLogAdapterInterceptor()],
/// );
/// 
/// // 2. 使用轻量级适配器（HttpAdapter）
/// // Using lightweight adapter (HttpAdapter)
/// final api = RxNet.create();
/// await api.initNet(
///   baseUrl: "https://api.example.com",
///   adapter: HttpAdapter(),
/// );
/// 
/// // 3. 使用测试适配器（MockAdapter）
/// // Using test adapter (MockAdapter)
/// final mockAdapter = MockAdapter();
/// mockAdapter.setMockResponse('/api/user', mockResponse);
/// await api.initNet(adapter: mockAdapter);
/// ```
/// 
/// ============================================================================
/// 📦 Version 0.5.0 (2025-10-03) - API 优化 / API Optimization
/// ============================================================================
/// 
/// 🎯 核心变更 / Core Changes:
/// 
/// 1. **参数类型明确化 / Explicit Parameter Types**
///    - setPathParam() - RESTful 路径参数 / RESTful path parameters
///    - setQueryParam() - URL 查询参数 / URL query parameters
///    - setBodyParam() - 请求体参数 / Request body parameters
/// 
/// 2. **RESTful 自动检测 / RESTful Auto-Detection**
///    - 自动识别路径中的 {placeholder}
///    - Automatically recognize {placeholder} in paths
///    - 无需手动调用 setRestfulUrl(true)
///    - No need to manually call setRestfulUrl(true)
/// 
/// 3. **请求体类型清晰化 / Clear Request Body Types**
///    - asJson() - JSON 格式 / JSON format
///    - asFormData() - FormData 格式 / FormData format
///    - asUrlEncoded() - URL 编码格式 / URL-encoded format
/// 
/// 💡 使用示例 / Usage Examples:
/// 
/// ```dart
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
/// 🔄 迁移指南 / Migration Guide:
/// 详见 MIGRATION_GUIDE_0.5.0.md 或 迁移指南_0.5.0.md
/// See MIGRATION_GUIDE_0.5.0.md or 迁移指南_0.5.0.md
/// 
/// ============================================================================
/// 📦 Version 0.4.3 及之前 / Version 0.4.3 and Earlier
/// ============================================================================
/// 
/// 🎯 核心特性 / Core Features:
/// 
/// 1. **多实例支持 / Multi-Instance Support** (0.4.0+)
///    - 支持创建多个 RxNet 实例
///    - Support for creating multiple RxNet instances
///    - 适用于多场景（业务 API、日志 API 等）
///    - Suitable for multiple scenarios (business API, logging API, etc.)
/// 
/// 2. **缓存策略 / Cache Strategy**
///    - 支持多种缓存模式
///    - Support for multiple cache modes
///    - async/await 和回调方式都支持缓存
///    - Both async/await and callback methods support caching
/// 
/// 3. **基础 API / Basic API**
///    - setParam() - 设置参数 / Set parameter
///    - setParams() - 批量设置参数 / Set multiple parameters
///    - setRestfulUrl(true) - 启用 RESTful / Enable RESTful
/// 
/// 💡 使用示例 / Usage Examples (0.4.3 API - 仍然支持 / Still Supported):
/// 
/// ```dart
/// // 基础请求 / Basic request
/// await RxNet.get()
///   .setPath("api/weather")
///   .setParam("city", "101030100")
///   .setRestfulUrl(true)
///   .request();
/// 
/// // POST 请求 / POST request
/// await RxNet.post()
///   .setPath("/api/user")
///   .setParams({"name": "John", "age": 25})
///   .toBodyData()
///   .request();
/// ```
/// 
/// ============================================================================
/// 📚 更多文档 / More Documentation
/// ============================================================================
/// 
/// - API 文档 / API Documentation: README.md
/// - 迁移指南 / Migration Guides: MIGRATION_GUIDE_*.md
/// - 更新日志 / Changelog: CHANGELOG.md
/// - 示例代码 / Examples: example/lib/
/// 
/// ============================================================================

// ==================== 0.6.0 推荐用法 / 0.6.0 Recommended Usage ====================

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

// 2.example：callback (0.5.0 New API - Recommended)

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

// 3.example: POST with JSON body (0.5.0 New API)

// void createUser() async {
//   final data = await RxNet.post()
//       .setPath("/api/user")
//       .setBodyParams({
//         "name": "John",
//         "age": 25,
//         "email": "john@example.com"
//       })
//       .asJson()  // Explicitly specify JSON format
//       .setJsonConvert(User.fromJson)
//       .request<User>();
//
//   if (data.isSuccess) {
//     print("User created: ${data.value}");
//   }
// }

// 4.example: File upload (0.5.0 New API)

// void uploadFile() async {
//   final file = await MultipartFile.fromFile(filePath);
//   
//   final data = await RxNet.post()
//       .setPath("/api/upload/avatar/{userId}")
//       .setPathParam("userId", "123")
//       .setBodyParam("file", file)
//       .setBodyParam("description", "Avatar")
//       .asFormData()  // Explicitly specify FormData format
//       .request();
// }

// 5.example: Complex query with mixed parameters (0.5.0 New API)

// void searchProducts() async {
//   final data = await RxNet.get()
//       .setPath("/api/categories/{categoryId}/products")
//       .setPathParam("categoryId", "electronics")  // Path parameter
//       .setQueryParams({                           // Query parameters
//         "keyword": "phone",
//         "minPrice": 100,
//         "maxPrice": 1000,
//         "page": 1,
//         "size": 20
//       })
//       .setIgnoreCacheKey("page")
//       .setCacheMode(CacheMode.FIRST_USE_CACHE_THEN_REQUEST)
//       .request();
// }

// ==================== 0.4.3 Old API (Still Supported) ====================

// 1.example：async/await (0.4.3 Old API)

// void requestData() async {
//   final data = await RxNet.get()
//       .setPath("api/weather")
//       .setParam("city", "101030100")
//       .setRestfulUrl(true)
//       .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
//       .setJsonConvert(NewWeatherInfo.fromJson)
//       .request();
//
//   setState(() {
//     var result = data.value;
//     content = jsonEncode(result?.toJson());
//     sourcesType = data.model;
//   });
// }

// 2.example：callback (0.4.3 Old API)

// void request()  {
//   // 公共请求头 public request header
//   // RxNet.I.setHeaders({
//   //   "User-Agent": "PostmanRuntime-ApipostRuntime/1.1.0",
//   //   "Cache-Control": "no-cache",
//   //   "Accept": "*",
//   //   "Accept-Encoding": "gzip, deflate, br",
//   //   "Connection": "keep-alive",
//   // });

//   RxNet.get()
//       .setPath('api/weather/')
//       .setParam("city", "101030100")
//       .setRestfulUrl(true) // http://t.weather.sojson.com/api/weather/city/101030100
//   //  .setCancelToken(tag)
//       .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
//       .setJsonConvert(NewWeatherInfo.fromJson)
//       .setRetryCount(2)  //重试次数
//       .setCacheInvalidationTime(1000*10)  //毫秒
//   //  .setRequestIgnoreCacheTime(true) //忽略缓存时效直接请求
//       .execute<NewWeatherInfo>(
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
//         //请求成功或失败后始终都会执行的回调，用于取消加载动画等
//       });
// }

//多实例情况： 创建一个新的 RxNet 实例--为这个实例进行独立的初始化配置
//Multi-instance scenario: Create a new instance of RxNet-perform independent initialization configuration for this instance

// final apiService = RxNet.create();
// await apiService.initNet(baseUrl: "https://api.yourdomain.com");
// final response = await apiService.getRequest()
//     .setPath("/users/1")
//     .setParam("xx","xxx")
//     .setJsonConvert(NewWeatherInfo.fromJson)
//     .request();
// final weatherInfo = response.value;

class RxNet {

  //单实例 -- 通常一个项目一个 RxNet 实例即可
  //Single instance-usually one RxNet instance per project is enough
  static final RxNet I = RxNet._internal();

  NetworkAdapter? _adapter;
  NetworkAdapter? get adapter => _adapter;

  // 存储 baseUrl，供 BuildRequest 使用
  String _baseUrl = '';
  String get baseUrl => _baseUrl;

  //网络检测到回调-外部自行实现
  //The network detects a callback-external implementation
  CheckNetWork? _baseCheckNet;
  //缓存策略
  //cache policy
  CacheMode? _baseCacheMode;

  //缓存时效，初始化默认一年
  //Cache aging, initialization default one year
  int _cacheInvalidationTime = 0;
  //全局请求头
  //global request header
  Map<String, dynamic> _globalHeader = {};

  //生成缓存的参数中需要忽略的关键key
  //Key keys that need to be ignored among the parameters of the generated cache
  List<String>? _baseIgnoreCacheKeys;

  //多环境的基础服务地址
  //Basic service addresses for multiple environments
  Map<String, dynamic> _baseUrlEnv = {};

  // 数据库实例 - 直接使用 RxNetDataBase
  // Database instance - directly use RxNetDataBase
  RxNetDataBase? _database;
  
  late final LogManager logManager;
  late final DebugManager debugManager;


  RxNet._internal() {
    logManager = LogManager();
    debugManager = DebugManager();
  }

  //多实例时使用，通常不需要
  //Used for multiple instances, usually not required
  static RxNet create() {
    return RxNet._internal();
  }

  /**
      中文：
      baseUrl:服务端基础地址
      cacheDir:缓存目录
      cacheName:缓存文件
      baseCacheMode:缓存策略
      interceptors:自定义的拦截器
      systemLog:是否使用系统自带的打印
      baseCheckNet:网络检测，外部自行实现，网络不通不发起请求
      ignoreCacheKeys:网络检测，外部自行实现
      encryptionCipher:数据加密，不传默认即可
      baseUrlEnv:多环境的基础服务地址
      cacheInvalidationTime:缓存时效：默认1年
      debugWindowWidth:调试窗口默认宽
      debugWindowHeight:调试窗口默认高

      English：
      baseUrl: basic address of the server
      cacheDir: Cache directory
      cacheName: Cache file
      baseCacheMode: caching strategy
      interceptors: Custom interceptors
      systemLog: Whether to use the system's own printing
      baseCheckNet: Network detection, implemented externally, no request is initiated when the network is blocked
      ignoreCacheKeys: Network detection, externally implemented
      encryptionCipher: Data encryption, you can only pass it by default
      baseUrlEnv: Basic service addresses for multiple environments
      cacheInvalidationTime: Cache aging: Default 1 year
      debugWindowWidth: Default width of debugging window
      debugWindowHeight: The debugging window defaults to high
   */

  static Future<void> init(
      {required String baseUrl,
      NetworkAdapter? adapter,
      String? cachePath,
      String cacheName = 'rxnet_cache.db',
      CacheMode baseCacheMode = CacheMode.ONLY_REQUEST,
      List<AdapterInterceptor>? interceptors,
      BaseOptions? baseOptions,
      bool systemLog = false,
      CheckNetWork? baseCheckNet,
      List<String>? ignoreCacheKeys,
      Map<String, dynamic>? baseUrlEnv,
      int cacheInvalidationTime = 365 * 24 * 60 * 60 * 1000,
      double debugWindowWidth = 800,
      double debugWindowHeight = 600}) async {
      WidgetsFlutterBinding.ensureInitialized();
     await I.initNet(
        baseUrl: baseUrl,
        adapter: adapter,
        cachePath: cachePath,
        cacheName: cacheName,
        baseCacheMode: baseCacheMode,
        interceptors: interceptors,
        baseOptions: baseOptions,
        systemLog: systemLog,
        baseCheckNet: baseCheckNet,
        ignoreCacheKeys: ignoreCacheKeys,
        baseUrlEnv: baseUrlEnv,
        cacheInvalidationTime: cacheInvalidationTime,
        debugWindowWidth: debugWindowWidth,
        debugWindowHeight: debugWindowHeight
      );
  }

  Future<void> initNet({
    required String baseUrl,
    NetworkAdapter? adapter,
    String? cachePath,
    String cacheName = 'network_cache',
    String databaseName = 'rxnet_cache.db',
    CacheMode baseCacheMode = CacheMode.ONLY_REQUEST,
    List<AdapterInterceptor>? interceptors,
    BaseOptions? baseOptions,
    bool systemLog = false,
    bool isDebug = kDebugMode,
    CheckNetWork? baseCheckNet,
    List<String>? ignoreCacheKeys,
    Map<String, dynamic>? baseUrlEnv,
    int cacheInvalidationTime = 365 * 24 * 60 * 60 * 1000,
    double debugWindowWidth = 800,
    double debugWindowHeight = 600
}) async {
    LogUtil.init(systemLog: systemLog,debug: isDebug);

    // 存储 baseUrl
    this._baseUrl = baseUrl;
    this._baseCheckNet = baseCheckNet;
    this._baseCacheMode = baseCacheMode;
    this._cacheInvalidationTime = cacheInvalidationTime;
    this._baseIgnoreCacheKeys = ignoreCacheKeys;
    debugWindow = ValueNotifier(Size(debugWindowWidth, debugWindowHeight));

    // 如果提供了自定义适配器，使用它；否则使用默认的 DioAdapter
    // If custom adapter provided, use it; otherwise use default DioAdapter
    if (adapter != null) {
      _adapter = adapter;
    } else if (_adapter == null) {
      // 只在 _adapter 为 null 时创建默认适配器
      // Only create default adapter when _adapter is null
      final options = baseOptions ?? BaseOptions(
        contentType: Headers.jsonContentType,
      );
      _adapter = DioAdapter.withOptions(options);
    }

    // 如果是 DioAdapter，配置 Dio 选项
    if (_adapter is DioAdapter) {
      final dioAdapter = _adapter as DioAdapter;
      
      if (baseOptions != null) {
        dioAdapter.dio.options = baseOptions;
      }
      
      dioAdapter.dio.options.baseUrl = baseUrl;
    }
    
    // 如果是 HttpAdapter，baseUrl 将在请求构建时处理
    // If HttpAdapter, baseUrl will be handled during request building
    
    // 添加适配器拦截器（适用于所有适配器）
    if (interceptors != null && interceptors.isNotEmpty) {
      for (var interceptor in interceptors) {
        _adapter?.addInterceptor(interceptor);
      }
    }
    
    if (baseUrlEnv != null && baseUrlEnv.isNotEmpty) {
      _baseUrlEnv.addAll(baseUrlEnv);
    }
    
    _database = RxNetDataBase();
    await RxNetDataBase.initDatabase(
      databasePath: cachePath,
      databaseName: databaseName,
      cacheName: cacheName,
    );
  }

  NetworkAdapter? getAdapter() => _adapter;

  static NetworkAdapter? getDefaultAdapter() => I._adapter;

  // 保持向后兼容性 - 已废弃，建议使用 getAdapter()
  @Deprecated('Use getAdapter() instead')
  Dio? getClient() {
    if (_adapter is DioAdapter) {
      return (_adapter as DioAdapter).dio;
    }
    return null;
  }

  @Deprecated('Use getDefaultAdapter() instead')
  static Dio? getDefaultClient() {
    if (I._adapter is DioAdapter) {
      return (I._adapter as DioAdapter).dio;
    }
    return null;
  }

  // baseUrlEnv: {
  // "test": "http://t.weather.sojson1.com/",
  // "debug": "http://t.weather.sojson2.com/",
  // "release": "http://t.weather.sojson.com/",
  // }
  //支持多环境 baseUrl调试， RxNet.I.setEnv("test")方式切换;
  //Support multi-environment baseUrl debugging and switch between RxNet.I.setEnv("test")/RxNet.setDefaultEnv("test") methods;
  static void setDefaultEnv(String env) {
    final baseUrl = I._baseUrlEnv[env];
    if (baseUrl != null && I._adapter is DioAdapter) {
      (I._adapter as DioAdapter).dio.options.baseUrl = baseUrl;
    }
  }
  
  void setEnv(String env) {
    final baseUrl = _baseUrlEnv[env];
    if (baseUrl != null && _adapter is DioAdapter) {
      (_adapter as DioAdapter).dio.options.baseUrl = baseUrl;
    }
  }

  /// 将日志输出到文件
  /// 
  /// 注意：此方法仅在使用 DioAdapter 时有效
  /// 对于其他适配器，请使用自定义的 AdapterInterceptor
  @Deprecated('Use custom AdapterInterceptor for logging instead')
  void cacheLogToFile(String filePath) async {
    if (_adapter is DioAdapter) {
      var file = File(filePath);
      var sink = file.openWrite();
      // 使用 Dio 的 LogInterceptor（仅限 DioAdapter）
      final dioAdapter = _adapter as DioAdapter;
      final logInterceptor = LogInterceptor(logPrint: sink.writeln);
      dioAdapter.dio.interceptors.add(logInterceptor);
      await sink.close();
    } else {
      LogUtil.v('cacheLogToFile is only supported for DioAdapter');
    }
  }

  // ---- 提供的静态实例，用于全局使用，非多实例使用 ----
  // ---- Static methods for Singleton instance ----
  static BuildRequest get<T>({String path = ""}) {
    return I.getRequest<T>().setPath(path);
  }

  static BuildRequest post<T>({String path = ""}) {
    return I.postRequest<T>().setPath(path);
  }

  static BuildRequest delete<T>({String path = ""}) {
    return I.deleteRequest<T>().setPath(path);
  }

  static BuildRequest put<T>({String path = ""}) {
    return I.putRequest<T>().setPath(path);
  }

  static BuildRequest patch<T>({String path = ""}) {
    return I.patchRequest<T>().setPath(path);
  }

  static BuildRequest head<T>({String path = ""}) {
    return I.headRequest<T>().setPath(path);
  }

  static BuildRequest options<T>({String path = ""}) {
    return I.optionsRequest<T>().setPath(path);
  }



  //多实例情况：请使用实例对象:await newRxNet.xxxRequest() 方式请求
  //Multi-instance situation: Please use the instance object:await apiService.xxxRequest() method to request
  BuildRequest<T> getRequest<T>() {
    return BuildRequest(
      HttpMethod.GET,
      this,
    );
  }

  BuildRequest<T> postRequest<T>() {
    return BuildRequest(
      HttpMethod.POST,
      this,
    );
  }

  BuildRequest<T> deleteRequest<T>() {
    return BuildRequest(
      HttpMethod.DELETE,
      this,
    );
  }

  BuildRequest<T> putRequest<T>() {
    return BuildRequest(
      HttpMethod.PUT,
      this,
    );
  }

  BuildRequest<T> patchRequest<T>() {
    return BuildRequest(
      HttpMethod.PATCH,
      this,
    );
  }

  BuildRequest<T> headRequest<T>() {
    return BuildRequest(
      HttpMethod.HEAD,
      this,
    );
  }

  BuildRequest<T> optionsRequest<T>() {
    return BuildRequest(
      HttpMethod.OPTIONS,
      this,
    );
  }

  //键值对存储数据
  //Key-value pairs store data
  static Future<void> saveCache(String key, dynamic value) async {
    await I._database?.put(key, value);
  }

  //通过key获取缓存数据
  //Get cached data through key
  static Future<T?> readCache<T>(String key) async {
    return await I._database?.get<T>(key);
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
    return _baseCheckNet;
  }

  CacheMode? getBaseCacheMode() {
    return _baseCacheMode;
  }

  int getCacheInvalidationTime() {
    return _cacheInvalidationTime;
  }

  List<String>? getIgnoreCacheKeys() {
    return _baseIgnoreCacheKeys;
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
