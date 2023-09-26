# RxNet 

一款极简且强大Flutter网络请求工具，支持restful、泛型请求、数据缓存(无网请求)。该库是对Dio的扩展,同步的写法异步的实现，使用更加自然。

0.1.0版本之后缓存升级：支持全平台缓存(非web)，无网请求。

注意：0.0.9以前版本 数据缓存只支持 Android、HarmonyOS 和 IOS 、MACOS平台。

## 依赖：

    dependencies:
    
       flutter_rxnet_forzzh:0.1.3


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


注意：

1.如需要 restful 风格请求：setEnableRestfulUrl(true)，内部自动转化参数链接

2.不设置 setJsonConvertAdapter返回的都是Map类型数据，否则返回定义的实体类型。

需要json 转对象，请设置 setJsonConvertAdapter 并在回调中根据后端返回统一格式进行转换。

额外功能：小量数据支持 RxNet 数据存储来替换 ShardPreference使用：

        // web 端不支持
        RxNet().getDb()?.put("key","内容"); //存数据
        RxNet().getDb()?.get("key");       //取数据

执行请求的两种方式：

    1.方式一 ：RxNet.execute(success,fail) 
      支持缓存策略，先读缓存后请求，先请求失败后读缓存等
      HttpSuccessCallback 回调中获取最终数据。
      HttpFailureCallback 回调中获取错误信息。


    2.方式二  await RxNet.executeAsync<xxxx>()
      返回结果或错误信息都在 ResultEntity 实体中，无需try catch操作。
      ResultEntity.value 获取最终结果。
      ResultEntity.error 获取错误信息

## 说明：
 
 1.先初始化网络框架

    await RxNet().init(
        baseUrl: "xxxx",
        // cacheDir: "xxx",   ///缓存目录
        // cacheName: "local_cache_app", ///缓存文件
        isDebug: true,   ///是否调试 打印日志
        baseCacheMode: CacheMode.requestFailedReadCache, //请求策略
        // baseCheckNet:checkNet, ///全局检查网络
        requestCaptureError: (e){  ///全局抓获 异常
            if(e is DioException){
              print("------------------------->>>${e.response}");
            }
        },
        interceptors: [  ///拦截器
            CustomLogInterceptor()
        ]);
 
 2.发起网络请求：

    1.回调模式：

    RxNet.get()
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setEnableRestfulUrl(true) //Restful 
        .setCacheMode(CacheMode.requestFailedReadCache)
        .setJsonConvert((data) => NormalWaterInfoEntity.fromJson(data))
        .execute<NormalWaterInfoEntity>(
            success: (data, source) {
              content = data.toString();
              sourcesType = source;
              setState(() {});
            },
            failure: (e) {});


    2. await方式：

     var data = await RxNet.get()
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setEnableRestfulUrl(true)
        .setCacheMode(CacheMode.onlyRequest)
        .setJsonConvert((data) => NormalWaterInfoEntity.fromJson(data))
        // .executeAsync();
        .executeAsync<NormalWaterInfoEntity?>();

      print("--------->#${data.isError}");
      print("--------->#${data.error}");
      var result = data.value;
      content = result.toString();
      sourcesType = data.model;



 3.请求原始数据,某些特殊情况，如读取网盘资源文件数据



        RxNet.get<String>()
            .setPath("http://xxxxx/xxxx/testjson.txt")
            .setCacheMode(CacheMode.onlyRequest)
            .execute(success: (data,sourcesType){
              var source = sourcesType as SourcesType;
              content = data.toString();
              ///数据来源是网络 界面上可以分别处理或提示 来源等
              if(source == SourcesType.net){
              }else{
                /// 本地数据库
              }
        });


 4.请求数据直接转 Bean对象

      RxNet.get<NormalWaterInfoEntity>()  //这里可以省略 泛型声明
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setEnableRestfulUrl(true) ///Restful
        .setCacheMode(CacheMode.onlyRequest)
        .setCheckNetwork((){
          //todo 检查网络的实现（非必要）
           return true;
        })
       .setJsonConvert((data)=>NormalWaterInfoEntity.fromJson(data))
        .execute(success: (data,sourcesType){
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
         setJsonConvertAdapter()设置需要转换的模型


 5.上传下载：(根据业务添加参数 setParam等),注意移动终端的文件读写权限。

  
    RxNet.get() 
        .setPath("https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
        .download(
          savePath:"${appDocPath}/55.jpg",
          onReceiveProgress: (len,total){
            print("len:$len,total:$total");
            if(len ==total){
              downloadPath = appDocPath;
            }
          });

   
  
    RxNet.post()
        .setPath(
            "xxxxx.jpg")
        .upload(
            success: (data, sourcesType) {},
            failure: (e) {},
            onSendProgress: (len, total) {});


   
   6.清晰的日志拦截器，拒绝调试抓瞎。
     
    需要日志信息，初始化配置网络框架时请添加 CustomLogInterceptor 拦截器

      RxNet().init(
       ...xxx
          isDebug: true, ///是否调试 打印日志
          interceptors: [  ///拦截器
          CustomLogInterceptor() // 可自行添加自定义
      ]);


   输出格式：

    v  *** Request ***
    v  uri: http://t.weather.sojson.com/api/weather/city/101030100
    v  method: GET
    v  responseType: ResponseType.json
    v  followRedirects: true
    v  connectTimeout: 0
    v  receiveTimeout: 0
    v  extra: {}
    v  headers:
    v  data:
    v  null
    v  
    v  *** Response ***
    v  statusCode: 200
    v  headers:
    v   connection: keep-alive
    v   cache-control: max-age=3000
    v   transfer-encoding: chunked
    v   date: Thu, 16 Feb 2023 06:11:02 GMT
    v   vary: Accept-Encoding
    v   content-encoding: gzip
    v   age: 2924
    v   content-type: application/json;charset=UTF-8
    v   x-source: C/200
    v   server: marco/2.19
    v   x-request-id: 997eb90085750305536780809799cda9; f2efd57cfbcd9dd1b7f4eed3ffee513d
    v   via: S.mix-js-czx2-045, T.45.M, V.mix-js-czx2-045, T.1.H, M.ctn-sc-yan-004
    v   expires: Thu, 16 Feb 2023 06:12:18 GMT
    v  Response Text:
    v  {"message":"success感谢又拍云(upyun.com)提供CDN赞助","status":200,"date":"20230216","time":"2023-02-16 13:15:07","cityInfo":{"city":"天津市","citykey":"101030100","parent":"天津","updateTime":"11:46"},"data":{"shidu":"46%","pm25":58.0,"pm10":98.0,"quality":"良","wendu":"1","ganmao":"极少数敏感人群应减少户外活动","forecast":[{"date":"16","high":"高温 7℃","low":"低温 -3℃","ymd":"2023-02-16","week":"星期四","sunrise":"07:01","sunset":"17:48","aqi":68,"fx":"西南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"17","high":"高温 7℃","low":"低温 0℃","ymd":"2023-02-17","week":"星期五","sunrise":"06:59","sunset":"17:50","aqi":101,"fx":"西南风","fl":"2级","type":"霾","notice":"雾霾来袭，戴好口罩再出门"},{"date":"18","high":"高温 3℃","low":"低温 -2℃","ymd":"2023-02-18","week":"星期六","sunrise":"06:58","sunset":"17:51","aqi":97,"fx":"东风","fl":"2级","type":"小雪","notice":"小雪虽美，赏雪别着凉"},{"date":"19","high":"高温 8℃","low":"低温 -1℃","ymd":"2023-02-19","week":"星期日","sunrise":"06:57","sunset":"17:52","aqi":54,"fx":"西风","fl":"3级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"20","high":"高温 6℃","low":"低温 -2℃","ymd":"2023-02-20","week":"星期一","sunrise":"06:55","sunset":"17:53","aqi":62,"fx":"东北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"21","high":"高温 5℃","low":"低温 -3℃","ymd":"2023-02-21","week":"星期二","sunrise":"06:54","sunset":"17:54","aqi":58,"fx":"东南风","fl":"3级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"22","high":"高温 6℃","low":"低温 -2℃","ymd":"2023-02-22","week":"星期三","sunrise":"06:53","sunset":"17:55","aqi":71,"fx":"西北风","fl":"3级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"23","high":"高温 11℃","low":"低温 1℃","ymd":"2023-02-23","week":"星期四","sunrise":"06:51","sunset":"17:56","aqi":58,"fx":"西风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"24","high":"高温 16℃","low":"低温 3℃","ymd":"2023-02-24","week":"星期五","sunrise":"06:50","sunset":"17:57","aqi":81,"fx":"西风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"25","high":"高温 17℃","low":"低温 5℃","ymd":"2023-02-25","week":"星期六","sunrise":"06:49","sunset":"17:58","aqi":94,"fx":"西南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"26","high":"高温 16℃","low":"低温 3℃","ymd":"2023-02-26","week":"星期日","sunrise":"06:47","sunset":"17:59","aqi":84,"fx":"东风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"27","high":"高温 10℃","low":"低温 3℃","ymd":"2023-02-27","week":"星期一","sunrise":"06:46","sunset":"18:00","aqi":90,"fx":"西南风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"28","high":"高温 14℃","low":"低温 4℃","ymd":"2023-02-28","week":"星期二","sunrise":"06:44","sunset":"18:02","aqi":105,"fx":"东风","fl":"2级","type":"霾","notice":"雾霾来袭，戴好口罩再出门"},{"date":"01","high":"高温 15℃","low":"低温 4℃","ymd":"2023-03-01","week":"星期三","sunrise":"06:43","sunset":"18:03","aqi":18,"fx":"东北风","fl":"3级","type":"小雨","notice":"雨虽小，注意保暖别感冒"},{"date":"02","high":"高温 16℃","low":"低温 4℃","ymd":"2023-03-02","week":"星期四","sunrise":"06:41","sunset":"18:04","aqi":27,"fx":"北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"}],"yesterday":{"date":"15","high":"高温 5℃","low":"低温 -2℃","ymd":"2023-02-15","week":"星期三","sunrise":"07:02","sunset":"17:47","aqi":42,"fx":"东南风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"}}}
    v  useTime:0分:0秒:184毫秒
    v  Response end url :http://t.weather.sojson.com/api/weather/city/101030100
    v  useJsonAdapter：true

   特殊说明：

    如果web端遇到跨域问题：The connection errored: The XMLHttpRequest onError callback was called.  

    解决办法如下：

    1.找到当前项目使用的flutter sdk目录
    
    2.然后找到flutter\packages\flutter_tools\lib\src\web\chrome.dart文件并打开

    3.找到'--disable-extensions'位置，然后添加'--disable-web-security'

    4.另外还需要到flutter\bin\cache目录下，删除flutter_tools.stamp和flutter_tools.snapshot的文件，否则改动不生效