# Rxnet 

一款极简且强大Flutter网络请求工具，支持restful,泛型请求，数据缓存。该库是对Dio网络库的扩展。

注意：数据缓存只支持 Andorid 和IOS 平台，内部是基于sqlite实现。

## 依赖：

    dependencies:
    
       flutter_rxnet_forzzh:0.0.2


## 常用参数：

支持的请求方式：  get, post, delete, put, patch,

CacheMode：支持如下几种模式：

    1.没有缓存
    onlyRequest,
    
    2.请求成功后存储缓存
    requestAndSaveCache,

    3.先请求网络，如果请求网络失败，则读取缓存，如果读取缓存失败，本次请求失败
    requestFailedReadCache,

    4.先使用缓存，不管是否存在，仍然请求网络
    firstCacheThenRequest,

    5.只使用缓存
    onlyCache;


如需要 restful 风格请求：setEnableRestfulUrl(true)。

不设置 setJsonConvertAdapter返回的都是Map 类型数据。

需要json 转对象，请设置 setJsonConvertAdapter 并在回调中根据后端返回统一格式进行转换。

Rxnet.execute() 的 HttpSuccessCallback 回调中获取最终数据。HttpFailureCallback获取错误信息。




## 说明：
 
 1.先初始化网络框架

    RxNet().init(
        baseUrl: "http://t.weather.sojson.com/",
        dbName: "test", ///数据库名字
        tableName: "project" ,///表明
        isDebug: true, ///是否调试 打印日志
        interceptors: [  ///拦截器
        CustomLogInterceptor()
    ]);
 
 2.发起网络请求：

    RxNet.get()
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setEnableRestfulUrl(true) ///Restful
        .setCacheMode(CacheMode.onlyCache)
        .setJsonConvertAdapter(
          JsonConvertAdapter<WaterInfoEntity>((data){
            ///这里利用了idea jsonToDart 插件
            ///其他工具实现也可以
            var base =  BaseBean<WaterInfoEntity>.fromJson(data);
            if(base.status == 200){
              return base.data;
            }
            /// 返回空数据模板 等
            return WaterInfoEntity();
          }))
          .execute(success: (data,sourcesType){
            var source = sourcesType as SourcesType;
            if(data is WaterInfoEntity){
              print("---------->${data.toString()}");
            }
            ///数据来源是网络
            /// 界面上可以分别处理或提示 来源等
            if(source == SourcesType.net){
            }else{
              /// 本地数据库
            }
         });


 3. 请求原始数据,某些特殊情况，如读取网盘资源文件数据



    RxNet.get<String>()
        .setPath("http://www.bestyxlife.com/appInfo/test.json.txt")
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
        .setJsonConvertAdapter(
            JsonConvertAdapter<NormalWaterInfoEntity>((data){
              return NormalWaterInfoEntity.fromJson(data);
            }))
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

 
    注意：如果有全局公共 BaseBean可以如说明 2中方式转换。如果没有则你的每个数据模型应当建全字段。
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
            "https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
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
          CustomLogInterceptor()
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
        v  uri: http://t.weather.sojson.com/api/weather/city/101030100
        v  statusCode: 200
        v  headers:
        v   connection: keep-alive
        v   cache-control: max-age=3000
        v   transfer-encoding: chunked
        v   date: Fri, 02 Sep 2022 01:59:04 GMT
        v   x-real-ip: 2409:8907:bb36:6ba7:6963:2da8:d6b:935f
        v   content-encoding: gzip
        v   vary: Accept-Encoding
        v   age: 2824
        v   content-type: application/json;charset=UTF-8
        v   x-source: C/200
        v   server: marco/2.17
        v   x-request-id: 161b3502a9a5df5aa79809152b368dd9; 06a1d20e55263e6a61797ab3e8a7d2ee
        v   via: S.mix-js-czx2-045, T.45.H, V.mix-js-czx2-047, T.2.H, M.ctn-sc-yan-004
        v   expires: Fri, 02 Sep 2022 02:02:00 GMT
        v  Response Text:
        v   {"status": 200,"date": "20220902","time": "2022-09-02 09:12:00","cityInfo": {"city": "天津市","citykey": "101030100","parent": "天津","updateTime": "08:31"},}