import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxnet_plus/rxnet_lib.dart';
import 'package:path_provider/path_provider.dart';

import 'bean/base_info.dart';
import 'bean/new_weather_info.dart';

/// RxNet Plus 0.6.0 增强示例
/// 展示新的适配器架构和最佳实践
/// 
/// 新特性：
/// - 可插拔适配器架构
/// - 三种内置适配器（DioAdapter, HttpAdapter, MockAdapter）
/// - 自定义适配器支持
/// - 统一的拦截器系统
/// - 100% 向后兼容
class EnhancedExample extends StatefulWidget {
  const EnhancedExample({Key? key}) : super(key: key);

  @override
  State<EnhancedExample> createState() => _EnhancedExampleState();
}

class _EnhancedExampleState extends State<EnhancedExample> {
  String result = "";
  SourcesType sourcesType = SourcesType.net;
  var count = 1;

  CancelToken pageRequestToken = CancelToken();

  @override
  void dispose() {
    pageRequestToken.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("RxNet Plus 0.6.0 增强示例"),
        actions: [
          TextButton(
            onPressed: () {
              RxNet.showDebugWindow(context);
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.cyan),
            ),
            child: const Text("打开调试窗口",
                style: TextStyle(color: Colors.black, fontSize: 16)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ==================== 适配器架构示例 ====================
            _buildSectionTitle("🎯 适配器架构示例（0.6.0 新特性）"),
            _buildSection("1. 默认适配器（DioAdapter）", _adapterExample1),
            _buildSection("2. 轻量级适配器（HttpAdapter）", _adapterExample2),
            _buildSection("3. 测试适配器（MockAdapter）", _adapterExample3),
            _buildSection("4. 多实例不同适配器", _adapterExample4),
            _buildSection("5. 自定义拦截器", _adapterExample5),

            const Divider(height: 40, thickness: 2),
            
            // ==================== 基础示例 ====================
            _buildSectionTitle("📚 基础示例"),
            _buildSection("基础示例:回调", basicExample1),
            _buildSectionWithStop("基础示例:流式(轮询)", basicExample2, _stopPolling),
            _buildSection("基础示例:async/await", basicExample3),
            
            const Divider(height: 40, thickness: 2),
            
            // ==================== API 优化示例 ====================
            _buildSectionTitle("🚀 API 优化示例"),
            _buildSection("1. RESTful请求 - 自动检测", _example1),
            _buildSection("2. 参数类型明确化", _example2),
            _buildSection("3. POST请求 - JSON格式", _example3),
            _buildSection("4. 文件上传 - FormData", _example4),
            _buildSection("5. 复杂查询 - 混合参数", _example5),
            _buildSection("6. 下载请求 - 混合参数", _example6),
            
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                "结果：\n$result",
                style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.blue,
        ),
      ),
    );
  }

  Widget _buildSection(String title, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          ElevatedButton(
            onPressed: onPressed,
            child: const Text("执行请求"),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionWithStop(String title, VoidCallback onPressed, VoidCallback onStop) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
          const SizedBox(height: 6),
          Row(
            children: [
              ElevatedButton(
                onPressed: onPressed,
                child: const Text("开始轮询"),
              ),
              const SizedBox(width: 10),
              ElevatedButton(
                onPressed: onStop,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: const Text("停止轮询"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 停止轮询
  void _stopPolling() {
    _subscription?.cancel();
    _subscription = null;
    setState(() {
      result = "轮询已停止";
    });
  }

  // ==================== 适配器架构示例 ====================

  /// 示例1：默认适配器（DioAdapter）
  /// 不指定适配器时，自动使用 DioAdapter（向后兼容）
  void _adapterExample1() async {
    try {
      // 方式1：不指定适配器（默认使用 DioAdapter）
      final result = await RxNet.get()
          .setPath('api/weather/city/{id}')
          .setPathParam("id", "101030100")
          .request();


      setState(() {
        this.result = "✅ 默认适配器示例\n"
            "适配器：DioAdapter（默认）\n"
            "状态：${result.isSuccess ? '成功' : '失败'}\n"
            "数据：${result.value?.toString().substring(0, 100)}...";
      });
    } catch (e) {
      setState(() {
        result = "❌ 错误：$e";
      });
    }
  }

  /// 示例2：轻量级适配器（HttpAdapter）
  /// 使用 dart:http 包，更轻量级
  void _adapterExample2() async {
    try {
      // 创建新实例并使用 HttpAdapter

      IOClient createPinnedClient() {
        final HttpClient httpClient = HttpClient();
        httpClient.badCertificateCallback =
            (X509Certificate cert, String host, int port) {
          // // 获取证书 DER
          // final der = cert.der;
          // final sha256 = sha256Convert(der);
          // const trustedFingerprint = "YOUR_SHA256_FINGERPRINT";
          // return sha256 == trustedFingerprint;
          return true;
        };
        return IOClient(httpClient);
      }

      final adapter = HttpAdapter(client: createPinnedClient());

      final httpApi = RxNet.create();
      await httpApi.initNet(
        baseUrl: "http://t.weather.sojson.com",
        adapter:adapter, // 使用轻量级适配器
        interceptors: [RxnetSimpleLogInterceptor()]
      );

      final result = await httpApi.getRequest()
          .setPath('api/weather/city/{id}')
          .setPathParam("id", "101030100")
          .request();

      setState(() {
        this.result = "✅ HttpAdapter 示例\n"
            "适配器：HttpAdapter（轻量级）\n"
            "状态：${result.isSuccess ? '成功' : '失败'}\n"
            "数据：${result.value?.toString().substring(0, 100)}...";
      });
    } catch (e) {
      setState(() {
        result = "❌ 错误：$e";
        LogUtil.v(result);
      });
    }
  }

  /// 示例3：测试适配器（MockAdapter）
  /// 用于单元测试，无需真实网络请求
  void _adapterExample3() async {
    try {
      // 创建 MockAdapter
      final mockAdapter = MockAdapter();
      
      // 配置模拟响应
      mockAdapter.setMockResponse(
        'api/weather/city/101030100',
        const AdapterResponse(
          statusCode: 200,
          data: {
            'status': 200,
            'message': 'success',
            'data': {
              'city': '北京',
              'temperature': '25°C',
              'weather': '晴天',
            }
          },
          headers: {'content-type': ['application/json']},
          request: AdapterRequest(
            baseUrl: 'http://mock.api.com',
            path: 'api/weather/city/101030100',
            method: HttpMethod.GET,
          ),
        ),
      );

      // 使用 MockAdapter
      final mockApi = RxNet.create();
      await mockApi.initNet(
        baseUrl: "http://mock.api.com",
        adapter: mockAdapter,
      );

      final result = await mockApi.getRequest()
          .setPath('api/weather/city/{id}')
          .setPathParam("id", "101030100")
          .request();

      setState(() {
        this.result = "✅ MockAdapter 示例\n"
            "适配器：MockAdapter（测试用）\n"
            "状态：${result.isSuccess ? '成功' : '失败'}\n"
            "数据：${jsonEncode(result.value)}\n"
            "说明：这是模拟数据，无需真实网络请求";
      });
    } catch (e) {
      setState(() {
        result = "❌ 错误：$e";
      });
    }
  }

  /// 示例4：多实例使用不同适配器
  /// 展示如何在同一应用中使用多个适配器
  void _adapterExample4() async {
    try {
      // API 1: 主要API使用 DioAdapter（功能完整）
      final mainApi = RxNet.create();
      await mainApi.initNet(
        baseUrl: "http://t.weather.sojson.com",
        adapter: DioAdapter(),
      );

      // API 2: 分析API使用 HttpAdapter（轻量级）
      final analyticsApi = RxNet.create();
      await analyticsApi.initNet(
        baseUrl: "http://analytics.example.com",
        adapter: HttpAdapter(),
      );

      // API 3: 测试API使用 MockAdapter
      final mockAdapter = MockAdapter();
      mockAdapter.setMockResponse(
        'api/test',
        AdapterResponse(
          statusCode: 200,
          data: {'message': 'test success'},
          headers: {},
          request: AdapterRequest(
            baseUrl: 'http://test.api.com',
            path: 'api/test',
            method: HttpMethod.GET,
          ),
        ),
      );
      
      final testApi = RxNet.create();
      await testApi.initNet(
        baseUrl: "http://test.api.com",
        adapter: mockAdapter,
      );

      debugPrint("mainApi:${mainApi.hashCode}");
      debugPrint("analyticsApi:${analyticsApi.hashCode}");
      debugPrint("testApi:${testApi.hashCode}");
      debugPrint("RxNet:${RxNet.I.hashCode}");

      // 并发请求
      final results = await Future.wait([
        mainApi.getRequest().setPath('api/weather/city/101030100').request(),
        testApi.getRequest().setPath('api/test').request(),
      ]);

      setState(() {
        this.result = "✅ 多实例不同适配器示例\n"
            "实例1（DioAdapter）：${results[0].isSuccess ? '成功' : '失败'}\n"
            "实例2（MockAdapter）：${results[1].isSuccess ? '成功' : '失败'}\n"
            "说明：不同实例可以使用不同的适配器，互不影响";
      });


    } catch (e) {
      setState(() {
        result = "❌ 错误：$e";
      });
    }
  }

  /// 示例5：自定义拦截器
  /// 展示如何使用统一的拦截器系统
  void _adapterExample5() async {
    try {
      // 创建自定义拦截器
      final customInterceptor = CustomLoggingInterceptor();

      // 创建实例并添加拦截器
      final api = RxNet.create();
      await api.initNet(
        baseUrl: "http://t.weather.sojson.com",
        adapter: DioAdapter(),
      );
      
      // 添加拦截器
      api.getAdapter()?.addInterceptor(customInterceptor);

      final result = await api.getRequest()
          .setPath('api/weather/city/{id}')
          .setPathParam("id", "101030100")
          .request();

      setState(() {
        this.result = "✅ 自定义拦截器示例\n"
            "拦截器：CustomLoggingInterceptor\n"
            "状态：${result.isSuccess ? '成功' : '失败'}\n"
            "说明：查看控制台日志，可以看到拦截器输出";
      });
    } catch (e) {
      setState(() {
        result = "❌ 错误：$e";
      });
    }
  }

  // ==================== 基础示例 ====================
  void basicExample1()  {

    //// 公共请求头 public request header
    // RxNet.setGlobalHeaders({
    //   "Accept-Encoding": "gzip, deflate, br",
    //   "Connection": "keep-alive",
    // });

    RxNet.get()
        .setPath('api/weather/city/{id}')
        .setPathParam("id", "101030100") //RESTFul时，这里的参数名称需要和路径中占位符--保持一直: http://t.weather.sojson.com/api/weather/city/101030100
        .setCancelToken(pageRequestToken) //取消请求的CancelToken
        .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
        // .setRetryCount(2, interval: const Duration(seconds: 7))  //失败重试，重试2次,每次间隔7秒
        .setLoop(true) // 定时请求
        .setContentType(ContentTypes.json) //application/json
        .setResponseType(ResponseType.json) //json
        .setCacheInvalidationTime(1000*5)  //本次请求的缓存失效时间-毫秒
    // .setRequestIgnoreCacheTime(true)  // 是否直接忽略缓存失效时间
    // .setJsonConvert(NewWeatherInfo.fromJson) //解析成NewWeatherInfo对象
    // .setJsonConvert((data)=> BaseBean<Data>.fromJson(data).data) // 如果你只关心data实体部分
        .setJsonConvert((data)=> BaseInfo<Data>.fromJson(data, Data.fromJson)) //如果你想要 code 等信息
    // .setJsonConvert((data)=>BaseInfo<Data>.fromJson(data, Data.fromJson).data) //如果你只关心data实体部分
    // .setResponseType(ResponseType.stream)
        .execute<BaseInfo<Data>>(
        success: (data, source) {
          //刷新UI
          count++;
          setState(() {
            result ="${sourcesType==SourcesType.net ? "网络请求" : "缓存请求"}-$count : ${jsonEncode(data)}";
            sourcesType = source;
          });
        },
        failure: (e) {
          debugPrint("--执行错误");
          setState(() {
            result = "empty data";
          });
        },
        completed: (){
          debugPrint("--执行完毕");
          //Callback that is always executed after a request succeeds or fails, used to cancel loading animations, etc.
          //请求成功或失败后始终都会执行的回调，用于取消加载动画等
        });
  }

  StreamSubscription? _subscription;
  void basicExample2(){
    // 如果已有订阅，先取消
    _subscription?.cancel();

    final pollingSubscription = RxNet.get()
        .setPath('api/weather/city/{id}')
        .setPathParam("id", "101030100")
        .setLoop(true, interval: const Duration(seconds: 7));

    _subscription = pollingSubscription.executeStream().listen((data){
      setState(() {
        count++;
        if (data.isSuccess) {
          result ="${sourcesType==SourcesType.net ? "网络请求" : "缓存请求"}-$count : ${jsonEncode(data.value)}";
          sourcesType = data.model;
        } else {
          result = data.error.toString();
        }
      });
    });
    // ⚠️ 注意：不要在这里立即取消订阅！
    // 订阅会在dispose()中取消，或者在下次调用basicExample2时取消
    // _subscription?.cancel();  // ❌ 错误：这会导致回调无法执行
  }

  void basicExample3() async {
    final data = await RxNet.get()
          .setPath('api/weather/city/{id}')
          .setPathParam("id", "101030100")
          .setRetryCount(2)  //重试次数
          .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
          .setJsonConvert(NewWeatherInfo.fromJson)
          .request<NewWeatherInfo>();

    setState(() {
      count++;
      result ="${sourcesType==SourcesType.net ? "网络请求" : "缓存请求"}-$count : ${jsonEncode(data.value)}";
      sourcesType = data.model;
    });
  }


  void newInstanceRequest() async {
    // 为这个实例进行独立的初始化配置
    final apiService = RxNet.create();
    await apiService.initNet(baseUrl: "https://api.xxx.com");
    // apiService.setHeaders(xxx)
    await apiService.getRequest()
        .setPath("/users/1")
        .setJsonConvert(NewWeatherInfo.fromJson)
        .request<NewWeatherInfo>();
    // final weatherInfo = response.value;

    final testApi = RxNet.create();
    await testApi.initNet(baseUrl: "https://api.xxx.com");

    debugPrint("apiService:${apiService.hashCode}");
    debugPrint("testApi:${testApi.hashCode}");
  }






  // ==================== 示例1：RESTful请求 - 自动检测 ====================
  
  void _example1() async {
    // ❌ 旧方式：需要手动设置 setRestfulUrl(true)
    // RxNet.get()
    //   .setPath("/user/{id}")
    //   .setParam("id", "123")
    //   .setRestfulUrl(true)  // 容易忘记
    //   .request();

    // ✅ 新方式：自动检测RESTful路径
    final result = await RxNet.get()
      .setPath("/api/weather/city/{id}")
      .setPathParam("id", "101030100")  // 自动替换 {id}
      // 无需 setRestfulUrl，框架自动检测
      .request();

    setState(() {
      this.result = "示例1结果：${result.value}";
    });
  }

  // ==================== 示例2：参数类型明确化 ====================
  
  void _example2() async {
    // ❌ 旧方式：参数类型不明确
    // RxNet.get()
    //   .setPath("/user/{id}")
    //   .setParam("id", "123")      // 这是路径参数？
    //   .setParam("page", 1)        // 这是查询参数？
    //   .setRestfulUrl(true)
    //   .request();

    // ✅ 新方式：参数类型清晰明确
    final result = await RxNet.get()
      .setPath("http://t.weather.sojson.com/api/users/{userId}/posts")
      .setPathParam("userId", "123")     // 路径参数：替换 {userId}
      .setQueryParam("page", 1)          // 查询参数：?page=1
      .setQueryParam("size", 20)         // 查询参数：&size=20
      .request();
    // 最终URL: /api/users/123/posts?page=1&size=20

    setState(() {
      this.result = "示例2结果：${result.value}";
    });
  }

  // ==================== 示例3：POST请求 - JSON格式 ====================
  
  void _example3() async {
    // ❌ 旧方式：不够明确
    // RxNet.post()
    //   .setPath("/api/user")
    //   .setParams({"name": "张三", "age": 25})
    //   .toBodyData()  // 不明确是什么格式
    //   .request();

    // ✅ 新方式：明确指定JSON格式
    final result = await RxNet.post()
      .setPath("/api/user")
      .setBodyParams({
        "name": "张三",
        "age": 25,
        "email": "zhangsan@example.com"
      })
      .asJson()  // 明确指定JSON格式
      .request();

    setState(() {
      this.result = "示例3结果：${result.value}";
    });
  }

  // ==================== 示例4：文件上传 - FormData ====================
  
  void _example4() async {
    // ❌ 旧方式
    // RxNet.post()
    //   .setPath("/upload")
    //   .setParam("file", multipartFile)
    //   .toFormData()
    //   .request();

    // ✅ 新方式：更语义化
    // final file = await MultipartFile.fromFile("path/to/file.jpg");
    // final result = await RxNet.post()
    //   .setPath("/api/upload/avatar/{userId}")
    //   .setPathParam("userId", "123")
    //   .setBodyParam("file", file)
    //   .setBodyParam("description", "用户头像")
    //   .asFormData()  // 明确指定FormData格式
    //   .request();

    setState(() {
      this.result = "示例4：文件上传（需要实际文件）";
    });
  }

  // ==================== 示例5：复杂查询 - 混合参数 ====================
  
  void _example5() async {
    // ❌ 旧方式：参数混在一起，不够清晰
    // RxNet.get()
    //   .setPath("/categories/{categoryId}/products")
    //   .setParam("categoryId", "electronics")
    //   .setParam("keyword", "手机")
    //   .setParam("minPrice", 1000)
    //   .setParam("page", 1)
    //   .setRestfulUrl(true)
    //   .request();

    // ✅ 新方式：参数分离清晰
    final result = await RxNet.get()
      .setPath("/api/categories/{categoryId}/products")
      .setPathParam("categoryId", "electronics")  // 路径参数
      .setQueryParams({                           // 查询参数
        "keyword": "手机",
        "minPrice": 1000,
        "maxPrice": 5000,
        "brand": "Apple",
        "sort": "price_asc",
        "page": 1,
        "size": 20
      })
      .setIgnoreCacheKey("page")  // 忽略page参数生成缓存键
      .setCacheMode(CacheMode.FIRST_USE_CACHE_THEN_REQUEST)
      .request();
    // 最终URL: /api/categories/electronics/products?keyword=手机&minPrice=1000&...

    setState(() {
      this.result = "示例5结果：${result.value}";
    });
  }

  void _example6() async {
    if (RxNetPlatform.isWeb) {
      Downloader.downloadFile(
          url:
          "https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg");
      return;
    }
    List<Permission> permissions = <Permission>[Permission.storage];

    for (var element in permissions) {
     final status = await element.request();
     if (status.isGranted) {
       debugPrint("权限已授权");
     } else {
       debugPrint("权限被拒绝");
     }
    }

    Directory? appDocDir = await getDownloadsDirectory();
    String? appDocPath = "${appDocDir?.absolute.path}/test.jpg";
    RxNet.get()
        .setPath("https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
        .breakPointDownload(
        savePath: appDocPath, success: (data,model){
          setState(() {
            this.result = "示例6：保存地址：$data";
          });
    });
  }
}

// ==================== 自定义拦截器示例 ====================

/// 自定义日志拦截器
/// 展示如何实现统一的拦截器接口
class CustomLoggingInterceptor extends AdapterInterceptor {

  @override
  void onRequest(
    AdapterRequest request,
    RequestInterceptorHandler handler,
  ) {
    debugPrint('🚀 [请求] ${request.method.name} ${request.buildFullUrl()}');
    debugPrint('📤 [请求头] ${request.headers}');
    if (request.bodyParams.isNotEmpty) {
      debugPrint('📦 [请求体参数] ${_safeJsonEncode(request.bodyParams)}');
    }
    if (request.rawBody != null) {
      debugPrint('📦 [原始请求体] ${_safeJsonEncode(request.rawBody)}');
    }
    if (request.queryParams.isNotEmpty) {
      debugPrint('🔍 [查询参数] ${request.queryParams}');
    }
    handler.next(request); // 继续请求
  }

  /// 安全地进行 JSON 编码，处理文件类型
  String _safeJsonEncode(dynamic data) {
    try {
      if (data == null) return 'null';
      
      // 如果是 Map，检查是否包含文件类型
      if (data is Map) {
        final safeData = <String, dynamic>{};
        data.forEach((key, value) {
          if (_isFileType(value)) {
            safeData[key] = '[File: ${_getFileDescription(value)}]';
          } else if (value is List && value.any(_isFileType)) {
            safeData[key] = '[Files: ${value.length} items]';
          } else {
            safeData[key] = value;
          }
        });
        return jsonEncode(safeData);
      } else if (_isFileType(data)) {
        return '[File: ${_getFileDescription(data)}]';
      } else {
        return jsonEncode(data);
      }
    } catch (e) {
      return data.toString();
    }
  }

  /// 检查是否是文件类型
  bool _isFileType(dynamic value) {
    final typeName = value.runtimeType.toString();
    return typeName.contains('MultipartFile') ||
           typeName.contains('File') ||
           typeName.contains('UploadFileInfo');
  }

  /// 获取文件描述信息
  String _getFileDescription(dynamic file) {
    try {
      if (file is Map && file.containsKey('filename')) {
        return file['filename'].toString();
      }
      return file.runtimeType.toString();
    } catch (e) {
      return 'unknown';
    }
  }

  @override
  void onResponse(
    AdapterResponse response,
    ResponseInterceptorHandler handler,
  ) {
    debugPrint('✅ [响应] ${response.statusCode} ${response.request.buildFullUrl()}');
    debugPrint('📥 [响应头] ${response.headers}');
    debugPrint('📦 [响应体] ${response.data?.toString().substring(0, 100)}...');
    handler.next(response); // 继续响应
  }

  @override
  void onError(
    AdapterException error,
    ErrorInterceptorHandler handler,
  ) {
    debugPrint('❌ [错误] ${error.type} - ${error.message}');
    handler.next(error); // 继续错误
  }
}

// ==================== 完整的实际应用示例 ====================

/// 用户管理API示例（使用适配器架构）
class UserApiExample {
  // 使用 DioAdapter 的实例
  static final RxNet _api = RxNet.create();
  
  /// 初始化API
  static Future<void> init() async {
    await _api.initNet(
      baseUrl: "https://api.example.com",
      adapter: DioAdapter(), // 显式指定适配器
    );
    
    // 添加自定义拦截器
    _api.getAdapter()?.addInterceptor(CustomLoggingInterceptor());
  }
  
  /// 获取用户列表（带分页和筛选）
  static Future<void> getUserList() async {
    final result = await _api.getRequest()
      .setPath("/api/users")
      .setQueryParams({
        "page": 1,
        "size": 20,
        "status": "active",
        "role": "admin"
      })
      .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
      // .setJsonConvert(UserListResponse.fromJson)
      .request();
    
    if (result.isSuccess) {
      debugPrint("用户列表：${result.value}");
    } else {
      debugPrint("错误：${result.error}");
    }
  }

  /// 获取单个用户详情
  static Future<void> getUserDetail(String userId) async {
    final result = await _api.getRequest()
      .setPath("/api/users/{id}")
      .setPathParam("id", userId)
      // .setJsonConvert(UserDetail.fromJson)
      .request();
    
    if (result.isSuccess) {
      debugPrint("用户详情：${result.value}");
    }
  }

  /// 创建用户
  static Future<void> createUser(Map<String, dynamic> userData) async {
    final result = await _api.postRequest()
      .setPath("/api/users")
      .setBodyParams(userData)
      .asJson()
      // .setJsonConvert(User.fromJson)
      .request();
    
    if (result.isSuccess) {
      debugPrint("创建成功：${result.value}");
    }
  }

  /// 更新用户
  static Future<void> updateUser(String userId, Map<String, dynamic> userData) async {
    final result = await _api.putRequest()
      .setPath("/api/users/{id}")
      .setPathParam("id", userId)
      .setBodyParams(userData)
      .asJson()
      .request();
    
    if (result.isSuccess) {
      debugPrint("更新成功");
    }
  }

  /// 删除用户
  static Future<void> deleteUser(String userId) async {
    final result = await _api.deleteRequest()
      .setPath("/api/users/{id}")
      .setPathParam("id", userId)
      .request();
    
    if (result.isSuccess) {
      debugPrint("删除成功");
    }
  }
}

/// 多适配器场景示例
class MultiAdapterExample {
  // 主API：使用 DioAdapter（功能完整）
  static final RxNet mainApi = RxNet.create();
  
  // 分析API：使用 HttpAdapter（轻量级）
  static final RxNet analyticsApi = RxNet.create();
  
  // 测试API：使用 MockAdapter
  static final RxNet testApi = RxNet.create();
  
  /// 初始化所有API实例
  static Future<void> init() async {
    // 初始化主API（DioAdapter）
    await mainApi.initNet(
      baseUrl: "https://api.main.com",
      adapter: DioAdapter(),
    );
    
    // 初始化分析API（HttpAdapter）
    await analyticsApi.initNet(
      baseUrl: "https://analytics.example.com",
      adapter: HttpAdapter(),
    );
    
    // 初始化测试API（MockAdapter）
    final mockAdapter = MockAdapter();
    mockAdapter.setMockResponse(
      'api/test',
      AdapterResponse(
        statusCode: 200,
        data: {'status': 'ok'},
        headers: {},
        request: AdapterRequest(
          baseUrl: 'https://test.api.com',
          path: 'api/test',
          method: HttpMethod.GET,
        ),
      ),
    );
    
    await testApi.initNet(
      baseUrl: "https://test.api.com",
      adapter: mockAdapter,
    );
  }
  
  /// 使用主API获取数据
  static Future<void> fetchMainData() async {
    final result = await mainApi.getRequest()
      .setPath("/api/data")
      .request();
    
    debugPrint("主API结果：${result.value}");
  }
  
  /// 发送分析数据（使用轻量级适配器）
  static Future<void> sendAnalytics(Map<String, dynamic> data) async {
    final result = await analyticsApi.postRequest()
      .setPath("/api/events")
      .setBodyParams(data)
      .asJson()
      .request();
    
    debugPrint("分析API结果：${result.value}");
  }
  
  /// 运行测试（使用模拟适配器）
  static Future<void> runTest() async {
    final result = await testApi.getRequest()
      .setPath("/api/test")
      .request();
    
    debugPrint("测试API结果：${result.value}");
  }
}

// ==================== 旧的示例代码（保留向后兼容性） ====================


/// 商品搜索API示例
class ProductApiExample {
  
  /// 搜索商品（复杂查询）
  static Future<void> searchProducts({
    required String categoryId,
    String? keyword,
    double? minPrice,
    double? maxPrice,
    String? brand,
    String? sort,
    int page = 1,
    int size = 20,
  }) async {
    final queryParams = <String, dynamic>{
      "page": page,
      "size": size,
    };
    
    if (keyword != null) queryParams["keyword"] = keyword;
    if (minPrice != null) queryParams["minPrice"] = minPrice;
    if (maxPrice != null) queryParams["maxPrice"] = maxPrice;
    if (brand != null) queryParams["brand"] = brand;
    if (sort != null) queryParams["sort"] = sort;
    
    final result = await RxNet.get()
      .setPath("/api/categories/{categoryId}/products")
      .setPathParam("categoryId", categoryId)
      .setQueryParams(queryParams)
      .setIgnoreCacheKey("page")  // 忽略page参数生成缓存键
      .setCacheMode(CacheMode.FIRST_USE_CACHE_THEN_REQUEST)
      // .setJsonConvert(ProductListResponse.fromJson)
      .request();
    
    if (result.isSuccess) {
      debugPrint("商品列表：${result.value}");
      debugPrint("数据来源：${result.model}");  // 网络或缓存
    }
  }
}

/// 文件上传API示例
class FileApiExample {
  
  /// 上传头像
  static Future<void> uploadAvatar(String userId, String filePath) async {
    // final file = await MultipartFile.fromFile(
    //   filePath,
    //   filename: "avatar.jpg"
    // );
    
    // final result = await RxNet.post()
    //   .setPath("/api/upload/avatar/{userId}")
    //   .setPathParam("userId", userId)
    //   .setBodyParam("file", file)
    //   .setBodyParam("description", "用户头像")
    //   .asFormData()
    //   .request();
    
    // if (result.isSuccess) {
    //   debugPrint("上传成功：${result.value}");
    // }
  }

  /// 批量上传文件
  static Future<void> uploadMultipleFiles(List<String> filePaths) async {
    // final files = await Future.wait(
    //   filePaths.map((path) => MultipartFile.fromFile(path))
    // );
    
    // final result = await RxNet.post()
    //   .setPath("/api/upload/batch")
    //   .setBodyParam("files", files)
    //   .setBodyParam("category", "documents")
    //   .asFormData()
    //   .request();
    
    // if (result.isSuccess) {
    //   debugPrint("批量上传成功");
    // }
  }
}

/// 表单提交API示例
class FormApiExample {
  
  /// 登录（URL编码格式）
  static Future<void> login(String username, String password) async {
    final result = await RxNet.post()
      .setPath("/api/auth/login")
      .setBodyParams({
        "username": username,
        "password": password
      })
      .asUrlEncoded()  // 使用URL编码格式
      .request();
    
    if (result.isSuccess) {
      debugPrint("登录成功：${result.value}");
    }
  }

  /// 提交反馈（JSON格式）
  static Future<void> submitFeedback({
    required String title,
    required String content,
    List<String>? tags,
  }) async {
    final bodyParams = <String, dynamic>{
      "title": title,
      "content": content,
    };
    
    if (tags != null && tags.isNotEmpty) {
      bodyParams["tags"] = tags;
    }
    
    final result = await RxNet.post()
      .setPath("/api/feedback")
      .setBodyParams(bodyParams)
      .removeNullValueKeys()  // 移除null值
      .asJson()
      .request();
    
    if (result.isSuccess) {
      debugPrint("提交成功");
    }
  }
}

/// 对比示例：展示新旧API的差异
class ComparisonExample {
  
  /// 场景1：简单的RESTful GET请求
  static void scenario1() async {
    // ❌ 旧方式
    // final oldResult = await RxNet.get()
    //   .setPath("/user/{id}")
    //   .setParam("id", "123")
    //   .setRestfulUrl(true)  // 需要手动设置
    //   .request();

    // ✅ 新方式
    await RxNet.get()
      .setPath("/user/{id}")
      .setPathParam("id", "123")  // 自动检测RESTful
      .request();
  }

  /// 场景2：POST请求提交JSON数据
  static void scenario2() async {
    // ❌ 旧方式
    // final oldResult = await RxNet.post()
    //   .setPath("/api/user")
    //   .setParams({"name": "张三", "age": 25})
    //   .toBodyData()  // 不够明确
    //   .request();

    // ✅ 新方式
    await RxNet.post()
      .setPath("/api/user")
      .setBodyParams({"name": "张三", "age": 25})
      .asJson()  // 明确指定JSON格式
      .request();
  }

  /// 场景3：复杂的混合参数请求
  static void scenario3() async {
    // ❌ 旧方式：参数混在一起
    // final oldResult = await RxNet.post()
    //   .setPath("/api/users/{userId}/profile")
    //   .setParam("userId", "123")
    //   .setParam("name", "张三")
    //   .setParam("age", 25)
    //   .setRestfulUrl(true)
    //   .toBodyData()
    //   .request();

    // ✅ 新方式：参数分离清晰
    await RxNet.post()
      .setPath("/api/users/{userId}/profile")
      .setPathParam("userId", "123")  // 路径参数
      .setBodyParams({                // Body参数
        "name": "张三",
        "age": 25
      })
      .asJson()
      .request();
  }

  /// 场景4：文件上传
  static void scenario4() async {
    // ❌ 旧方式
    // final oldResult = await RxNet.post()
    //   .setPath("/upload")
    //   .setParam("file", file)
    //   .toFormData()
    //   .upload();

    // ✅ 新方式
    // final newResult = await RxNet.post()
    //   .setPath("/upload")
    //   .setBodyParam("file", file)
    //   .asFormData()
    //   .upload(xxx,xx,xx);
  }
}
