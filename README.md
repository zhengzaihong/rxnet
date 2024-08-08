# RxNet 

一款极简且强大Flutter网络请求工具，支持restful、泛型请求、数据缓存(无网请求，非web)。该库是对Dio的扩展,使用更加自然。

已支持断点上传 / 下载


## 依赖：

    dependencies:
       flutter_rxnet_forzzh:0.1.9


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

1.如需要 restful 风格请求：setRestfulUrl(true)，内部自动转化参数链接

2.不设置 setJsonConvert 返回的都是Map类型数据，否则返回定义的实体类型。

需要json 转对象，请设置 setJsonConvert 并在回调中根据后端返回统一格式进行转换。

额外功能：小量数据支持 RxNet 数据存储来替换 ShardPreference使用：

        // web 端不支持
        rxPut("key","内容"); //存数据
        rxGet("key");       //取数据

执行请求的两种方式：

    1.方式一 ：RxNet.execute(success,failure) 
      支持缓存策略，先读缓存后请求，先请求失败后读缓存等
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
         baseUrlEnv: {  ///支持多环境 baseUrl调试
          "test": "http://t.weather.sojson1.com/",
          "debug": "http://t.weather.sojson2.com/",
          "release": "http://t.weather.sojson.com/",
           //xxxxx
        },
        interceptors: [  ///拦截器
          CustomLogInterceptor(
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
        .setRestfulUrl(true) //Restful 
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

     var data = await RxNet.get()  // post, get, delete, put, patch
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setRestfulUrl(true)
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
        .setRestfulUrl(true) ///Restful
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


 5.上传下载(支持断点上传下载)：(根据业务添加参数 setParam等),注意移动终端的文件读写权限。

  
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

    [log] ###输出日志信息：  v  ***************** Request Start *****************
    [log] ###输出日志信息：  v  uri: http://t.weather.sojson.com/api/weather/city/101030100
    [log] ###输出日志信息：  v  method: GET
    [log] ###输出日志信息：  v  responseType: ResponseType.json
    [log] ###输出日志信息：  v  followRedirects: true
    [log] ###输出日志信息：  v  connectTimeout:
    [log] ###输出日志信息：  v  receiveTimeout:
    [log] ###输出日志信息：  v  extra: {}
    [log] ###输出日志信息：  v  Request Headers:
    [log] ###输出日志信息：  v  {"content-type":"application/json"}
    [log] ###输出日志信息：  v  data:
    [log] ###输出日志信息：  v  null
    [log] ###输出日志信息：  v  ***************** Request End *****************
    [log] ###输出日志信息：  v  ***************** Response Start *****************
    [log] ###输出日志信息：  v  statusCode: 200
    [log] ###输出日志信息：  v  Response Headers:
    [log] ###输出日志信息：  v   connection: keep-alive
    [log] ###输出日志信息：  v   cache-control: max-age=3000
    [log] ###输出日志信息：  v   transfer-encoding: chunked
    [log] ###输出日志信息：  v   date: Wed, 07 Feb 2024 13:09:47 GMT
    [log] ###输出日志信息：  v   vary: Accept-Encoding
    [log] ###输出日志信息：  v   content-encoding: gzip
    [log] ###输出日志信息：  v   age: 2404
    [log] ###输出日志信息：  v   content-type: application/json;charset=UTF-8
    [log] ###输出日志信息：  v   x-source: C/200
    [log] ###输出日志信息：  v   server: marco/2.20
    [log] ###输出日志信息：  v   x-request-id: c58182a21ddcaed97d76dbb49f4771d8; 32238019a67857706c0e40b6dd0e1238
    [log] ###输出日志信息：  v   via: S.mix-hz-fdi1-213, T.213.H, V.mix-hz-fdi1-217, T.194.H, M.cun-he-sjw8-194
    [log] ###输出日志信息：  v   expires: Wed, 07 Feb 2024 13:19:43 GMT
    [log] ###输出日志信息：  v  Response Text:
    [log] ###输出日志信息：  v  {"message":"success感谢又拍云(upyun.com)提供CDN赞助","status":200,"date":"20240207","time":"2024-02-07 20:26:47","cityInfo":{"city":"天津市","citykey":"101030100","parent":"天津","updateTime":"18:31"},"data":{"shidu":"31%","pm25":13.0,"pm10":21.0,"quality":"优","wendu":"-1","ganmao":"各类人群可自由活动","forecast":[{"date":"07","high":"高温 5℃","low":"低温 -4℃","ymd":"2024-02-07","week":"星期三","sunrise":"07:11","sunset":"17:38","aqi":35,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"08","high":"高温 5℃","low":"低温 -5℃","ymd":"2024-02-08","week":"星期四","sunrise":"07:10","sunset":"17:39","aqi":62,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"09","high":"高温 7℃","low":"低温 -5℃","ymd":"2024-02-09","week":"星期五","sunrise":"07:09","sunset":"17:40","aqi":64,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"10","high":"高温 5℃","low":"低温 -4℃","ymd":"2024-02-10","week":"星期六","sunrise":"07:08","sunset":"17:41","aqi":68,"fx":"北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"11","high":"高温 10℃","low":"低温 -4℃","ymd":"2024-02-11","week":"星期日","sunrise":"07:07","sunset":"17:42","aqi":58,"fx":"西南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"12","high":"高温 11℃","low":"低温 -2℃","ymd":"2024-02-12","week":"星期一","sunrise":"07:06","sunset":"17:44","aqi":60,"fx":"西南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"13","high":"高温 12℃","low":"低温 0℃","ymd":"2024-02-13","week":"星期二","sunrise":"07:05","sunset":"17:45","aqi":72,"fx":"西南风","fl":"1级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"14","high":"高温 9℃","low":"低温 0℃","ymd":"2024-02-14","week":"星期三","sunrise":"07:03","sunset":"17:46","aqi":40,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"15","high":"高温 4℃","low":"低温 -2℃","ymd":"2024-02-15","week":"星期四","sunrise":"07:02","sunset":"17:47","aqi":46,"fx":"西北风","fl":"4级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"16","high":"高温 8℃","low":"低温 -3℃","ymd":"2024-02-16","week":"星期五","sunrise":"07:01","sunset":"17:48","aqi":38,"fx":"南风","fl":"3级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"17","high":"高温 10℃","low":"低温 3℃","ymd":"2024-02-17","week":"星期六","sunrise":"07:00","sunset":"17:49","aqi":34,"fx":"东风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"18","high":"高温 6℃","low":"低温 -1℃","ymd":"2024-02-18","week":"星期日","sunrise":"06:58","sunset":"17:50","aqi":57,"fx":"北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"19","high":"高温 3℃","low":"低温 -5℃","ymd":"2024-02-19","week":"星期一","sunrise":"06:57","sunset":"17:51","aqi":59,"fx":"东风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"20","high":"高温 3℃","low":"低温 -5℃","ymd":"2024-02-20","week":"星期二","sunrise":"06:56","sunset":"17:53","aqi":56,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"21","high":"高温 2℃","low":"低温 -6℃","ymd":"2024-02-21","week":"星期三","sunrise":"06:54","sunset":"17:54","aqi":97,"fx":"北风","fl":"2级","type":"霾","notice":"雾霾来袭，戴好口罩再出门"}],"yesterday":{"date":"06","high":"高温 5℃","low":"低温 -7℃","ymd":"2024-02-06","week":"星期二","sunrise":"07:12","sunset":"17:37","aqi":48,"fx":"西北风","fl":"2级","type":"霾","notice":"雾霾来袭，戴好口罩再出门"}}}
    [log] ###输出日志信息：  v  useTime:0分:0秒:215毫秒
    [log] ###输出日志信息：  v  Response url :http://t.weather.sojson.com/api/weather/city/101030100
    [log] ###输出日志信息：  v  ***************** Response End *****************
    [log] ###输出日志信息：  v  useJsonAdapter：true

