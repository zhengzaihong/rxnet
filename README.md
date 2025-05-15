# RxNet 

Language: English | [简体中文](README-ZH.md)


A minimalist Flutter network request tool. This library is an extension of Dio. It is more natural to use and makes the application smoother. It has data and other features when the screen is opened.

* Supports multiple caching strategies.
* Support breakpoint upload and download.
* Failed retry is supported.
* Support cache aging.
* Support RESTful style requests.
* Supports circular requests, and there is no need to maintain request queues or execute them regularly externally.
* Support json entity transfer requests.
* Support global interceptors.
* Supports async/await calls.
* Callbacks that support native habits.
* Support global exception capture.
* Support log console interface display
* Support small number of key-value pair data storage (danger threshold: more than 200,000 or when a single record size exceeds 1MB)


## dependent：

    dependencies:
       flutter_rxnet_forzzh:0.3.1  


## common parameters：

Supported request methods: get, post, delete, put, patch,

Caching strategy: CacheMode supports the following modes:

    1.No caching, only network data
    onlyRequest,
    
    2.Request the network first. If the network request fails, the cache is read. If the cache fails, the request fails.
    requestFailedReadCache,

    3.Use cache first, and still request network regardless of whether it exists or not
    firstCacheThenRequest,

    4.Use cache only
    onlyCache;

    5.Use cache first, and request network if there is no cache or it is out of time
    cacheNoneToRequest;


注意：

1. If you need a RESTful style request: setRestfulUrl(true), internal automatic conversion parameter link

2. If `setJsonConvert` is not set to return Map type data, otherwise the defined entity type will be returned.

If you need json conversion objects, please set setJsonConvert and convert them in the callback according to the unified format returned by the backend.

Additional features: Small amounts of data support RxNet data storage to replace ShardPreference:

    // Not supported on the web
    rxPut("key","content"); //data contained within, in connection with
    rxGet("key");       //fetch data

Two ways to execute requests：

    1.Usage 1 ：RxNet.execute(success,failure) 
      Support caching strategies

      Success: Get final data in callback。
      Failure: Get error message in callback。
      Completed: Callbacks that are always executed, unloading animations, releasing resources, etc.


    2.Usage 2 ： await RxNet.executeAsync<xxxx>()
      The returned results or error messages are all in the RxResult entity, no try catch operation is needed。
      RxResult.value ：Get the final result。
      RxResult.error ：Get error information

## description：
 
 1.Initialize the network framework first

     await RxNet().init(
        baseUrl: "http://t.weather.sojson.com/",
        // cacheDir: "xxx",   ///Cache directory
        // cacheName: "local_cache_app", ///Cache files
        baseCacheMode: CacheMode.requestFailedReadCache,
        baseCheckNet:checkNet, ///If a callback is provided to globally check the network, it will be triggered before each request
        requestCaptureError: (e){ //Global caught exception
          //It is recommended to handle it during interception, not to process too much content here 
          print(">>>${HandleError.dioError(e).message}");
        },
         baseUrlEnv: { ///supports multi-environment baseUrl debugging, and switches between RxNet().setEnv("test");
          "test": "http://t.weather.sojson1.com/",
          "debug": "http://t.weather.sojson2.com/",
          "release": "http://t.weather.sojson.com/",
           //xxxxx
        }, 
        interceptors: [ ///interceptors
          //You can add multiple interceptors of your own
          RxNetLogInterceptor()
        ]);
 
 2.Initiate network request：

    1.callback mode：

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
             // 这里的 data 已经是 NormalWaterInfoEntity类型
              setState(() {
                content = jsonEncode(data);
                sourcesType = source;
              });
             },
            failure: (e) {
              setState(() {
                content = "";
              });
             },
            completed: (){
              //请求成功或失败后始终都会执行的回调，用于取消加载动画等
         });


    2. await approach：

     var data = await RxNet.get()  // post, get, delete, put, patch
        .setPath("api/weather")
        .setParam("city", "101030100")
        //.addParams(Map)
        .setRestfulUrl(true)
        .setCacheMode(CacheMode.onlyRequest)
       // .setJsonConvert((data) => NormalWaterInfoEntity.fromJson(data))
        .setJsonConvert(NormalWaterInfoEntity.fromJson)
        .executeAsync<NormalWaterInfoEntity?>();

      print("--------->#${data.isError}");
      print("--------->#${data.error}");
      var result = data.value;
      content = result.toString();
      sourcesType = data.model;



 3.Request raw data, in some special cases, such as reading network disk resource file data


        RxNet.get()
            .setPath("http://xxxxx/xxxx/testjson.txt")
            .setCacheMode(CacheMode.onlyRequest)
            .execute<String>(success: (data,sourcesType){
              var source = sourcesType as SourcesType;
              content = data.toString();
              ///Data sources are sources that can be processed separately or prompted on the network interface
              if(source == SourcesType.net){
              }else{
                /// local database
              }
        });


 4.Request data to be transferred directly to a Bean object

      RxNet.get() 
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setRestfulUrl(true) ///Restful
        .setCacheMode(CacheMode.onlyRequest)
        .setCheckNetwork((){
          //todo Check network implementation (optional)
           return true;
        })
       .setJsonConvert(NormalWaterInfoEntity.fromJson)
       .execute<NormalWaterInfoEntity>(success: (data,sourcesType){
          var source = sourcesType as SourcesType;
          if(data is NormalWaterInfoEntity){
            content = data.toString();
            print("------>${data.message}");
          }
          ///The data source is the Internet
          if(source == SourcesType.net){
          }else{
            /// local database
          }
          setState(() {});
        });

 
    Note: If there is a global public BaseBean, it can be converted as in Note 2. If not, you should have all fields in each of your data models.
         setJsonConvert() sets the model that needs to be converted


 5.Upload and download (support breakpoint upload and download):(Add parameters such as setParam according to the service), pay attention to the file read and write permissions of the Mobile device.

  
    RxNet.get() 
        .setPath("https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
         /downloadBreakPoint() Breakpoint download
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
        // uploadFileBreakPoint() breakpoint continuous transmission
        .upload(
            success: (data, sourcesType) {},
            failure: (e) {},
            onSendProgress: (len, total) {});


   
   6.A clear log interceptor that refuses debugging.
     
    Log information is needed. Please add RxNetLogInterceptor interceptor or your customized when initializing and configuring the network framework.

      RxNet().init(
       ... xxx
          isDebug: true, ///Whether to debug the print log
          interceptors: [ ///interceptors
          RxNetLogInterceptor() //You can add your own customization
      ]);


   output format：

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

   7.For online APP interface error messages, you can also view the request log information through RxNet.
     
    Open the debug log window： RxNet().showDebugWindow(context);
    Close the debug log window： RxNet().closeDebugWindow();


## debug window：
![调试窗口](https://github.com/zhengzaihong/rxnet/blob/master/images/app_logcat.jpg) 
   
