# RxNet 使用说明文档

> 本文档旨在帮助开发者快速上手 RxNet 网络请求框架，涵盖从安装、初始化到各功能模块的完整用法。

---

## 目录

- [1. 简介](#1-简介)
- [2. 安装与依赖](#2-安装与依赖)
- [3. 快速开始](#3-快速开始)
- [4. 初始化配置 (RxNetConfig)](#4-初始化配置-rxnetconfig)
- [5. 发起请求](#5-发起请求)
- [6. 缓存策略](#6-缓存策略)
- [7. 重试策略](#7-重试策略)
- [8. 拦截器](#8-拦截器)
- [9. 并发请求](#9-并发请求)
- [10. 文件上传与下载](#10-文件上传与下载)
- [11. 多实例与多环境](#11-多实例与多环境)
- [12. 适配器 (Adapter)](#12-适配器-adapter)
- [13. 全局请求配置 (AdapterBaseOptions)](#13-全局请求配置-adapterbaseoptions)
- [14. 证书验证](#14-证书验证)
- [15. 调试窗口](#15-调试窗口)
- [16. API 参考速查表](#16-api-参考速查表)

---

## 1. 简介

RxNet 是一个专为 Flutter 打造的跨平台网络请求框架，支持 Android / iOS / Windows / Linux / macOS / Web / HarmonyOS。它具备以下核心特性：

- **类原生开发体验**：符合 Flutter 原生开发习惯，几乎零学习成本
- **灵活的缓存管理**：5 种缓存模式 + 4 种淘汰策略（LRU / LFU / FIFO / 无）
- **智能重试**：固定间隔、指数退避、指数退避 + 随机抖动
- **可插拔适配器**：DioAdapter / HttpAdapter / MockAdapter，按需选择
- **内置拦截器**：Token 自动刷新、请求去重、节流
- **并发请求**：支持 zip 聚合和 Dart record 并行模式
- **断点续传**：上传 / 下载均支持断点续传

---

## 2. 安装与依赖

在 `pubspec.yaml` 中添加依赖：

```yaml
dependencies:
  rxnet_plus: ^0.7.0
```

然后执行：

```bash
flutter pub get
```

---

## 3. 快速开始

只需 3 步即可发起第一个请求：

### 第一步：初始化

在 `main.dart` 的 `main()` 函数中初始化：

```dart
import 'package:rxnet_plus/rxnet_plus.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RxNet.init(config: RxNetConfig(
    baseUrl: "https://api.example.com",
  ));

  runApp(MyApp());
}
```

### 第二步：定义数据模型

```dart
class WeatherInfo {
  final String city;
  final double temperature;

  WeatherInfo({required this.city, required this.temperature});

  factory WeatherInfo.fromJson(Map<String, dynamic> json) {
    return WeatherInfo(
      city: json['city'],
      temperature: (json['temperature'] as num).toDouble(),
    );
  }
}
```

### 第三步：发起请求

```dart
// async/await 方式（推荐）
final result = await RxNet.get<WeatherInfo>()
    .setPath('/api/weather/{id}')
    .setPathParam('id', '101030100')
    .setJsonConvert(WeatherInfo.fromJson)
    .request();

if (result.isSuccess) {
  final weather = result.requiredValue;
  print('城市: ${weather.city}, 温度: ${weather.temperature}');
}
```

---

## 4. 初始化配置 (RxNetConfig)

`RxNetConfig` 是整个框架的核心配置类，支持直接构造和 Builder 模式两种方式。

### 4.1 直接构造

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",         // 必填：服务端基础地址
  adapter: DioAdapter(),                       // 可选：网络适配器（默认 DioAdapter）
  cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST, // 缓存策略
  cacheInvalidationTime: 24 * 60 * 60 * 1000, // 缓存时效（毫秒），默认 1 年
  cacheMaxSize: 500,                           // 缓存最大条目数（0=不限制）
  cacheEvictionPolicy: CacheEvictionPolicy.lru, // 缓存淘汰策略
  interceptors: [                              // 拦截器列表
    RxNetLogAdapterInterceptor(),
  ],
  adapterBaseOptions: AdapterBaseOptions(      // 全局请求默认值
    connectTimeout: Duration(seconds: 10),
    sendTimeout: Duration(seconds: 10),
    receiveTimeout: Duration(seconds: 30),
  ),
  isDebug: true,                               // 是否为调试模式（默认 true）
  systemLog: false,                            // 是否开启系统日志
  ignoreCacheKeys: ['token'],                  // 生成缓存 key 时忽略的参数
));
```

### 4.2 Builder 模式

```dart
await RxNet.init(config: RxNetConfig.builder()
    .baseUrl("https://api.example.com")
    .adapter(DioAdapter())
    .cacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
    .cacheInvalidationTime(24 * 60 * 60 * 1000)
    .cacheMaxSize(500)
    .cacheEvictionPolicy(CacheEvictionPolicy.lru)
    .baseOptions(AdapterBaseOptions(
      connectTimeout: Duration(seconds: 10),
      sendTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 30),
    ))
    .addInterceptor(RxNetLogAdapterInterceptor())
    .debug(true)
    .build());
```

### 4.3 配置修改 (copyWith)

基于已有配置创建新配置（不可变模式）：

```dart
final newConfig = originalConfig.copyWith(
  baseUrl: "https://new-api.example.com",
  cacheMaxSize: 1000,
);
```

### 4.4 配置参数速查

| 参数 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `baseUrl` | `String` | **必填** | 服务端基础地址 |
| `adapter` | `NetworkAdapter?` | `DioAdapter()` | 网络适配器 |
| `cacheMode` | `CacheMode` | `ONLY_REQUEST` | 缓存策略 |
| `cacheInvalidationTime` | `int` | 365天（毫秒） | 缓存过期时间 |
| `cacheMaxSize` | `int` | `0`（不限制） | 缓存最大条目数 |
| `cacheEvictionPolicy` | `CacheEvictionPolicy` | `none` | 缓存淘汰策略 |
| `interceptors` | `List<AdapterInterceptor>?` | `null` | 拦截器列表 |
| `adapterBaseOptions` | `AdapterBaseOptions?` | `null` | 全局请求默认值 |
| `isDebug` | `bool` | `true` | 调试模式 |
| `systemLog` | `bool` | `false` | 系统日志 |
| `ignoreCacheKeys` | `List<String>?` | `null` | 忽略的缓存参数 key |
| `baseUrlEnv` | `Map<String, dynamic>?` | `null` | 多环境基础 URL |
| `cachePath` | `String?` | `null` | 自定义缓存目录 |
| `cacheName` | `String` | `network_cache` | 缓存文件名 |
| `databaseName` | `String` | `rxnet_cache.db` | 数据库文件名 |

---

## 5. 发起请求

### 5.1 支持的 HTTP 方法

```dart
RxNet.get<T>()      // GET 请求
RxNet.post<T>()     // POST 请求
RxNet.put<T>()      // PUT 请求
RxNet.delete<T>()   // DELETE 请求
RxNet.patch<T>()    // PATCH 请求
RxNet.head<T>()     // HEAD 请求
RxNet.options<T>()  // OPTIONS 请求
```

所有方法均支持泛型 `<T>`，用于指定响应数据的解析类型。

### 5.2 三种请求模式

#### 模式一：async/await（推荐）

适用于大多数场景，返回 `RxResult<T>` 对象：

```dart
final result = await RxNet.get<WeatherInfo>()
    .setPath('/api/weather/{id}')
    .setPathParam('id', '101030100')
    .setQueryParam('lang', 'zh')
    .setJsonConvert(WeatherInfo.fromJson)
    .request();

if (result.isSuccess) {
  final data = result.requiredValue;    // 非 null 版本，推荐使用
  // 或
  final data2 = result.value;           // nullable 版本
  final source = result.model;          // 数据来源：SourcesType.net / SourcesType.cache
} else {
  print('请求失败: ${result.error}');
}
```

#### 模式二：回调模式

适用于需要 `completed` 回调（如关闭 loading）的场景：

```dart
RxNet.get<WeatherInfo>()
    .setPath('/api/weather/{id}')
    .setPathParam('id', '101030100')
    .setJsonConvert(WeatherInfo.fromJson)
    .setRetryCount(2, interval: Duration(seconds: 7))
    .execute(
      success: (data, source) {
        // 请求成功，data 为解析后的对象，source 为数据来源
        setState(() { weather = data; });
      },
      failure: (e) {
        // 请求失败
        setState(() { error = e.toString(); });
      },
      completed: () {
        // 无论成功失败都会执行，适合关闭 loading 动画
        setState(() { isLoading = false; });
      },
    );
```

#### 模式三：Stream 模式

适用于轮询或需要持续监听数据的场景：

```dart
StreamSubscription? _subscription;

_subscription = RxNet.get<WeatherInfo>()
    .setPath('/api/weather/{id}')
    .setPathParam('id', '101030100')
    .setJsonConvert(WeatherInfo.fromJson)
    .setLoop(true, interval: Duration(seconds: 5))  // 每 5 秒轮询一次
    .executeStream()
    .listen((result) {
      if (result.isSuccess) {
        setState(() { weather = result.value; });
      }
    });

// 重要：在 dispose() 中取消订阅
@override
void dispose() {
  _subscription?.cancel();
  super.dispose();
}
```

### 5.3 请求构建 API 速查

以下方法可在构建请求时链式调用：

| 方法 | 说明 | 示例 |
|------|------|------|
| `.setPath(path)` | 设置请求路径 | `.setPath('/api/users/{id}')` |
| `.setPathParam(key, value)` | 设置路径参数 | `.setPathParam('id', '123')` |
| `.setQueryParam(key, value)` | 设置查询参数 | `.setQueryParam('page', 1)` |
| `.setQueryParams(map)` | 批量设置查询参数 | `.setQueryParams({'page': 1, 'size': 20})` |
| `.setBodyParam(key, value)` | 设置单个 Body 参数 | `.setBodyParam('name', 'John')` |
| `.setBodyParams(map)` | 批量设置 Body 参数 | `.setBodyParams({'name': 'John', 'age': 25})` |
| `.setHeader(key, value)` | 设置单个请求头 | `.setHeader('Authorization', 'Bearer xxx')` |
| `.addHeaders(map)` | 批量设置请求头 | `.addHeaders({'X-Custom': 'value'})` |
| `.setJsonConvert(fn)` | 设置 JSON 反序列化函数 | `.setJsonConvert(User.fromJson)` |
| `.setCacheMode(mode)` | 设置缓存策略 | `.setCacheMode(CacheMode.ONLY_REQUEST)` |
| `.setRetryCount(n, interval:)` | 设置重试次数 | `.setRetryCount(3, interval: Duration(seconds: 2))` |
| `.setRetryPolicy(policy)` | 设置高级重试策略 | `.setRetryPolicy(RetryPolicy.exponentialBackoff(...))` |
| `.asJson()` | 以 JSON 方式发送 Body | 适用于 POST/PUT/PATCH |
| `.asFormData()` | 以 FormData 方式发送 Body | 适用于文件上传 |
| `.asUrlEncoded()` | 以 URL 编码方式发送 Body | 适用于表单提交 |
| `.setBodyType(type)` | 设置请求体类型 | `.setBodyType(RequestBodyType.json)` |
| `.setLoop(enable, interval:)` | 启用轮询 | `.setLoop(true, interval: Duration(seconds: 5))` |
| `.setCancelToken(token)` | 设置取消令牌 | 支持 RxNet 和 Dio 的 CancelToken |
| `.setContentType(type)` | 设置 Content-Type | `.setContentType('text/plain')` |
| `.setResponseType(type)` | 设置响应类型 | `.setResponseType(ResponseType.plain)` |
| `.removeNullValueKeys()` | 移除值为 null 的参数 | 自动清理空参数 |

---

## 6. 缓存策略

### 6.1 缓存模式 (CacheMode)

RxNet 提供 5 种缓存模式，可通过全局配置或请求级别设置：

| 模式 | 说明 | 典型场景 |
|------|------|----------|
| `ONLY_REQUEST` | 不缓存，每次请求网络 | 实时数据（如股票行情） |
| `ONLY_CACHE` | 仅使用缓存，不请求网络 | 离线数据展示 |
| `REQUEST_FAILED_READ_CACHE` | 网络优先，失败时读缓存 | 普通列表页 |
| `FIRST_USE_CACHE_THEN_REQUEST` | 先展示缓存，再请求网络更新 | 首页信息流，追求加载速度 |
| `CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST` | 无缓存或过期才请求网络 | 天气、汇率等低频变化数据 |

**全局设置**（在 `RxNetConfig` 中配置）：

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
  cacheInvalidationTime: 60 * 60 * 1000, // 1 小时过期
));
```

**请求级别设置**（覆盖全局配置）：

```dart
RxNet.get<WeatherInfo>()
    .setPath('/api/weather/{id}')
    .setPathParam('id', '101030100')
    .setCacheMode(CacheMode.FIRST_USE_CACHE_THEN_REQUEST)
    .setJsonConvert(WeatherInfo.fromJson)
    .request();
```

### 6.2 缓存淘汰策略 (CacheEvictionPolicy)

当缓存条目数超过 `cacheMaxSize` 时，按以下策略自动淘汰旧数据：

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  cacheMaxSize: 200,
  cacheEvictionPolicy: CacheEvictionPolicy.lru,
));
```

| 策略 | 行为 | 适用场景 |
|------|------|----------|
| `none` | 不淘汰（默认） | 缓存数据量可控 |
| `lru` | 淘汰最近最少使用的条目 | 通用场景（推荐） |
| `lfu` | 淘汰使用频率最低的条目 | 有明显热点数据的场景 |
| `fifo` | 淘汰最早创建的条目 | 需要按时间先后淘汰的场景 |


### 6.3 缓存手动管理

```dart
final cache = RxNet.I.cacheManager;

// 键值对缓存
await cache.put('user_token', 'abc123');
final token = await cache.get<String>('user_token');

// 网络缓存读写
await cache.saveNetworkCache(
  path: '/api/data',
  params: {'page': 1},
  responseData: {'list': [...]},
);
final data = await cache.readNetworkCache(
  path: '/api/data',
  params: {'page': 1},
);

// 清除缓存
await cache.clearAll();                          // 清除全部
await cache.clearByPrefix('/api/users');          // 按前缀清除
await cache.clearByPattern(r'^/api/v\d+/');       // 按正则清除

// 查询缓存
final size = await cache.getCacheSize();          // 缓存条目数
final keys = await cache.getAllKeys();            // 所有缓存 key
```

---

## 7. 重试策略

### 7.1 固定间隔重试（简单方式）

```dart
RxNet.get<WeatherInfo>()
    .setPath('/api/weather/{id}')
    .setPathParam('id', '101030100')
    .setRetryCount(3, interval: Duration(seconds: 2)) // 失败后重试 3 次，每次间隔 2 秒
    .setJsonConvert(WeatherInfo.fromJson)
    .request();
```

### 7.2 高级重试策略 (RetryPolicy)

#### 指数退避

每次重试间隔时间翻倍，适合服务器过载恢复场景：

```dart
RxNet.get<WeatherInfo>()
    .setPath('/api/weather/{id}')
    .setRetryPolicy(RetryPolicy.exponentialBackoff(
      maxRetries: 3,
      baseInterval: Duration(seconds: 1),
      maxInterval: Duration(seconds: 30),
    ))
    .request();
// 重试间隔：1s -> 2s -> 4s
```

#### 指数退避 + 随机抖动（推荐）

在指数退避基础上加入随机抖动，避免大量客户端同时重试造成惊群效应：

```dart
RxNet.get<WeatherInfo>()
    .setPath('/api/weather/{id}')
    .setRetryPolicy(RetryPolicy.exponentialBackoffWithJitter(
      maxRetries: 5,
      baseInterval: Duration(seconds: 1),
      maxInterval: Duration(seconds: 30),
    ))
    .request();
// 重试间隔（约）：0.5s -> 1.5s -> 3s -> ...
```

### 7.3 策略对比

| 策略 | 第1次重试 | 第2次重试 | 第3次重试 | 适用场景 |
|------|-----------|-----------|-----------|----------|
| `fixed`（固定间隔） | 1s | 1s | 1s | 简单场景 |
| `exponentialBackoff` | 1s | 2s | 4s | 服务器过载恢复 |
| `exponentialBackoffWithJitter` | ~0.5s | ~1.5s | ~3s | 分布式系统（推荐） |

---

## 8. 拦截器

拦截器可以在请求发出前、响应返回后、出错时进行统一处理。

### 8.1 Token 自动刷新拦截器 (TokenRefreshInterceptor)

当服务器返回 401/403 时自动刷新 Token 并重试请求，内置并发去重（多个请求同时 401 时只刷新一次）：

```dart
String? currentToken;

await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  interceptors: [
    TokenRefreshInterceptor(
      // 判断是否为未授权错误
      isUnauthorized: (error, request) => error.statusCode == 401,
      // 提供新 Token
      tokenProvider: () async {
        final response = await Dio().post(
          'https://api.example.com/auth/refresh',
          data: {'refresh_token': refreshToken},
        );
        return response.data['access_token'];
      },
      // 更新请求头
      onRequestUpdated: (request, newToken) {
        return request.copyWith(
          headers: {...request.headers, 'Authorization': 'Bearer $newToken'},
        );
      },
      // Token 刷新成功回调
      onTokenRefreshed: (token) {
        currentToken = token;
      },
    ),
  ],
));
```

### 8.2 请求去重拦截器 (DeduplicateInterceptor)

在指定时间窗口内，相同请求只发送一次，避免用户重复点击导致的重复请求：

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  interceptors: [
    DeduplicateInterceptor(
      duration: Duration(seconds: 3), // 3 秒内同路径请求去重
    ),
  ],
));
```

### 8.3 请求节流拦截器 (ThrottleInterceptor)

限制请求频率，确保两次相同路径的请求间隔不低于指定时间：

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  interceptors: [
    ThrottleInterceptor(
      throttleDuration: Duration(seconds: 1), // 同一路径 1 秒内只发一次
    ),
  ],
));
```

### 8.4 日志拦截器

RxNet 提供两个内置日志拦截器：

```dart
// 完整日志拦截器（推荐调试使用）
RxNetLogAdapterInterceptor()

// 简洁日志拦截器
RxNetSimpleLogInterceptor()
```

在初始化时添加到拦截器列表即可。

---

## 9. 并发请求

### 9.1 使用 Dart Record 并行（推荐，Flutter 3.x+）

```dart
final (weatherResult, userResult) = await (
  RxNet.get<Weather>().setPath('/weather').request(),
  RxNet.get<User>().setPath('/user').request(),
).wait;

if (weatherResult.isSuccess && userResult.isSuccess) {
  final weather = weatherResult.requiredValue;
  final user = userResult.requiredValue;
}
```

### 9.2 使用 ZipRequest 聚合

适用于需要按标签获取结果的场景：

```dart
final results = await RxNet.zipRequest([
  ZipRequest<Weather>(
    request: ({success, failure, completed}) {
      RxNet.get<Weather>()
        .setPath('/weather')
        .execute(success: success, failure: failure, completed: completed);
    },
    tag: 'weather',
  ),
  ZipRequest<User>(
    request: ({success, failure, completed}) {
      RxNet.get<User>()
        .setPath('/user')
        .execute(success: success, failure: failure, completed: completed);
    },
    tag: 'user',
  ),
]);

// 按标签获取结果
final weather = results.getRequestByTag<Weather>('weather');
final user = results.getRequestByTag<User>('user');
```

### 9.3 ZipRequest 配置

```dart
final results = await RxNet.zipRequest(
  [...],
  eagerError: true,        // 任一请求失败立即返回（默认 true）
  cancelToken: cancelToken, // 取消令牌
  timeout: Duration(seconds: 10), // 超时时间
);
```

---

## 10. 文件上传与下载

### 10.1 普通下载

```dart
// Future 版本（推荐）
final result = await RxNet.get()
    .setPath("https://example.com/file.zip")
    .downloadFile(savePath: "${appDocPath}/file.zip");

if (result.isSuccess) {
  print('下载成功: ${result.value}');
}

// 回调版本
RxNet.get()
    .setPath("https://example.com/file.zip")
    .download(
      savePath: "${appDocPath}/file.zip",
      onReceiveProgress: (received, total) {
        final progress = (received / total * 100).toStringAsFixed(1);
        print('下载进度: $progress%');
      },
      success: (data, source) {
        print('下载完成: $data');
      },
      failure: (e) {
        print('下载失败: $e');
      },
    );
```

### 10.2 断点下载

支持暂停后继续下载，适合大文件场景：

```dart
RxNet.get()
    .setPath("https://example.com/large-file.zip")
    .breakPointDownload(
      savePath: "${appDocPath}/large-file.zip",
      onReceiveProgress: (received, total) {
        final progress = (received / total * 100).toStringAsFixed(1);
        print('下载进度: $progress%');
      },
      success: (data, source) {
        print('下载完成');
      },
      failure: (e) {
        print('下载失败: $e');
      },
      cancelCallback: () {
        print('下载已取消');
      },
    );
```

### 10.3 上传文件

```dart
// Future 版本
final result = await RxNet.post<Map<String, dynamic>>()
    .setPath("/api/upload")
    .setBodyParam("file", MultipartFile.fromFileSync("/path/to/image.jpg"))
    .asFormData()
    .uploadFile(onSendProgress: (sent, total) {
      final progress = (sent / total * 100).toStringAsFixed(1);
      print('上传进度: $progress%');
    });

// 回调版本
RxNet.post()
    .setPath("/api/upload")
    .setBodyParam("file", MultipartFile.fromFileSync("/path/to/image.jpg"))
    .asFormData()
    .upload(
      onSendProgress: (sent, total) {
        final progress = (sent / total * 100).toStringAsFixed(1);
        print('上传进度: $progress%');
      },
      success: (data, source) {
        print('上传成功');
      },
      failure: (e) {
        print('上传失败: $e');
      },
    );
```

### 10.4 断点上传

```dart
RxNet.post()
    .setPath("/api/upload")
    .breakPointUpload(
      filePath: "/path/to/large-file.zip",
      onSendProgress: (sent, total) {
        final progress = (sent / total * 100).toStringAsFixed(1);
        print('上传进度: $progress%');
      },
      success: (data, source) {
        print('上传完成');
      },
      failure: (e) {
        print('上传失败: $e');
      },
      cancelCallback: () {
        print('上传已取消');
      },
    );
```

---

## 11. 多实例与多环境

### 11.1 多实例

当你的项目需要对接多个不同的后端服务时，可以创建多个 RxNet 实例：

```dart
// 主 API 实例
final mainApi = RxNet.create();
await mainApi.initNet(config: RxNetConfig(
  baseUrl: "https://api.main.com",
  adapter: DioAdapter(),
));

// 分析 API 实例
final analyticsApi = RxNet.create();
await analyticsApi.initNet(config: RxNetConfig(
  baseUrl: "https://analytics.example.com",
  adapter: HttpAdapter(),
));

// 通过实例发起请求
await mainApi.getRequest<User>()
    .setPath('/user/me')
    .request();

await analyticsApi.postRequest<AnalyticsResult>()
    .setPath('/events')
    .request();
```

### 11.2 多环境切换

支持在开发、测试、生产环境之间快速切换：

```dart
// 初始化时配置多环境
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  baseUrlEnv: {
    'dev': 'https://dev.api.example.com',
    'test': 'https://test.api.example.com',
    'prod': 'https://api.example.com',
  },
));

// 运行时切换环境
RxNet.setDefaultEnv('test');   // 静态方法，切换默认实例
// 或
RxNet.I.setEnv('dev');         // 实例方法
```

---

## 12. 适配器 (Adapter)

RxNet 采用可插拔适配器架构，底层网络实现可自由切换。

### 12.1 适配器对比

| 适配器 | 依赖包 | 特性 | 请求取消 | 适用场景 |
|--------|--------|------|----------|----------|
| **DioAdapter** | `dio: ^5.8.0+1` | 全功能、拦截器完整 | 真正中断连接 | 生产环境（默认） |
| **HttpAdapter** | `http: ^1.2.0` | 基础 HTTP、拦截器、流式 | 伪取消（标记已取消） | 轻量应用 |
| **MockAdapter** | 无 | 模拟数据、无网络 | 模拟 | 单元测试/集成测试 |

### 12.2 选择适配器

```dart
// 使用默认的 DioAdapter（推荐，无需显式指定）
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
));

// 显式指定 DioAdapter
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  adapter: DioAdapter(),
));

// 使用 HttpAdapter（更轻量）
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  adapter: HttpAdapter(),
));

// 使用 MockAdapter（用于测试）
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  adapter: MockAdapter(),
));
```

---

## 13. 全局请求配置 (AdapterBaseOptions)

`AdapterBaseOptions` 允许你设置所有请求共享的全局默认值，无需在每个请求中重复设置：

```dart
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://api.example.com",
  adapterBaseOptions: AdapterBaseOptions(
    connectTimeout: Duration(seconds: 10),     // 连接超时
    sendTimeout: Duration(seconds: 10),        // 发送超时
    receiveTimeout: Duration(seconds: 30),     // 接收超时
    headers: {                                 // 全局请求头
      'Authorization': 'Bearer your_token_here',
    },
    contentType: 'application/json',           // 默认内容类型
    responseType: ResponseType.json,           // 默认响应类型
    followRedirects: true,                     // 是否跟随重定向
    maxRedirects: 5,                           // 最大重定向次数
    persistentConnection: true,                // 持久连接
  ),
));
```

**优先级规则**：请求级参数 > 全局默认值。例如，某个请求单独设置了 `connectTimeout`，则该设置会覆盖 `AdapterBaseOptions` 中的值。

---

## 14. 证书验证

### 使用 HttpAdapter 进行证书固定

```dart
import 'dart:io';
import 'package:http/io_client.dart';

IOClient createPinnedClient() {
  final httpClient = HttpClient();
  httpClient.badCertificateCallback = (X509Certificate cert, String host, int port) {
    // 在此处实现证书验证逻辑
    // 例如：验证证书指纹
    // final der = cert.der;
    // final sha256Hash = sha256Convert(der);
    // const trustedFingerprint = "YOUR_SHA256_FINGERPRINT";
    // return sha256Hash == trustedFingerprint;

    return true; // 仅测试用，生产环境请正确验证
  };
  return IOClient(httpClient);
}

// 使用自定义证书验证的适配器初始化
await RxNet.init(config: RxNetConfig(
  baseUrl: "https://your-api.com",
  adapter: HttpAdapter(client: createPinnedClient()),
));
```

---

## 15. 调试窗口

RxNet 内置了可视化的调试窗口，方便开发期间查看请求详情：

```dart
// 在需要的地方调用
RxNet.showDebugWindow(context);
```

调试窗口会展示所有请求的 URL、方法、状态码、请求/响应体等详细信息。

---

## 16. API 参考速查表

### 核心类

| 类 | 说明 |
|----|------|
| `RxNet` | 框架入口，提供静态方法和单例 `RxNet.I` |
| `RxNetConfig` | 配置类，支持 Builder 模式 |
| `RxNetConfigBuilder` | 配置构建器，流式 API |
| `BuildRequest<T>` | 请求构建器，链式设置请求参数 |
| `RxResult<T>` | 响应结果包装类 |
| `NetworkAdapter` | 适配器抽象基类 |
| `AdapterRequest` | 统一请求模型 |
| `AdapterResponse` | 统一响应模型 |
| `AdapterBaseOptions` | 全局请求默认配置 |
| `CancelToken` | 请求取消令牌 |
| `ZipRequest<T>` | 并发请求包装器 |
| `ZipResults` | 并发请求聚合结果 |

### RxNet 静态方法

| 方法 | 说明 |
|------|------|
| `RxNet.init(config:)` | 初始化框架（应用启动时调用一次） |
| `RxNet.get<T>()` | 创建 GET 请求 |
| `RxNet.post<T>()` | 创建 POST 请求 |
| `RxNet.put<T>()` | 创建 PUT 请求 |
| `RxNet.delete<T>()` | 创建 DELETE 请求 |
| `RxNet.patch<T>()` | 创建 PATCH 请求 |
| `RxNet.head<T>()` | 创建 HEAD 请求 |
| `RxNet.options<T>()` | 创建 OPTIONS 请求 |
| `RxNet.create()` | 创建新的 RxNet 实例 |
| `RxNet.setDefaultEnv(env)` | 切换多环境 |
| `RxNet.zipRequest(requests)` | 并发执行多个请求 |
| `RxNet.showDebugWindow(context)` | 显示调试窗口 |

### RxResult 属性

| 属性 | 类型 | 说明 |
|------|------|------|
| `isSuccess` | `bool` | 请求是否成功 |
| `isError` | `bool` | 请求是否失败 |
| `value` | `T?` | 结果值（nullable） |
| `requiredValue` | `T` | 结果值（非 null，失败时抛异常） |
| `error` | `Object?` | 错误信息 |
| `model` | `SourcesType` | 数据来源（net / cache） |

---

## 附录：完整项目示例

以下是一个结合多种特性的完整示例：

```dart
import 'package:flutter/material.dart';
import 'package:rxnet_plus/rxnet_plus.dart';

// ========== 数据模型 ==========
class User {
  final int id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'],
      name: json['name'],
      email: json['email'],
    );
  }
}

// ========== 初始化 ==========
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RxNet.init(config: RxNetConfig(
    baseUrl: "https://api.example.com",
    cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
    cacheInvalidationTime: 30 * 60 * 1000, // 30 分钟
    cacheMaxSize: 300,
    cacheEvictionPolicy: CacheEvictionPolicy.lru,
    adapterBaseOptions: AdapterBaseOptions(
      connectTimeout: Duration(seconds: 10),
      receiveTimeout: Duration(seconds: 30),
      headers: {
        'Content-Type': 'application/json',
      },
    ),
    interceptors: [
      RxNetLogAdapterInterceptor(),
      DeduplicateInterceptor(duration: Duration(seconds: 3)),
    ],
  ));

  runApp(MyApp());
}

// ========== 页面使用 ==========
class UserPage extends StatefulWidget {
  @override
  _UserPageState createState() => _UserPageState();
}

class _UserPageState extends State<UserPage> {
  User? user;
  String? error;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUser();
  }

  // 请求用户信息 -- async/await 模式
  Future<void> _fetchUser() async {
    setState(() { isLoading = true; error = null; });

    final result = await RxNet.get<User>()
        .setPath('/api/users/{id}')
        .setPathParam('id', '1')
        .setJsonConvert(User.fromJson)
        .setRetryPolicy(RetryPolicy.exponentialBackoffWithJitter(
          maxRetries: 3,
          baseInterval: Duration(seconds: 1),
          maxInterval: Duration(seconds: 10),
        ))
        .request();

    setState(() {
      isLoading = false;
      if (result.isSuccess) {
        user = result.requiredValue;
      } else {
        error = result.error.toString();
      }
    });
  }

  // 提交数据 -- 回调模式
  void _updateUser() {
    RxNet.put<User>()
        .setPath('/api/users/{id}')
        .setPathParam('id', '1')
        .setBodyParams({'name': '新名字'})
        .setJsonConvert(User.fromJson)
        .execute(
          success: (data, source) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('更新成功: ${data?.name}')),
            );
          },
          failure: (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('更新失败: $e')),
            );
          },
          completed: () {
            // 关闭 loading 等
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('用户信息')),
      body: isLoading
          ? Center(child: CircularProgressIndicator())
          : error != null
              ? Center(child: Text('错误: $error'))
              : Center(child: Text('用户: ${user?.name}')),
    );
  }
}
```
