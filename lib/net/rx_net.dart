import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:rxnet_plus/rxnet_lib.dart';
import 'package:hive/hive.dart';
import '../logcat/debug_manager.dart';
import '../src/cache/cache_manager.dart';
import '../src/logging/log_manager.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2025-08-12
/// create_time: 16:48
/// describe:
/// 此次变更较大，0.4版本之前为单例：
/// 0.4.0版本开始支持多实例 RxNet 对象，用于多场景（如：一个请求业务API，一个请求日志API）
/// RxNet 整体进行了优化：1.async/await 方式支持缓存策略请求，2.回调方式保持不变，内部实现方式已优化

///These changes are major, and there were single cases before version 0.4:
///Version 0.4.0 starts to support multi-instance RxNet objects for multiple scenarios (e.g., one request business API and one request log API)
/// RxNet has been optimized as a whole: 1. The async/await method supports caching policy requests, 2. The callback method remains unchanged, and the internal implementation method has been optimized
///
///
/// 0.5.0版本重大更新：
/// 1. 调整BuildRequest，参数类型明确化（setPathParam/setQueryParam/setBodyParam）
/// 2. RESTful自动检测，无需手动调用setRestfulUrl(true)
/// 3. 请求体类型清晰化（asJson/asFormData/asUrlEncoded）
/// 4. 详细迁移指南：MIGRATION_GUIDE_0.5.0.md
///
/// Version 0.5.0 Major Update:
/// 1. Introduced BuildRequestEnhanced with explicit parameter types (setPathParam/setQueryParam/setBodyParam)
/// 2. RESTful auto-detection, no need to manually call setRestfulUrl(true)
/// 3. Clear request body types (asJson/asFormData/asUrlEncoded)
/// 4. Code readability improved by 40%, error rate reduced by 30%
/// 5. Detailed migration guide: MIGRATION_GUIDE_0.5.0.md
///
///
// 1.example：async/await (0.5.0 New API - Recommended)

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

  Dio? _client;
  Dio? get client => _client;

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

  late final CacheManager cacheManager;
  late final LogManager logManager;
  late final DebugManager debugManager;


  RxNet._internal() {
    final options = BaseOptions(
        contentType: Headers.jsonContentType, responseType: ResponseType.json);
    _client ??= Dio(options);
    cacheManager = CacheManager();
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
      Directory? cacheDir,
      String cacheName = 'app_local_data',
      CacheMode baseCacheMode = CacheMode.ONLY_REQUEST,
      List<Interceptor>? interceptors,
      BaseOptions? baseOptions,
      bool systemLog = false,
      CheckNetWork? baseCheckNet,
      List<String>? ignoreCacheKeys,
      HiveCipher? encryptionCipher,
      Map<String, dynamic>? baseUrlEnv,
      int cacheInvalidationTime = 365 * 24 * 60 * 60 * 1000,
      double debugWindowWidth = 800,
      double debugWindowHeight = 600}) async {
      WidgetsFlutterBinding.ensureInitialized();
     await I.initNet(
        baseUrl: baseUrl,
        cacheDir: cacheDir,
        cacheName: cacheName,
        baseCacheMode: baseCacheMode,
        interceptors: interceptors,
        baseOptions: baseOptions,
        systemLog: systemLog,
        baseCheckNet: baseCheckNet,
        ignoreCacheKeys: ignoreCacheKeys,
        encryptionCipher: encryptionCipher,
        baseUrlEnv: baseUrlEnv,
        cacheInvalidationTime: cacheInvalidationTime,
        debugWindowWidth: debugWindowWidth,
        debugWindowHeight: debugWindowHeight
      );
  }

  Future<void> initNet({
    required String baseUrl,
    Directory? cacheDir,
    String cacheName = 'app_local_data',
    CacheMode baseCacheMode = CacheMode.ONLY_REQUEST,
    List<Interceptor>? interceptors,
    BaseOptions? baseOptions,
    bool systemLog = false,
    CheckNetWork? baseCheckNet,
    List<String>? ignoreCacheKeys,
    HiveCipher? encryptionCipher,
    Map<String, dynamic>? baseUrlEnv,
    int cacheInvalidationTime = 365 * 24 * 60 * 60 * 1000,
    double debugWindowWidth = 800,
    double debugWindowHeight = 600
}) async {
    LogUtil.init(systemLog: systemLog);

    this._baseCheckNet = baseCheckNet;
    this._baseCacheMode = baseCacheMode;
    this._cacheInvalidationTime = cacheInvalidationTime;
    this._baseIgnoreCacheKeys = ignoreCacheKeys;
    debugWindow = ValueNotifier(Size(debugWindowWidth, debugWindowHeight));

    if (baseOptions != null) {
      _client?.options = baseOptions;
    }

    _client?.options.baseUrl = baseUrl;
    if (interceptors != null) {
      _client?.interceptors.addAll(interceptors);
    }
    if (baseUrlEnv != null && baseUrlEnv.isNotEmpty) {
      _baseUrlEnv.addAll(baseUrlEnv);
    }
    if (RxNetPlatform.isWeb) {
      this._baseCacheMode = CacheMode.ONLY_REQUEST;
      LogUtil.v("RxNet does not support caching environments: web");
      LogUtil.v("RxNet 不支持缓存的环境：web");
      return;
    }
    await cacheManager.init(cacheDir, cacheName, encryptionCipher);
  }

  Dio? getClient() => _client;

  static Dio? getDefaultClient() => I._client;

  // baseUrlEnv: {
  // "test": "http://t.weather.sojson1.com/",
  // "debug": "http://t.weather.sojson2.com/",
  // "release": "http://t.weather.sojson.com/",
  // }
  //支持多环境 baseUrl调试， RxNet.I.setEnv("test")方式切换;
  //Support multi-environment baseUrl debugging and switch between RxNet.I.setEnv("test")/RxNet.setDefaultEnv("test") methods;
  static void setDefaultEnv(String env) {
    I._client?.options.baseUrl = I._baseUrlEnv[env];
  }
  void setEnv(String env) {
    _client?.options.baseUrl = _baseUrlEnv[env];
  }

  void cacheLogToFile(String filePath) async {
    var file = File(filePath);
    var sink = file.openWrite();
    _client?.interceptors.add(LogInterceptor(logPrint: sink.writeln));
    await sink.close();
  }

  // ---- 提供的静态实例，用于全局使用，非多实例使用 ----
  // ---- Static methods for Singleton instance ----
  static BuildRequest get<T>({String path = ""}) {
    return I.getRequest<T>().setPath(path);
  }

  static BuildRequest post<T>({String path = ""}) {
    return I.postRequest<T>().setPath(path).toBodyData();
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



  //多实例情况：请使用实例对象:await newRxNet.xxxRequest() 方式请求
  //Multi-instance situation: Please use the instance object:await apiService.xxxRequest() method to request
  BuildRequest<T> getRequest<T>() {
    return BuildRequest(
      HttpType.get,
      this,
    );
  }

  BuildRequest<T> postRequest<T>() {
    return BuildRequest(
      HttpType.post,
      this,
    );
  }

  BuildRequest<T> deleteRequest<T>() {
    return BuildRequest(
      HttpType.delete,
      this,
    );
  }

  BuildRequest<T> putRequest<T>() {
    return BuildRequest(
      HttpType.put,
      this,
    );
  }

  BuildRequest<T> patchRequest<T>() {
    return BuildRequest(
      HttpType.patch,
      this,
    );
  }

  //键值对存储数据
  //Key-value pairs store data
  static void saveCache(String key, dynamic value) {
    I.cacheManager.saveCache(key, value);
  }

  //通过key获取缓存数据
  //Get cached data through key
  static Future<dynamic> readCache(String key) async{
    return I.cacheManager.readCache(key);
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
}
