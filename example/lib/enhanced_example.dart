import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxnet_plus/rxnet_lib.dart';
import 'package:path_provider/path_provider.dart';

import 'bean/base_info.dart';
import 'bean/new_weather_info.dart';

/// 优化后的API使用示例
/// 展示新旧API的对比和最佳实践
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
        title: const Text("请求示例"),
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
            _buildSection("基础示例:回调", basicExample1),
            _buildSectionWithStop("基础示例:流式(轮询)", basicExample2, _stopPolling),
            _buildSection("基础示例:async/await", basicExample3),
            _buildSection("1. RESTful请求 - 自动检测", _example1),
            _buildSection("2. 参数类型明确化", _example2),
            _buildSection("3. POST请求 - JSON格式", _example3),
            _buildSection("4. 文件上传 - FormData", _example4),
            _buildSection("5. 复杂查询 - 混合参数", _example5),
            _buildSection("6. 下载请求 - 混合参数", _example6),
            const SizedBox(height: 20),
            Text("结果：\n$result", style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String title, VoidCallback onPressed) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
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
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
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
        //.setLoop(true) // 定时请求
        .setContentType(ContentTypes.json) //application/json
        .setResponseType(ResponseType.json) //json
        // .setCacheInvalidationTime(1000*5)  //本次请求的缓存失效时间-毫秒
    // .setRequestIgnoreCacheTime(true)  // 是否直接忽略缓存失效时间
    // .setJsonConvert(NewWeatherInfo.fromJson) //解析成NewWeatherInfo对象
    // .setJsonConvert((data)=> BaseBean<Data>.fromJson(data).data) // 如果你只关心data实体部分
        .setJsonConvert((data)=> BaseInfo<Data>.fromJson(data, Data.fromJson)) //如果你想要 code 等信息
    // .setJsonConvert((data)=>BaseInfo<Data>.fromJson(data, Data.fromJson).data) //如果你只关心data实体部分
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
          setState(() {
            result = "empty data";
          });
        },
        completed: (){
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
    final response = await apiService.getRequest()
        .setPath("/users/1")
        .setJsonConvert(NewWeatherInfo.fromJson)
        .request<NewWeatherInfo>();
    // final weatherInfo = response.value;
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
      .setPath("/api/users/{userId}/posts")
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
    String? appDocPath = "${appDocDir?.path}/test.jpg";
    RxNet.get()
        .setPath("https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
        .download(
        savePath: appDocPath, success: (data,model){
      setState(() {
        this.result = "示例6：保存地址：$data";
      });
    });
  }
}

// ==================== 完整的实际应用示例 ====================

/// 用户管理API示例
class UserApiExample {
  
  /// 获取用户列表（带分页和筛选）
  static Future<void> getUserList() async {
    final result = await RxNet.get()
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
    final result = await RxNet.get()
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
    final result = await RxNet.post()
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
    final result = await RxNet.put()
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
    final result = await RxNet.delete()
      .setPath("/api/users/{id}")
      .setPathParam("id", userId)
      .request();
    
    if (result.isSuccess) {
      debugPrint("删除成功");
    }
  }
}

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
    final newResult = await RxNet.get()
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
    final newResult = await RxNet.post()
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
    final newResult = await RxNet.post()
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
