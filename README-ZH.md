# RxNet

[![pub package](https://img.shields.io/pub/v/rxnet_plus.svg)](https://pub.dev/packages/rxnet_plus)
[![GitHub stars](https://img.shields.io/github/stars/ZhengZaiHong/rxnet.svg?style=social)](https://github.com/ZhengZaiHong/rxnet)
[![license](https://img.shields.io/github/license/ZhengZaiHong/rxnet)](LICENSE)

Language: [English](README.md) | 简体中文

RxNet：极简易用、强大、原生风格的 Flutter 网络通信框架

RxNet 是专为 Flutter 构建的跨平台网络请求工具，贴合原生开发习惯，几乎零学习成本即可上手，支持丰富的功能组合，助你构建高性能、可维护的应用程序。

---
[使用说明文档](docs/USAGE_GUIDE.md)


## 0.7.0 更新 - 配置类、缓存淘汰、重试策略等

RxNet 0.7.0 引入了结构化配置类、高级缓存管理、智能重试策略和内置拦截器。

**0.7.0 新特性：**

- **RxNetConfig** - 清晰的配置类，支持 Builder 模式，替代冗长的参数列表
- **缓存淘汰策略** - 支持 LRU / LFU / FIFO，可配置 `cacheMaxSize`
- **RetryPolicy** - 支持指数退避、抖动等高级重试策略
- **AdapterBaseOptions** - 适配器无关的全局请求默认配置（超时、请求头等）
- **TokenRefreshInterceptor** - 401/403 自动刷新 Token，支持并发去重
- **DeduplicateInterceptor** - 可配置时间窗口内的请求去重
- **ThrottleInterceptor** - 请求限流，可配置窗口时间
- **RxResult.success()** - 保证非空的工厂方法 + `requiredValue` getter


### 历史亮点

- **0.6.x**: 可插拔适配器架构（DioAdapter、HttpAdapter、MockAdapter）
- **0.5.0**: RESTful 自动检测、参数分离、断点上传/下载

---

## 目录

- [快速开始](#快速开始)
- [RxNetConfig](#rxnetconfig)
- [缓存淘汰](#缓存淘汰)
- [重试策略](#重试策略)
- [AdapterBaseOptions](#adapterbaseoptions)
- [适配器选择](#适配器选择)
- [请求示例](#请求示例)
- [内置拦截器](#内置拦截器)
- [并发请求](#并发请求)
- [上传与下载](#上传与下载)
- [证书校验](#证书校验)
- [迁移指南](#从-06x-迁移到-070)

---

## 快速开始

### 方式一：RxNetConfig（推荐）

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
  cacheInvalidationTime: 24 * 60 * 60 * 1000,
  cacheMaxSize: 500,
  cacheEvictionPolicy: CacheEvictionPolicy.lru,
  adapterBaseOptions: AdapterBaseOptions(
    connectTimeout: Duration(seconds: 10),
    sendTimeout:  Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
  ),
  interceptors: [
    RxNetLogAdapterInterceptor(),
  ],
));
```

### 方式二：Builder 模式

```dart
await RxNet.init(config: RxNetConfig.builder()
  .baseUrl("https://api.example.com")
  .cacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
  .cacheInvalidationTime(24 * 60 * 60 * 1000)
  .cacheMaxSize(500)
  .cacheEvictionPolicy(CacheEvictionPolicy.lru)
  .baseOptions(AdapterBaseOptions(
    connectTimeout: Duration(seconds: 10),
    sendTimeout:  Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
  ))
  .addInterceptor(RxNetLogAdapterInterceptor())
  .build());
```

---

## RxNetConfig

`RxNetConfig` 是推荐的 RxNet 配置方式，提供清晰、类型安全的配置对象，支持 Builder 模式。

### 所有配置选项

```dart
final config = RxNetConfig(
  baseUrl: "https://api.example.com",          // 必填
  adapter: DioAdapter(),                        // 可选，默认 DioAdapter
  adapterBaseOptions: AdapterBaseOptions(       // 可选，全局请求默认配置
    connectTimeout: Duration(seconds: 10),
    sendTimeout:  Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
    headers: {'Authorization': 'Bearer token'},
  ),
  cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
  cacheInvalidationTime: 60 * 1000,            // 1 分钟
  cacheMaxSize: 500,                           // 最大 500 条
  cacheEvictionPolicy: CacheEvictionPolicy.lru, // LRU 淘汰
  interceptors: [RxNetLogAdapterInterceptor()],
  cachePath: '/path/to/cache',
  cacheName: 'network_cache',
  databaseName: 'rxnet_cache.db',
  ignoreCacheKeys: ['token'],
  baseUrlEnv: {'dev': 'https://dev.api.com', 'prod': 'https://api.com'},
  baseCheckNet: myCheckNetFunction,
);
```

### copyWith

```dart
final updatedConfig = config.copyWith(
  baseUrl: "https://new-api.example.com",
  cacheMaxSize: 1000,
);
```

---

## 缓存淘汰

### 缓存淘汰策略

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  cacheMaxSize: 200,
  cacheEvictionPolicy: CacheEvictionPolicy.lru,
));
```

| 策略 | 行为 |
|------|----------|
| `CacheEvictionPolicy.none` | 不淘汰（默认，向后兼容） |
| `CacheEvictionPolicy.lru` | 淘汰最久未访问的条目 |
| `CacheEvictionPolicy.lfu` | 淘汰访问次数最少的条目 |
| `CacheEvictionPolicy.fifo` | 淘汰最早创建的条目 |


### 缓存管理

```dart
final cache = RxNet.I.cacheManager;

// 保存/读取网络缓存
await cache.saveNetworkCache(path: '/api/data', params: {'page': 1}, responseData: {...});
final data = await cache.readNetworkCache(path: '/api/data', params: {'page': 1});

// 保存/读取键值缓存
await cache.put('user_token', 'abc123');
final token = await cache.get<String>('user_token');

// 清除缓存
await cache.clearAll();
await cache.clearByPrefix('/api/users');
await cache.clearByPattern(r'^/api/v\d+/');

// 查询缓存
final size = await cache.getCacheSize();
final keys = await cache.getAllKeys();
```

---

## 重试策略

### 固定间隔（默认，向后兼容）

```dart
RxNet.get()
  .setPath("/api/data")
  .setRetryCount(3, interval: Duration(seconds: 2))
  .request();
```

### 高级 RetryPolicy

```dart
// 指数退避
RxNet.get()
  .setPath("/api/data")
  .setRetryPolicy(RetryPolicy.exponentialBackoff(
    maxRetries: 3,
    baseInterval: Duration(seconds: 1),
    maxInterval: Duration(seconds: 30),
  ))
  .request();

// 指数退避 + 随机抖动（推荐用于分布式系统）
RxNet.get()
  .setPath("/api/data")
  .setRetryPolicy(RetryPolicy.exponentialBackoffWithJitter(
    maxRetries: 5,
    baseInterval: Duration(seconds: 1),
    maxInterval: Duration(seconds: 30),
  ))
  .request();
```

| 策略 | 第 1 次 | 第 2 次 | 第 3 次 | 适用场景 |
|------|---------|---------|---------|----------|
| `fixed` | 1s | 1s | 1s | 简单场景 |
| `exponentialBackoff` | 1s | 2s | 4s | 服务器过载恢复 |
| `exponentialBackoffWithJitter` | ~0.5s | ~1.5s | ~3s | 分布式系统 |

---

## AdapterBaseOptions

设置适用于所有适配器的全局请求默认配置：

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  adapterBaseOptions: AdapterBaseOptions(
    connectTimeout: Duration(seconds: 10),
    sendTimeout:  Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
    sendTimeout: Duration(seconds: 30),
    headers: {'Authorization': 'Bearer token'},
    contentType: 'application/json',
    responseType: ResponseType.json,
    followRedirects: true,
    maxRedirects: 5,
    receiveDataWhenStatusError: true,
    persistentConnection: true,
  ),
));
```

请求级参数始终优先于全局默认值

---

## 适配器选择

| 适配器 | 包 | 功能 | 取消 | 最适合 |
|--------|-----|------|------|--------|
| **DioAdapter** | `dio: ^5.8.0+1` | 所有功能、拦截器 | 真正取消（中止连接） | 生产应用（默认） |
| **HttpAdapter** | `http: ^1.2.0` | 基础 HTTP、拦截器、multipart、流式 | 伪取消（标记已取消） | 轻量级应用 |
| **MockAdapter** | 内置 | 测试、无网络 | 模拟 | 单元/集成测试 |

**默认行为：** 未指定适配器时自动使用 DioAdapter。

### 多实例

```dart
final mainApi = RxNet.create();
await mainApi.initNet(config:RxNetConfig(baseUrl: "https://api.main.com", adapter: DioAdapter()));

final analyticsApi = RxNet.create();
await analyticsApi.initNet(config:RxNetConfig(baseUrl: "https://analytics.example.com", adapter: HttpAdapter()));
```

---

## 请求示例

### 支持的请求方式

`get`、`post`、`delete`、`put`、`patch`、`head`、`options`

### 缓存模式

```dart
enum CacheMode {
  ONLY_REQUEST,                        // 不缓存，每次请求网络
  ONLY_CACHE,                          // 仅使用缓存，不请求网络
  REQUEST_FAILED_READ_CACHE,           // 先请求网络，失败后读取缓存
  FIRST_USE_CACHE_THEN_REQUEST,        // 先使用缓存，再请求网络
  CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST, // 缓存为空或过期时才请求网络
}
```

### 1. 回调模式

```dart
RxNet.get<WeatherInfo>()
  .setPath('/api/weather/city/{id}')
  .setPathParam("id", "101030100")
  .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
  .setJsonConvert(WeatherInfo.fromJson)
  .setRetryPolicy(RetryPolicy.exponentialBackoff(maxRetries: 3))
  .execute(
    success: (data, source) {
      setState(() { weather = data; });
    },
    failure: (e) {
      setState(() { error = e.toString(); });
    },
    completed: () { /* 始终执行 */ },
  );
```

### 2. async/await 模式

```dart
final result = await RxNet.get<WeatherInfo>()
  .setPath('/api/weather/city/{id}')
  .setPathParam("id", "101030100")
  .setJsonConvert(WeatherInfo.fromJson)
  .request();

if (result.isSuccess) {
  print(result.value);
}
```

### 3. Stream 流式模式

```dart
StreamSubscription? _subscription;

_subscription = RxNet.get()
  .setPath('/api/weather/city/{id}')
  .setPathParam("id", "101030100")
  .setLoop(true, interval: const Duration(seconds: 5))
  .executeStream()
  .listen((result) {
    if (result.isSuccess) { setState(() { weather = result.value; }); }
  });

// 不忘记在 dispose() 中取消
@override
void dispose() { _subscription?.cancel(); super.dispose(); }
```

---

## 内置拦截器

### TokenRefreshInterceptor

```dart
TokenRefreshInterceptor(
  tokenProvider: () async { ... },
  isUnauthorized: (error, request) => error.statusCode == 401,
  onRequestUpdated: (request, newToken) {
    return request.copyWith(headers: {...request.headers, 'Authorization': 'Bearer $newToken'});
  },
  onTokenRefreshed: (token) => currentToken = token,
);
```

### DeduplicateInterceptor

```dart
DeduplicateInterceptor(windowDuration: Duration(milliseconds: 500))
```

### ThrottleInterceptor

```dart
ThrottleInterceptor(throttleDuration: Duration(seconds: 1))
```

---

## 并发请求

### async/await 请求（推荐）

```dart
final (weather, user) = await (
  RxNet.get<Weather>().setPath('/weather').request(),
  RxNet.get<User>().setPath('/user').request(),
).wait;
```

### 回调式请求（zipRequest）

```dart
final results = await RxNet.zipRequest([
  ZipRequest<Weather>(request: ..., tag: 'weather'),
  ZipRequest<User>(request: ..., tag: 'user'),
]);
final weather = results.getRequestByTag<Weather>('weather');
```

---

## 上传与下载

```dart
// 下载
await RxNet.get().setPath("https://example.com/file.zip")
  .downloadFile(savePath: "${appDocPath}/file.zip");

// 断点下载
RxNet.get().setPath("https://example.com/large-file.zip")
  .breakPointDownload(savePath: "...", onReceiveProgress: (len, total) {});

// 断点上传
RxNet.post().setPath("/api/upload")
  .breakPointUpload(filePath: "/path/to/file.jpg", onSendProgress: (len, total) {});
```

---


## 证书校验
#### 使用 HttpAdapter（http 包方式）

```dart
import 'dart:io';
import 'package:http/io_client.dart';

// 创建带证书校验的自定义 HTTP 客户端
IOClient createPinnedClient() {
  final HttpClient httpClient = HttpClient();
  httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
    // 在这里添加您的证书校验逻辑
    // 例如：校验证书指纹
    // final der = cert.der;
    // final sha256 = sha256Convert(der);
    // const trustedFingerprint = "YOUR_SHA256_FINGERPRINT";
    // return sha256 == trustedFingerprint;
    return true; // 仅用于测试，生产环境请正确校验
  };
  return IOClient(httpClient);
}

// 使用自定义客户端创建 HttpAdapter
final httpAdapter = HttpAdapter(client: createPinnedClient());

// 使用配置好的适配器初始化 RxNet
await RxNet.init(config:RxNetConfig
  baseUrl: "https://your-api.com",
  adapter: httpAdapter,
));
```

## 从 0.6.x 迁移到 0.7.0

**务必配置RxNetConfig**

```dart
await RxNet.init(config: RxNetConfig(baseUrl: "...", cacheMode: CacheMode.ONLY_REQUEST));
```
---

## 调试窗口

```dart
RxNet.showDebugWindow(context);
```

![调试窗口](https://github.com/ZhengZaiHong/rxnet/blob/master/images/app_logcat.jpg)

## HarmonyOS 支持

![HarmonyOS](https://github.com/ZhengZaiHong/rxnet/blob/master/images/HarmonyOS-example.gif)

