import 'package:rxnet_plus/rxnet_lib.dart';


/// author:郑再红
/// email:1096877329@qq.com
/// date:2026-08-07 9:37
/// describe: RxNet 网络请求配置类
/// 支持 Builder 模式和直接构造两种方式。
/// ## 使用示例
///
/// ```dart
/// // 方式1：直接构造
/// final config = RxNetConfig(
///   baseUrl: "https://api.example.com",
///   cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
///   interceptors: [RxNetLogAdapterInterceptor()],
/// );
/// await RxNet.init(config: config);
///
/// // 方式2：Builder 模式
/// final config = RxNetConfig.builder()
///   .baseUrl("https://api.example.com")
///   .cacheMode(CacheMode.FIRST_USE_CACHE_THEN_REQUEST)
///   .addInterceptor(RxNetLogAdapterInterceptor())
///   .build();
/// await RxNet.init(config: config);
///
/// ```
const int _defaultCacheInvalidationTime = 365 * 24 * 60 * 60 * 1000;

class RxNetConfig {
  /// 服务端基础地址
  final String baseUrl;

  /// 网络适配器（DioAdapter、HttpAdapter、MockAdapter 等）
  final NetworkAdapter? adapter;

  /// 缓存目录路径（可选）
  final String? cachePath;

  /// 缓存文件名
  final String cacheName;

  /// 数据库名称
  final String databaseName;

  /// 缓存策略
  final CacheMode cacheMode;

  /// 拦截器列表
  final List<AdapterInterceptor>? interceptors;

  /// 是否开启系统日志
  final bool systemLog;

  /// 是否为调试模式
  final bool isDebug;

  /// 网络检测回调
  ///The network detects a callback-external implementation
  final CheckNetWork? baseCheckNet;

  /// 生成缓存时忽略的参数 key 列表
  final List<String>? ignoreCacheKeys;

  /// 多环境基础服务地址
  final Map<String, dynamic>? baseUrlEnv;

  /// 缓存时效（毫秒），默认 1 年
  final int cacheInvalidationTime;

  /// 缓存最大条目数（0 表示不限制，默认 0）
  ///
  /// 当缓存条目数超过此限制时，按 [cacheEvictionPolicy] 策略淘汰。
  /// ```dart
  /// final config = RxNetConfig(
  ///   baseUrl: "https://api.example.com",
  ///   cacheMaxSize: 500,
  ///   cacheEvictionPolicy: CacheEvictionPolicy.lru,
  /// );
  /// ```
  final int cacheMaxSize;

  /// 缓存淘汰策略（默认 [CacheEvictionPolicy.none]）
  ///
  /// 配合 [cacheMaxSize] 使用，当缓存超过最大条目数时触发淘汰。
  final CacheEvictionPolicy cacheEvictionPolicy;

  /// 调试窗口宽度
  final double debugWindowWidth;

  /// 调试窗口高度
  final double debugWindowHeight;

  /// 适配器无关的全局请求默认配置（推荐）
  ///
  /// 所有适配器（DioAdapter、HttpAdapter、MockAdapter）共享此配置。
  /// 请求级参数优先级高于此全局默认值。
  ///
  /// ```dart
  /// final config = RxNetConfig(
  ///   baseUrl: "https://api.example.com",
  ///   adapterBaseOptions: AdapterBaseOptions(
  ///     connectTimeout: Duration(seconds: 10),
  ///     receiveTimeout: Duration(seconds: 30),
  ///     headers: {'Authorization': 'Bearer token'},
  ///     contentType: 'application/json',
  ///   ),
  /// );
  /// await RxNet.init(config: config);
  /// ```
  final AdapterBaseOptions? adapterBaseOptions;

  const RxNetConfig({
    required this.baseUrl,
    this.adapter,
    this.adapterBaseOptions,
    this.cachePath,
    this.cacheName = 'network_cache',
    this.databaseName = 'rxnet_cache.db',
    this.cacheMode = CacheMode.ONLY_REQUEST,
    this.interceptors,
    this.systemLog = false,
    this.isDebug = true,
    this.baseCheckNet,
    this.ignoreCacheKeys,
    this.baseUrlEnv,
    this.cacheInvalidationTime = _defaultCacheInvalidationTime,
    this.cacheMaxSize = 0,
    this.cacheEvictionPolicy = CacheEvictionPolicy.none,
    this.debugWindowWidth = 800,
    this.debugWindowHeight = 600,
  });

  /// 创建 Builder 实例
  static RxNetConfigBuilder builder() => RxNetConfigBuilder();

  /// 复制并修改配置
  RxNetConfig copyWith({
    String? baseUrl,
    NetworkAdapter? adapter,
    AdapterBaseOptions? adapterBaseOptions,
    String? cachePath,
    String? cacheName,
    String? databaseName,
    CacheMode? cacheMode,
    List<AdapterInterceptor>? interceptors,
    bool? systemLog,
    bool? isDebug,
    CheckNetWork? baseCheckNet,
    List<String>? ignoreCacheKeys,
    Map<String, dynamic>? baseUrlEnv,
    int? cacheInvalidationTime,
    int? cacheMaxSize,
    CacheEvictionPolicy? cacheEvictionPolicy,
    double? debugWindowWidth,
    double? debugWindowHeight,
  }) {
    return RxNetConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      adapter: adapter ?? this.adapter,
      adapterBaseOptions: adapterBaseOptions ?? this.adapterBaseOptions,
      cachePath: cachePath ?? this.cachePath,
      cacheName: cacheName ?? this.cacheName,
      databaseName: databaseName ?? this.databaseName,
      cacheMode: cacheMode ?? this.cacheMode,
      interceptors: interceptors ?? this.interceptors,
      systemLog: systemLog ?? this.systemLog,
      isDebug: isDebug ?? this.isDebug,
      baseCheckNet: baseCheckNet ?? this.baseCheckNet,
      ignoreCacheKeys: ignoreCacheKeys ?? this.ignoreCacheKeys,
      baseUrlEnv: baseUrlEnv ?? this.baseUrlEnv,
      cacheInvalidationTime: cacheInvalidationTime ?? this.cacheInvalidationTime,
      cacheMaxSize: cacheMaxSize ?? this.cacheMaxSize,
      cacheEvictionPolicy: cacheEvictionPolicy ?? this.cacheEvictionPolicy,
      debugWindowWidth: debugWindowWidth ?? this.debugWindowWidth,
      debugWindowHeight: debugWindowHeight ?? this.debugWindowHeight,
    );
  }

  @override
  String toString() {
    return 'RxNetConfig(baseUrl: $baseUrl, cacheMode: $cacheMode)';
  }
}

/// RxNetConfig Builder 类
/// 
/// 提供流式 API 来构建 RxNetConfig 实例。
///
/// ```dart
/// final config = RxNetConfig.builder()
///   .baseUrl("https://api.example.com")
///   .adapter(DioAdapter())
///   .cacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
///   .addInterceptor(RxNetLogAdapterInterceptor())
///   .cacheInvalidationTime(60 * 1000) // 1 分钟
///   .build();
/// ```
class RxNetConfigBuilder {
  String _baseUrl = '';
  NetworkAdapter? _adapter;
  AdapterBaseOptions? _adapterBaseOptions;
  String? _cachePath;
  String _cacheName = 'network_cache';
  String _databaseName = 'rxnet_cache.db';
  CacheMode _cacheMode = CacheMode.ONLY_REQUEST;
  final List<AdapterInterceptor> _interceptors = [];
  bool _systemLog = false;
  bool _isDebug = true;
  CheckNetWork? _baseCheckNet;
  List<String>? _ignoreCacheKeys;
  Map<String, dynamic>? _baseUrlEnv;
  int _cacheInvalidationTime = _defaultCacheInvalidationTime;
  int _cacheMaxSize = 0;
  CacheEvictionPolicy _cacheEvictionPolicy = CacheEvictionPolicy.none;
  double _debugWindowWidth = 800;
  double _debugWindowHeight = 600;

  /// 设置基础 URL
  RxNetConfigBuilder baseUrl(String url) {
    _baseUrl = url;
    return this;
  }

  /// 设置网络适配器
  RxNetConfigBuilder adapter(NetworkAdapter adapter) {
    _adapter = adapter;
    return this;
  }


  /// 设置适配器无关的全局请求默认配置（推荐）
  ///
  /// ```dart
  /// .baseOptions(AdapterBaseOptions(
  ///   connectTimeout: Duration(seconds: 10),
  ///   receiveTimeout: Duration(seconds: 30),
  ///   headers: {'Authorization': 'Bearer token'},
  ///   contentType: 'application/json',
  /// ))
  /// ```
  RxNetConfigBuilder baseOptions(AdapterBaseOptions options) {
    _adapterBaseOptions = options;
    return this;
  }

  /// 设置缓存目录路径
  RxNetConfigBuilder cachePath(String path) {
    _cachePath = path;
    return this;
  }

  /// 设置缓存文件名
  RxNetConfigBuilder cacheName(String name) {
    _cacheName = name;
    return this;
  }

  /// 设置数据库名称
  RxNetConfigBuilder databaseName(String name) {
    _databaseName = name;
    return this;
  }

  /// 设置缓存策略
  RxNetConfigBuilder cacheMode(CacheMode mode) {
    _cacheMode = mode;
    return this;
  }

  /// 添加拦截器
  RxNetConfigBuilder addInterceptor(AdapterInterceptor interceptor) {
    _interceptors.add(interceptor);
    return this;
  }

  /// 设置拦截器列表（覆盖）
  RxNetConfigBuilder interceptors(List<AdapterInterceptor> interceptors) {
    _interceptors.clear();
    _interceptors.addAll(interceptors);
    return this;
  }

  /// 开启系统日志
  RxNetConfigBuilder systemLog(bool enable) {
    _systemLog = enable;
    return this;
  }

  /// 设置调试模式
  RxNetConfigBuilder debug(bool enable) {
    _isDebug = enable;
    return this;
  }

  /// 设置网络检测回调
  RxNetConfigBuilder checkNetwork(CheckNetWork check) {
    _baseCheckNet = check;
    return this;
  }

  /// 设置忽略缓存的参数 key
  RxNetConfigBuilder ignoreCacheKeys(List<String> keys) {
    _ignoreCacheKeys = keys;
    return this;
  }

  /// 设置多环境基础 URL
  RxNetConfigBuilder baseUrlEnv(Map<String, dynamic> env) {
    _baseUrlEnv = env;
    return this;
  }

  /// 设置缓存时效（毫秒）
  RxNetConfigBuilder cacheInvalidationTime(int milliseconds) {
    _cacheInvalidationTime = milliseconds;
    return this;
  }

  /// 设置缓存最大条目数（0 表示不限制）
  RxNetConfigBuilder cacheMaxSize(int size) {
    _cacheMaxSize = size;
    return this;
  }

  /// 设置缓存淘汰策略
  RxNetConfigBuilder cacheEvictionPolicy(CacheEvictionPolicy policy) {
    _cacheEvictionPolicy = policy;
    return this;
  }

  /// 设置调试窗口大小
  RxNetConfigBuilder debugWindowSize(double width, double height) {
    _debugWindowWidth = width;
    _debugWindowHeight = height;
    return this;
  }

  /// 构建 RxNetConfig 实例
  RxNetConfig build() {
    return RxNetConfig(
      baseUrl: _baseUrl,
      adapter: _adapter,
      adapterBaseOptions: _adapterBaseOptions,
      cachePath: _cachePath,
      cacheName: _cacheName,
      databaseName: _databaseName,
      cacheMode: _cacheMode,
      interceptors: _interceptors.isEmpty ? null : List.unmodifiable(_interceptors),
      systemLog: _systemLog,
      isDebug: _isDebug,
      baseCheckNet: _baseCheckNet,
      ignoreCacheKeys: _ignoreCacheKeys,
      baseUrlEnv: _baseUrlEnv,
      cacheInvalidationTime: _cacheInvalidationTime,
      cacheMaxSize: _cacheMaxSize,
      cacheEvictionPolicy: _cacheEvictionPolicy,
      debugWindowWidth: _debugWindowWidth,
      debugWindowHeight: _debugWindowHeight,
    );
  }
}
