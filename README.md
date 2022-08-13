# Rxnet 

一款极简的Flutter网络请求工具，支持restful,泛型请求，数据缓存。该库是对Dio 的网络库的扩展。

注意：数据缓存只支持 Andorid 和IOS 平台，内部是基于sqlite实现。

## 依赖：

    dependencies:
    
       flutter_rxnet_forzzh:0.0.1


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


如需要 restful 风格请求：setEnableRestfulUrl(true)

不设置 setJsonConvertAdapter返回的都是Map 类型数据，需要json 转对象，请设置 setJsonConvertAdapter
并在回调中根据后端返回统一格式进行转换。

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
          .execute(success: (data,mo){
            var source = mo as SourcesType;
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


 3.上传下载：(根据业务添加参数 setParam等),注意移动终端的文件读写权限。

  
    RxNet.get() 
        .setPath("https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
        .download(
          savePath:"${appDocPath}/55.jpg",
          onReceiveProgress: (len,total){
            print("len:$len,total:$total");
            if(len ==total){
              downloadPath = appDocPath;
              setState(() {

              });
            }
          });

   
  
    RxNet.post()
        .setPath(
            "https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
        .upload(
            success: (data, mo) {},
            failure: (e) {},
            onSendProgress: (len, total) {});