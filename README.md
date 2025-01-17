# RxNet 

一款极简Flutter网络请求工具，该库是对Dio的扩展，使用更加自然，让应用更加丝滑,开屏即有数据等特性。

* 支持多种缓存策略。
* 支持断点上传、下载。
* 支持失败重试。
* 支持缓存时效。
* 支持restful风格请求。
* 支持循环请求，外部不用维护请求队列或定时执行。
* 支持json转实体请求。
* 支持全局拦截器。
* 支持async/await 方式调用。
* 支持原生开发的回调方式。
* 支持全局异常捕获。
* 支持日志控制台界面展示
* 支持少量键值对数据存储


## 依赖：

    dependencies:
       flutter_rxnet_forzzh:0.2.2   #请使用 0.2.2 版本及其以上


## 常用参数：

支持的请求方式：  get, post, delete, put, patch,

缓存策略：CacheMode 支持如下几种模式：

    1.不做缓存，只网络数据
    onlyRequest,
    
    2.先请求网络，如果请求网络失败，则读取缓存，如果读取缓存失败，本次请求失败
    requestFailedReadCache,

    3.先使用缓存，不管是否存在，仍然请求网络
    firstCacheThenRequest,

    4.只使用缓存
    onlyCache;

    5.先使用缓存，无缓存或超时效则请求网络(推荐)
    cacheNoneToRequest;


注意：

1.如需要 restful 风格请求：setRestfulUrl(true)，内部自动转化参数链接

2.不设置 setJsonConvert 返回的都是Map类型数据，否则返回定义的实体类型。

需要json 转对象，请设置 setJsonConvert 并在回调中根据后端返回统一格式进行转换。

额外功能：小量数据支持 RxNet 数据存储来替换 ShardPreference使用：

    // web 端不支持
    rxPut("key","内容"); //存数据
    rxGet("key");       //取数据

执行请求的两种方式：

    1.方式一 ：RxNet.execute(success,failure) 
      支持缓存策略
      HttpSuccessCallback 回调中获取最终数据。
      HttpFailureCallback 回调中获取错误信息。


    2.方式二  await RxNet.executeAsync<xxxx>()
      返回结果或错误信息都在 RxResult 实体中，无需try catch操作。
      RxResult.value 获取最终结果。
      RxResult.error 获取错误信息

## 说明：
 
 1.先初始化网络框架

     await RxNet().init(
        baseUrl: "http://t.weather.sojson.com/",
        // cacheDir: "xxx",   ///缓存目录
        // cacheName: "local_cache_app", ///缓存文件
        isDebug: true,   ///是否调试 打印日志
        baseCacheMode: CacheMode.requestFailedReadCache,
        // useSystemPrint: true,
        baseCheckNet:checkNet, ///全局检查网络
        requestCaptureError: (e){  ///全局抓获 异常
          print(">>>${HandleError.dioError(e).message}");
        },
         baseUrlEnv: {  ///支持多环境 baseUrl调试， RxNet().setEnv("test")方式切换;
          "test": "http://t.weather.sojson1.com/",
          "debug": "http://t.weather.sojson2.com/",
          "release": "http://t.weather.sojson.com/",
           //xxxxx
        }, 
        interceptors: [  ///拦截器
          //可以添加多个你自己的拦截器

          RxNetLogInterceptor(
            handlerRequest: (e,f) {
            },
            handlerResponse: (e,f) {
             ///拦截响应预处理些类似错误码跳转等业务。
             // final status = e.data['status'];
            }
          )
        ]);
 
 2.发起网络请求：

    1.回调模式：

    RxNet.get()  // post, get, delete, put, patch
        .setPath("api/weather")
        .setParam("city", "101030100")
        //.addParams(Map)  
        .setRestfulUrl(true) //Restful 
        .setCacheMode(CacheMode.onlyRequest)
        .setRetryCount(2)  //重试次数
        .setRetryInterval(5000) //毫秒
        .setFailRetry(true)
        //.setJsonConvert((data) => NormalWaterInfoEntity.fromJson(data))
        .setJsonConvert(NormalWaterInfoEntity.fromJson)
        .execute<NormalWaterInfoEntity>(
            success: (data, source) {
              content = data.toString();
              sourcesType = source;
              setState(() {});
            },
            failure: (e) {});


    2. await方式：

     var data = await RxNet.get()  // post, get, delete, put, patch
        .setPath("api/weather")
        .setParam("city", "101030100")
        //.addParams(Map)
        .setRestfulUrl(true)
        .setCacheMode(CacheMode.onlyRequest)
       // .setJsonConvert((data) => NormalWaterInfoEntity.fromJson(data))
        .setJsonConvert(NormalWaterInfoEntity.fromJson)
        // .executeAsync();
        .executeAsync<NormalWaterInfoEntity?>();

      print("--------->#${data.isError}");
      print("--------->#${data.error}");
      var result = data.value;
      content = result.toString();
      sourcesType = data.model;



 3.请求原始数据,某些特殊情况，如读取网盘资源文件数据



        RxNet.get()
            .setPath("http://xxxxx/xxxx/testjson.txt")
            .setCacheMode(CacheMode.onlyRequest)
            .execute<String>(success: (data,sourcesType){
              var source = sourcesType as SourcesType;
              content = data.toString();
              ///数据来源是网络 界面上可以分别处理或提示 来源等
              if(source == SourcesType.net){
              }else{
                /// 本地数据库
              }
        });


 4.请求数据直接转 Bean对象

      RxNet.get()  //这里可以省略 泛型声明
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setRestfulUrl(true) ///Restful
        .setCacheMode(CacheMode.onlyRequest)
        .setCheckNetwork((){
          //todo 检查网络的实现（非必要）
           return true;
        })
       .setJsonConvert(NormalWaterInfoEntity.fromJson)
       .execute<NormalWaterInfoEntity>(success: (data,sourcesType){
          var source = sourcesType as SourcesType;
          if(data is NormalWaterInfoEntity){
            content = data.toString();
            print("------>${data.message}");
          }
          ///数据来源是网络
          if(source == SourcesType.net){
          }else{
            /// 本地数据库
          }
          setState(() {});
        });

 
    注意：如果有全局公共 BaseBean可以如说明 2 中方式转换。如果没有则你的每个数据模型应当建全字段。
         setJsonConvert()设置需要转换的模型


 5.上传下载(支持断点上传下载)：(根据业务添加参数 setParam等),注意移动终端的文件读写权限。

  
    RxNet.get() 
        .setPath("https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
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
        .setPath("xxxxx.jpg")
        // breakPointUploadFile() 断点续传
        .upload(
            success: (data, sourcesType) {},
            failure: (e) {},
            onSendProgress: (len, total) {});


   
   6.清晰的日志拦截器，拒绝调试抓瞎。
     
    需要日志信息，初始化配置网络框架时请添加 RxNetLogInterceptor 拦截器

      RxNet().init(
       ...xxx
          isDebug: true, ///是否调试 打印日志
          interceptors: [  ///拦截器
          RxNetLogInterceptor() // 可自行添加自定义
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

   7.对于线上的APP接口错误信息，也可通过RxNet查看请求日志信息。
     
    打开调试日志窗口： RxNet().showDebugWindow(context);
    关闭调试日志窗口： RxNet().closeDebugWindow();


## 调试窗口：
![调试窗口](https://github.com/zhengzaihong/rxnet/blob/master/images/app_logcat.jpg) 
   
