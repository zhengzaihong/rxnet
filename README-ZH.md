# RxNet 

Language: [English](README.md) | 简体中文

🚀 RxNet：极简、强大、原生风格的 Flutter 网络通信框架
RxNet 是一款专为 Flutter 打造的跨平台网络请求工具，基于 Dio 深度封装，贴合原生开发习惯，几乎零学习成本即可上手。它不仅让网络通信更丝滑，还支持丰富的功能组合，助你构建高性能、可维护的移动应用。

🌟 核心亮点：

✅ 多种缓存策略：支持首次缓存、失败兜底、仅缓存等多种模式，灵活应对各种场景

🔁 断点续传：上传/下载支持断点恢复，轻松处理大文件传输

🔄 轮询请求：无需额外维护队列，轻松实现定时拉取

🔥 RESTful 风格支持：参数自动拼接，URL更清晰

🧠 JSON → 实体自动转换：支持 setJsonConvert，轻松对接后端数据模型

🧩 全局拦截器与异常捕获：统一处理请求逻辑与错误反馈

🧪 支持 async/await 与响应回调双模式：满足不同开发习惯

🧰 内置日志控制台 UI：调试更直观，线上问题快速定位

📦 轻量键值存储：替代 SharedPreferences，更高效

## 依赖：

    dependencies:
       rxnet_plus:0.4.0 //旧版本不在维护，旧版本最后依赖地址：flutter_rxnet_forzzh:0.4.0


## 常用参数：

支持的请求方式：`get, post, delete, put, patch`,

缓存策略：CacheMode 支持如下几种模式：

    enum CacheMode {
    
        //不做缓存，每次都发起请求
        ONLY_REQUEST,
        
        //只使用缓存，通常用于先预加载数据，切换到无网环境做数据显示
        ONLY_CACHE,
        
        //先请求网络，如果请求网络失败，则读取缓存，如果读取缓存失败，本次请求失败
        REQUEST_FAILED_READ_CACHE,
        
        //先使用缓存显示，不管是否存在，仍然请求网络，新数据替换缓存数据，并触发上次数据刷新
        FIRST_USE_CACHE_THEN_REQUEST,
        
        //先使用缓存，无缓存或缓存过期后再请求网络，否则不会请求网络
        CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
    }



注意：

1.如需要 `RESTful` 风格请求：请设置setRestfulUrl(true)，内部自动转化参数链接。

2.不设置 `setJsonConvert` 返回的都原始类型数据，否则返回定义的实体类型。

需要json 转对象，请设置 setJsonConvert 并在回调中根据后端返回统一格式进行转换。

#### 额外功能：小量数据支持 RxNet 数据来存储,效率更高效：

  
    //存储数据 key-value
    RxNet.saveCache("name", "张三");

    //读取数据
    RxNet.readCache("name").then((value) {
      LogUtil.v(value);  //输出：张三
    });

    //或者
    Future.delayed(const Duration(seconds: 5),() async{
      final result = await RxNet.readCache("name");
      LogUtil.v(result);  //输出：张三
    });

#### 注意：Web端不支持额外数据存储。

#### 执行请求的几种方式，请结合场景使用：

    1.方式一 ：RxNet.execute(success,failure,completed)
      Success 回调中获取最终数据。
      Failure 回调中获取错误信息。
      Completed 始终都会执行的回调，取消加载动画，释放资源等


    2.方式二  await RxNet.request()
      返回结果或错误信息都在 RxResult 实体中，无需try catch操作。
      RxResult.value 获取最终结果。
      RxResult.error 获取错误信息

    3.方式三  await RxNet.executeStream()
      返回结果或错误信息都在 RxResult 实体中。
      RxResult.value 获取最终结果。
      RxResult.error 获取错误信息

## 服用说明：
 
 ### 初始化网络框架

     await RxNet.init(
        baseUrl: "http://t.weather.sojson.com/",
        // cacheDir: "xxx",   ///缓存目录
        // cacheName: "local_cache", ///缓存文件
        baseCacheMode: CacheMode.REQUEST_FAILED_READ_CACHE, //请求失败读取缓存数据
        baseCheckNet:checkNet, //全局检查网络，所有的请求都走这个方法
        cacheInvalidationTime: 24 * 60 * 60 * 1000, //缓存时效毫秒
        // baseUrlEnv: {  ///支持多环境 baseUrl调试，RxNet.setDefaultEnv("test") 方式切换;
        //   "test": "http://t.weather.sojson1.com/",
        //   "debug": "http://t.weather.sojson2.com/",
        //   "release": "http://t.weather.sojson.com/",
        // },
        interceptors: [
          // TokenInterceptor // token拦截器，更多功能请自定义拦截器
          //日志拦截器
           RxNetLogInterceptor()
          //ResponseInterceptor() //自定义响应拦截器，预处理结果等
        ]);
 
 ### 发起网络请求（ post, get, delete, put, patch等同理）这里get举例：

###    1.回调模式：

    RxNet.get()
        .setPath('api/weather/') //地址
        .setParam("city", "101030100") //参数
        .setRestfulUrl(true) // http://t.weather.sojson.com/api/weather/city/101030100
        .setCancelToken(pageRequestToken) //取消请求的CancelToken
        .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
        //.setRetryCount(2, interval: const Duration(seconds: 7))  //失败重试，重试2次,每次间隔7秒
        //.setLoop(true, interval: const Duration(seconds: 5)) // 定时请求
        //.setContentType(ContentTypes.json) //application/json
        //.setResponseType(ResponseType.json) //json
        //.setCacheInvalidationTime(1000*10)  //本次请求的缓存失效时间-毫秒
        //.setRequestIgnoreCacheTime(true)  //是否直接忽略缓存失效时间
        .setJsonConvert(NewWeatherInfo.fromJson) //解析成NewWeatherInfo对象
        // .setJsonConvert((data)=> BaseBean<Data>.fromJson(data).data) // 如果你只关心data实体部分
        // .setJsonConvert((data)=> BaseInfo<Data>.fromJson(data, Data.fromJson)) //如果你想要 code 等信息
        //.setJsonConvert((data)=>BaseInfo<Data>.fromJson(data, Data.fromJson).data) //如果你只关心data实体部分
        .execute<NewWeatherInfo>(
            success: (data, source) {
              //刷新UI
              count++;
              setState(() {
                content ="$count : ${jsonEncode(data)}";
                sourcesType = source;
              });
             },
            failure: (e) {
              setState(() {
                content = "empty data";
              });
             },
            completed: (){
              //请求成功或失败后始终都会执行的回调，用于取消加载动画等
         });


###   2. async/await方式：

     var data = await RxNet.get()  
        .setPath("api/weather")
        .setParam("city", "101030100")
        //.addParams(Map) //一次添加多个参数
        .setRestfulUrl(true) //RESTFul 
        //.setRetryCount(2)  //重试次数
        //.setRetryInterval(7000) //毫秒
        .setCacheMode(CacheMode.ONLY_REQUEST)
        //.setJsonConvert((data) => NormalWaterInfoEntity.fromJson(data)) //解析成NormalWaterInfoEntity对象
        .setJsonConvert(NormalWaterInfoEntity.fromJson)
        .request();

      print("--------->#${data.error}");
      var result = data.value;
      content = result.toString();
      sourcesType = data.model;

###   3. Stream 流方式：

    //用于取消的句柄
    StreamSubscription? _subscription;

    void testStreamRequest(){

      final pollingSubscription = RxNet.get()
           .setPath("api/weather")
           .setParam("city", "101030100")
           .setRestfulUrl(true)
           .setLoop(true, interval: const Duration(seconds: 7))
           .executeStream(); // 直接使用 executeStream
       //     .listen((data) {
       //       setState(() {
       //         count++;
       //         if (data.isSuccess) {
       //           var result = data.value;
       //           content =count.toString() +" : "+ jsonEncode(result);
       //           sourcesType = data.model;
       //         } else {
       //           content = data.error.toString();
       //         }
       //       });
       // });
       // 或者使用如下方式：
      _subscription = pollingSubscription.listen((data){
               setState(() {
                 count++;
                 if (data.isSuccess) {
                   var result = data.value;
                   content ="$count : ${jsonEncode(result)}";
                   sourcesType = data.model;
                 } else {
                   content = data.error.toString();
                 }
               });
       });

    }

 注意：在使用方式三中，需要再不使用时，及时取消订阅：

    @override
    void dispose() {
     _subscription?.cancel();
     _cancelToken?.cancel();
      super.dispose();
    }

特别说明：

 无论使用那种请求方式，本质上都是 Stream,当轮询启用时，async/await 只返回首次的结果,底层流将被取消。
 如要获得所有响应结果，你必须使用execute（）或者直接监听executeStream（）。

 1.方式1中的success第二个参数和RxResult中的Model说明了数据来源：网络/缓存。

 2.使用方式三时，在不需需要时，及时关闭订阅：_subscription?.cancel()

 3.当页面需要退出时，或者不在关系请求结果时，可通过设置的CancelToken取消请求。


 ### 上传下载(支持断点上传下载)：注意移动终端的文件读写权限。

  
    RxNet.get() 
        .setPath("https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
        .setParam(xx,xx)
         //breakPointDownload() 断点下载
        .download(
          savePath:"${appDocPath}/55.jpg",
          onReceiveProgress: (len,total){
            print("len:$len,total:$total");
            if(len ==total){
              downloadPath = appDocPath;
            }
          });

   
  
    RxNet.post()
        .setPath("xxxxx/xxx.jpg")
        // breakPointUpload() 断点续传
        .upload(
            success: (data, sourcesType) {},
            failure: (e) {},
            onSendProgress: (len, total) {});


### 配置全局请求头的方式

 1.setGlobalHeaders(Map<String, dynamic> headers) 方式:

    RxNet.setGlobalHeaders({
     "Accept-Encoding": "gzip, deflate, br",
     "Connection": "keep-alive",
    });     

 2.添加自定义请求拦截器 xxxInterceptor() 如：

    class TokenInterceptors extends Interceptor {
      @override
      onRequest(
        RequestOptions options,
        RequestInterceptorHandler handler,
      ) async {
        Map<String, dynamic> header = {};
        header["token"] = "xxxxx";
        header["version"] = "1.0";
        options.headers.addAll(header);
        handler.next(options);
      }
    }

### 如果你的业务或项目中需要多个网络请求实例可手动创建多个请求对象：

    void newInstanceRequest() async {
      // 为这个实例进行独立的初始化配置，请求策略，拦截器等等
      final apiService = RxNet.create();
      await apiService.initNet(baseUrl: "https://api.yourdomain.com");
      // apiService.setHeaders(xxx)
      final response = await apiService.getRequest()
          .setPath("/users/1")
          .setJsonConvert(NewWeatherInfo.fromJson)
          .request();

      final weatherInfo = response.value;
    }

### 请求前的网络检测：  

     //无论是默认的请求实例，还是手动创建的多实例 配置了 baseCheckNet，则每次请求都会网络检测
    await RxNet.init(
        baseUrl: "xxxx",
        baseCacheMode: CacheMode.REQUEST_FAILED_READ_CACHE, //请求失败读取缓存数据
        baseCheckNet:checkNet, //全局检查网络，所有的请求都走这个方法
       );
   
    例如：

    Future<bool> checkNet() async{
      //需自行实现网络检测，或使用三方库
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        Toast.show( "当前无网络");
        return false;
      }
      return Future.value(true);
    }

### 证书校验：

    RxNet.getDefaultClient()?.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // 在这里进行自定义配置，例如证书校验等：
        // 设置为 false，表示默认拒绝所有无效证书
        client.badCertificateCallback = (X509Certificate cert, String host, int port) {
          // 你可以在这里添加更复杂的校验逻辑，例如校验证书指纹或颁发机构
          // 你的可能是xx.pem 等文件，读取出来再校验
          const trustedFingerprint = 'AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12';
          final certFingerprint = cert.sha1.toString().toUpperCase();
          final isTrusted = certFingerprint == trustedFingerprint;
          // 只有当证书可信时才允许请求
          return isTrusted;
        };
        return client;
      },
    );

### 清晰的日志拦截器，拒绝调试抓瞎。
     
    需要日志信息，初始化配置网络框架时请添加 RxNetLogInterceptor 拦截器 或者您自定义的

     await RxNet.init(
        // xxxxxx
        interceptors: [
          //TokenInterceptor // token拦截器，更多功能请自定义拦截器
          ///日志拦截器
           RxNetLogInterceptor()
           //ResponseInterceptor() //响应拦截器，预处理结果
        ]);

   输出格式：

    [log] ###日志：  v  ***************** Request Start *****************
    [log] ###日志：  v  uri: http://t.weather.sojson.com/api/weather/city/101030100
    [log] ###日志：  v  method: GET
    [log] ###日志：  v  responseType: ResponseType.json
    [log] ###日志：  v  followRedirects: true
    [log] ###日志：  v  connectTimeout:
    [log] ###日志：  v  receiveTimeout:
    [log] ###日志：  v  extra: {}
    [log] ###日志：  v  Request Headers:
    [log] ###日志：  v  {"content-type":"application/json"}
    [log] ###日志：  v  data:
    [log] ###日志：  v  null
    [log] ###日志：  v  ***************** Request End *****************
    [log] ###日志：  v  ***************** Response Start *****************
    [log] ###日志：  v  statusCode: 200
    [log] ###日志：  v  Response Headers:
    [log] ###日志：  v   connection: keep-alive
    [log] ###日志：  v   cache-control: max-age=3000
    [log] ###日志：  v   transfer-encoding: chunked
    [log] ###日志：  v   date: Wed, 07 Feb 2024 13:09:47 GMT
    [log] ###日志：  v   vary: Accept-Encoding
    [log] ###日志：  v   content-encoding: gzip
    [log] ###日志：  v   age: 2404
    [log] ###日志：  v   content-type: application/json;charset=UTF-8
    [log] ###日志：  v   x-source: C/200
    [log] ###日志：  v   server: marco/2.20
    [log] ###日志：  v   x-request-id: c58182a21ddcaed97d76dbb49f4771d8; 32238019a67857706c0e40b6dd0e1238
    [log] ###日志：  v   via: S.mix-hz-fdi1-213, T.213.H, V.mix-hz-fdi1-217, T.194.H, M.cun-he-sjw8-194
    [log] ###日志：  v   expires: Wed, 07 Feb 2024 13:19:43 GMT
    [log] ###日志：  v  Response Text:
    [log] ###日志：  v  {"message":"success感谢又拍云(upyun.com)提供CDN赞助","status":200,"date":"20241230","time":"2024-12-30 16:40:54","cityInfo":{"city":"天津市","citykey":"101030100","parent":"天津","updateTime":"15:13"},"data":{"shidu":"16%","pm25":11.0,"pm10":61.0,"quality":"良","wendu":"1.7","ganmao":"极少数敏感人群应减少户外活动","forecast":[{"date":"30","high":"高温 8℃","low":"低温 -6℃","ymd":"2024-12-30","week":"星期一","sunrise":"07:29","sunset":"16:57","aqi":46,"fx":"西北风","fl":"3级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"31","high":"高温 5℃","low":"低温 -3℃","ymd":"2024-12-31","week":"星期二","sunrise":"07:30","sunset":"16:58","aqi":54,"fx":"西风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"01","high":"高温 5℃","low":"低温 -4℃","ymd":"2025-01-01","week":"星期三","sunrise":"07:30","sunset":"16:59","aqi":59,"fx":"东北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"02","high":"高温 2℃","low":"低温 -2℃","ymd":"2025-01-02","week":"星期四","sunrise":"07:30","sunset":"17:00","aqi":50,"fx":"东北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"03","high":"高温 4℃","low":"低温 -5℃","ymd":"2025-01-03","week":"星期五","sunrise":"07:30","sunset":"17:00","aqi":65,"fx":"西风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"04","high":"高温 5℃","low":"低温 -5℃","ymd":"2025-01-04","week":"星期六","sunrise":"07:30","sunset":"17:01","aqi":86,"fx":"西南风","fl":"1级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"05","high":"高温 7℃","low":"低温 -2℃","ymd":"2025-01-05","week":"星期日","sunrise":"07:30","sunset":"17:02","aqi":75,"fx":"东北风","fl":"2级","type":"小雪","notice":"小雪虽美，赏雪别着凉"},{"date":"06","high":"高温 7℃","low":"低温 -2℃","ymd":"2025-01-06","week":"星期一","sunrise":"07:30","sunset":"17:03","aqi":31,"fx":"西北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"07","high":"高温 6℃","low":"低温 -2℃","ymd":"2025-01-07","week":"星期二","sunrise":"07:30","sunset":"17:04","aqi":32,"fx":"西北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"08","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-08","week":"星期三","sunrise":"07:30","sunset":"17:05","aqi":52,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"09","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-09","week":"星期四","sunrise":"07:30","sunset":"17:06","aqi":87,"fx":"西南风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"10","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-10","week":"星期五","sunrise":"07:29","sunset":"17:07","aqi":49,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"11","high":"高温 4℃","low":"低温 -2℃","ymd":"2025-01-11","week":"星期六","sunrise":"07:29","sunset":"17:08","aqi":46,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"12","high":"高温 3℃","low":"低温 -3℃","ymd":"2025-01-12","week":"星期日","sunrise":"07:29","sunset":"17:09","aqi":40,"fx":"西北风","fl":"3级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"13","high":"高温 3℃","low":"低温 -5℃","ymd":"2025-01-13","week":"星期一","sunrise":"07:29","sunset":"17:10","aqi":68,"fx":"南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"}],"yesterday":{"date":"29","high":"高温 6℃","low":"低温 -5℃","ymd":"2024-12-29","week":"星期日","sunrise":"07:29","sunset":"16:56","aqi":100,"fx":"西南风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"}}}
    [log] ###日志：  v  useTime:0分:0秒:215毫秒
    [log] ###日志：  v  Response url :http://t.weather.sojson.com/api/weather/city/101030100
    [log] ###日志：  v  ***************** Response End *****************
    [log] ###日志：  v  useJsonAdapter：true

 ### 对于线上的APP接口信息，也可通过埋点的RxNet查看请求日志信息。
     
    打开调试日志窗口： RxNet.showDebugWindow(context);
    关闭调试日志窗口： RxNet.closeDebugWindow();


## 调试窗口：
![调试窗口](https://github.com/zhengzaihong/rxnet/blob/master/images/app_logcat.jpg) 


    Copyright (c) 2018 ZhengZaiHong
    
    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the "Software"), to deal
    in the Software without restriction, including without limitation the rights
    to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
    copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:
    
    The above copyright notice and this permission notice shall be included in all
    copies or substantial portions of the Software.
    
    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
    OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
    SOFTWARE.