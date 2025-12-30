# RxNet

[![pub package](https://img.shields.io/pub/v/rxnet_plus.svg)](https://pub.dev/packages/rxnet_plus)
[![GitHub stars](https://img.shields.io/github/stars/zhengzaihong/rxnet.svg?style=social)](https://github.com/zhengzaihong/rxnet)
[![license](https://img.shields.io/github/license/zhengzaihong/rxnet)](LICENSE)

Language: English | [简体中文](README-ZH.md)

🚀 RxNet: Extremely Easy-to-Use, Powerful, Native-Style Flutter Network Communication Framework

RxNet is a cross-platform network request tool specially built for Flutter. It is based on deep encapsulation of Dio and conforms to native development habits. It can be started with almost zero learning cost. It can easily implement the feature of having data on the screen, supports rich function combinations, and helps you build high-performance, maintainable applications.

## 🎉 0.5.0 Major Update

RxNet 0.5.0 brings a brand new API design, significantly improving code readability and development experience!

📖 **Detailed Migration Guide:** [MIGRATION_GUIDE_0.5.0.md](MIGRATION_GUIDE_0.5.0.md)

🌟 Key Features:

✅ Multiple Cache Strategies: Supports first-use cache, failure fallback, cache-only, and more modes to flexibly respond to various scenarios

🔁 Breakpoint Resume: Upload/download supports breakpoint recovery, easily handling large file transfers

🔄 Polling Requests: No need to maintain additional queues, easily implement timed fetching

🔥 RESTful Style Support: Parameters auto-convert into URLs for cleaner URLs

🧠 JSON → Entity Auto-Conversion: Supports setJsonConvert, seamlessly mapping with backend data models

🧩 Global Interceptors & Error Handling: Centralized control over request flow and error feedback

🧪 Supports async/await and Callback Dual Modes: Meets different development habits

🧰 Built-in Debug Console UI: More intuitive debugging, quickly locate online issues

📦 Lightweight Key-Value Storage: Replaces SharedPreferences, more efficient

## Dependency:

    dependencies:
       rxnet_plus: ^0.5.0  // Latest version with new API design
       # rxnet_plus: ^0.4.3  // Old version
       # flutter_rxnet_forzzh: ^0.4.0  // Older version (no longer maintained)

**Version Notes:**
- **0.5.0+** - New API design with explicit parameter types and RESTful auto-detection (Recommended)
- **0.4.3** - Stable version, still maintained
- **0.4.0 and below** - Old version, no longer maintained

**Upgrading from 0.4.3 to 0.5.0?** Check [Migration Guide](MIGRATION_GUIDE_0.5.0.md)

## Common Parameters:

### Supported Request Methods: `get, post, delete, put, patch`

Cache Strategy: CacheMode supports the following modes:

    enum CacheMode {
    
        // No caching, always initiates a request
        ONLY_REQUEST,
        
        // Only uses cache, typically for preloading data and displaying in an offline environment
        ONLY_CACHE,
        
        // Requests network first, if network request fails, reads cache; if reading cache fails, this request fails
        REQUEST_FAILED_READ_CACHE,
        
        // Uses cache first regardless of existence, still requests network, new data replaces cached data and triggers data refresh
        FIRST_USE_CACHE_THEN_REQUEST,
        
        // Uses cache first, only requests network if cache is empty or expired, otherwise won't request network
        CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
    }

Note:

1. If `setJsonConvert` is not set, raw type data is returned; otherwise, the defined entity type is returned.

2. To convert JSON to object, please set setJsonConvert and perform conversion in the callback according to the backend's unified format.

#### Additional Feature: Small amounts of data support RxNet data storage, more efficient:


    // Store data key-value
    RxNet.saveCache("name", "John Doe");

    // Read data
    RxNet.readCache("name").then((value) {
      LogUtil.v(value);  // Output: John Doe
    });

    // Or
    Future.delayed(const Duration(seconds: 5),() async{
      final result = await RxNet.readCache("name");
      LogUtil.v(result);  // Output: John Doe
    });

#### Note: Web platform does not support additional data storage.

#### Several ways to execute requests, use according to scenario:

    1. Method One: RxNet.execute(success, failure, completed)
      Get final data in Success callback.
      Get error information in Failure callback.
      Completed callback always executes, for canceling loading animations, releasing resources, etc.


    2. Method Two: await RxNet.request()
      Results or error information are in RxResult entity, no need for try-catch operation.
      RxResult.value gets the final result.
      RxResult.error gets error information

    3. Method Three: await RxNet.executeStream()
      Results or error information are in RxResult entity.
      RxResult.value gets the final result.
      RxResult.error gets error information

## Usage Instructions:

### Initialize Network Framework

     await RxNet.init(
        baseUrl: "http://t.weather.sojson.com/",
        // cacheDir: "xxx",   /// Cache directory
        // cacheName: "local_cache", /// Cache file
        baseCacheMode: CacheMode.REQUEST_FAILED_READ_CACHE, // Read cache data on request failure
        baseCheckNet: checkNet, // Global network check, all requests go through this method
        cacheInvalidationTime: 24 * 60 * 60 * 1000, // Cache expiration time in milliseconds
        // baseUrlEnv: {  /// Supports multi-environment baseUrl debugging, switch with RxNet.setDefaultEnv("test");
        //   "test": "http://t.weather.sojson1.com/",
        //   "debug": "http://t.weather.sojson2.com/",
        //   "release": "http://t.weather.sojson.com/",
        // },
        interceptors: [
          // TokenInterceptor // Token interceptor, customize for more features
          // Log interceptor
           RxNetLogInterceptor()
          // ResponseInterceptor() // Custom response interceptor, preprocess results, etc.
        ]);

### Initiate Network Request (post, get, delete, put, patch are similar) - GET example:

###    1. Callback Mode:

    RxNet.get()
        .setPath('api/weather/city/{id}')
        .setPathParam("id", "101030100") // For RESTful, parameter name must match placeholder in path: Final URL: http://t.weather.sojson.com/api/weather/city/101030100
        .setCancelToken(pageRequestToken) // CancelToken for canceling request
        .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
        //.setRetryCount(2, interval: const Duration(seconds: 7))  // Retry on failure, retry 2 times, 7 seconds interval each
        //.setLoop(true, interval: const Duration(seconds: 5)) // Timed request
        //.setContentType(ContentTypes.json) // application/json
        //.setResponseType(ResponseType.json) // json
        //.setCacheInvalidationTime(1000*10)  // Cache expiration time for this request - milliseconds
        //.setRequestIgnoreCacheTime(true)  // Whether to directly ignore cache expiration time
        .setJsonConvert(NewWeatherInfo.fromJson) // Parse into NewWeatherInfo object
        // .setJsonConvert((data)=> BaseBean<Data>.fromJson(data).data) // If you only care about the data entity part
        // .setJsonConvert((data)=> BaseInfo<Data>.fromJson(data, Data.fromJson)) // If you want code and other information
        //.setJsonConvert((data)=>BaseInfo<Data>.fromJson(data, Data.fromJson).data) // If you only care about the data entity part
        .execute<NewWeatherInfo>(
            success: (data, source) {
              // Refresh UI
              count++;
              setState(() {
                content = "$count : ${jsonEncode(data)}";
                sourcesType = source;
              });
             },
            failure: (e) {
              setState(() {
                content = "empty data";
              });
             },
            completed: (){
              // Callback that always executes after request success or failure, for canceling loading animations, etc.
         });


###   2. async/await Method:

     var data = await RxNet.get()  
        .setPath("api/weather/{id}") // For RESTful, parameter name must match placeholder in path: Final URL: http://t.weather.sojson.com/api/weather/101030100
        .setPathParam("city", "101030100")
        //.setQueryParams(Map) // Add multiple parameters at once
        //.setRetryCount(2)  // Retry count
        .setCacheMode(CacheMode.ONLY_REQUEST)
        //.setJsonConvert((data) => NormalWaterInfoEntity.fromJson(data)) // Parse into NormalWaterInfoEntity object
        .setJsonConvert(NormalWaterInfoEntity.fromJson)
        .request<NormalWaterInfoEntity>();

      print("--------->#${data.error}");
      var result = data.value;
      content = result.toString();
      sourcesType = data.model;

###   3. Stream Style:

    // Handle for cancellation
    StreamSubscription? _subscription;

    void testStreamRequest(){

      final pollingSubscription = RxNet.get()
           .setPath("api/weather/{id}")
           .setParam("city", "101030100")
           .setLoop(true, interval: const Duration(seconds: 7))
           .executeStream(); // Directly use executeStream
       //     .listen((data) {
       //       setState(() {
       //         count++;
       //         if (data.isSuccess) {
       //           var result = data.value;
       //           content = count.toString() +" : "+ jsonEncode(result);
       //           sourcesType = data.model;
       //         } else {
       //           content = data.error.toString();
       //         }
       //       });
       // });
       // Or use the following method:
      _subscription = pollingSubscription.listen((data){
               setState(() {
                 count++;
                 if (data.isSuccess) {
                   var result = data.value;
                   content = "$count : ${jsonEncode(result)}";
                   sourcesType = data.model;
                 } else {
                   content = data.error.toString();
                 }
               });
       });

    }

Note: In Method Three, cancel the subscription in time when not in use:

    @override
    void dispose() {
     _subscription?.cancel();
     _cancelToken?.cancel();
      super.dispose();
    }

Special Note:

Regardless of which request method is used, it is essentially a Stream. When polling is enabled, async/await only returns the first result, and the underlying stream will be canceled.
To get all response results, you must use execute() or directly listen to executeStream().

1. The second parameter of success in Method 1 and Model in RxResult indicate the data source: network/cache.

2. When using Method Three, cancel the subscription in time when not needed: _subscription?.cancel()

3. When the page needs to exit, or when no longer interested in the request result, the request can be canceled through the set CancelToken.


### Upload and Download (supports breakpoint upload and download): Note file read/write permissions on mobile terminals.


    RxNet.get() 
        .setPath("https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
        .setParam(xx, xx)
         // breakPointDownload() Breakpoint download
        .download(
          savePath: "${appDocPath}/55.jpg",
          onReceiveProgress: (len, total){
            print("len:$len, total:$total");
            if(len == total){
              downloadPath = appDocPath;
            }
          });

   
  
    RxNet.post()
        .setPath("xxxxx/xxx.jpg")
        // breakPointUpload() Breakpoint resume upload
        .upload(
            success: (data, sourcesType) {},
            failure: (e) {},
            onSendProgress: (len, total) {});


### Configure Global Request Headers

1. setGlobalHeaders(Map<String, dynamic> headers) method:
 ```dart
   RxNet.setGlobalHeaders({
       "Accept-Encoding": "gzip, deflate, br",
       "Connection": "keep-alive",
   });

```

2. Add custom request interceptor xxxInterceptor() such as:

 ```dart
 class TokenInterceptors extends Interceptor {
      @override
      onRequest( RequestOptions options, RequestInterceptorHandler handler) async {
          Map<String, dynamic> header = {};
          header["token"] = "xxxxx";
          header["version"] = "1.0";
          options.headers.addAll(header);
          handler.next(options);
      }
  }
```

### If your business or project needs multiple network request instances, you can manually create multiple request objects:

    void newInstanceRequest() async {
      // Perform independent initialization configuration for this instance, request strategy, interceptors, etc.
      final apiService = RxNet.create();
      await apiService.initNet(baseUrl: "https://api.yourdomain.com");
      // apiService.setHeaders(xxx)
      final response = await apiService.getRequest()
          .setPath("/users/1")
          .setJsonConvert(NewWeatherInfo.fromJson)
          .request();

      final weatherInfo = response.value;
    }

### Network Detection Before Request:

     // Whether it's the default request instance or manually created multi-instance, if baseCheckNet is configured, network detection will be performed before each request
    await RxNet.init(
        baseUrl: "xxxx",
        baseCacheMode: CacheMode.REQUEST_FAILED_READ_CACHE, // Read cache data on request failure
        baseCheckNet: checkNet, // Global network check, all requests go through this method
       );
   
    For example:

    Future<bool> checkNet() async{
      // You need to implement network detection yourself or use a third-party library
      var connectivityResult = await (Connectivity().checkConnectivity());
      if (connectivityResult == ConnectivityResult.none) {
        Toast.show("Currently no network");
        return false;
      }
      return Future.value(true);
    }

### Certificate Validation:

    RxNet.getDefaultClient()?.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // Perform custom configuration here, such as certificate validation, etc.:
        // Set to false, indicating default rejection of all invalid certificates
        client.badCertificateCallback = (X509Certificate cert, String host, int port) {
          // You can add more complex validation logic here, such as validating certificate fingerprints or issuers
          // Your file might be xx.pem, etc., read it out and then validate
          const trustedFingerprint = 'AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12';
          final certFingerprint = cert.sha1.toString().toUpperCase();
          final isTrusted = certFingerprint == trustedFingerprint;
          // Only allow requests when the certificate is trusted
          return isTrusted;
        };
        return client;
      },
    );

### Clear Log Interceptor, Refuse Debugging Blindness.

    If you need log information, please add RxNetLogInterceptor or your custom interceptor when initializing the network framework

     await RxNet.init(
        // xxxxxx
        interceptors: [
          // TokenInterceptor // Token interceptor, customize for more features
          /// Log interceptor
           RxNetLogInterceptor()
           // ResponseInterceptor() // Response interceptor, preprocess results
        ]);

Output format:

    [log] ###Log:  v  ***************** Request Start *****************
    [log] ###Log:  v  uri: http://t.weather.sojson.com/api/weather/city/101030100
    [log] ###Log:  v  method: GET
    [log] ###Log:  v  responseType: ResponseType.json
    [log] ###Log:  v  followRedirects: true
    [log] ###Log:  v  connectTimeout:
    [log] ###Log:  v  receiveTimeout:
    [log] ###Log:  v  extra: {}
    [log] ###Log:  v  Request Headers:
    [log] ###Log:  v  {"content-type":"application/json"}
    [log] ###Log:  v  data:
    [log] ###Log:  v  null
    [log] ###Log:  v  ***************** Request End *****************
    [log] ###Log:  v  ***************** Response Start *****************
    [log] ###Log:  v  statusCode: 200
    [log] ###Log:  v  Response Headers:
    [log] ###Log:  v   connection: keep-alive
    [log] ###Log:  v   cache-control: max-age=3000
    [log] ###Log:  v   transfer-encoding: chunked
    [log] ###Log:  v   date: Wed, 07 Feb 2024 13:09:47 GMT
    [log] ###Log:  v   vary: Accept-Encoding
    [log] ###Log:  v   content-encoding: gzip
    [log] ###Log:  v   age: 2404
    [log] ###Log:  v   content-type: application/json;charset=UTF-8
    [log] ###Log:  v   x-source: C/200
    [log] ###Log:  v   server: marco/2.20
    [log] ###Log:  v   x-request-id: c58182a21ddcaed97d76dbb49f4771d8; 32238019a67857706c0e40b6dd0e1238
    [log] ###Log:  v   via: S.mix-hz-fdi1-213, T.213.H, V.mix-hz-fdi1-217, T.194.H, M.cun-he-sjw8-194
    [log] ###Log:  v   expires: Wed, 07 Feb 2024 13:19:43 GMT
    [log] ###Log:  v  Response Text:
    [log] ###Log:  v  {"message":"success感谢又拍云(upyun.com)提供CDN赞助","status":200,"date":"20241230","time":"2024-12-30 16:40:54","cityInfo":{"city":"天津市","citykey":"101030100","parent":"天津","updateTime":"15:13"},"data":{"shidu":"16%","pm25":11.0,"pm10":61.0,"quality":"良","wendu":"1.7","ganmao":"极少数敏感人群应减少户外活动","forecast":[{"date":"30","high":"高温 8℃","low":"低温 -6℃","ymd":"2024-12-30","week":"星期一","sunrise":"07:29","sunset":"16:57","aqi":46,"fx":"西北风","fl":"3级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"31","high":"高温 5℃","low":"低温 -3℃","ymd":"2024-12-31","week":"星期二","sunrise":"07:30","sunset":"16:58","aqi":54,"fx":"西风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"01","high":"高温 5℃","low":"低温 -4℃","ymd":"2025-01-01","week":"星期三","sunrise":"07:30","sunset":"16:59","aqi":59,"fx":"东北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"02","high":"高温 2℃","low":"低温 -2℃","ymd":"2025-01-02","week":"星期四","sunrise":"07:30","sunset":"17:00","aqi":50,"fx":"东北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"03","high":"高温 4℃","low":"低温 -5℃","ymd":"2025-01-03","week":"星期五","sunrise":"07:30","sunset":"17:00","aqi":65,"fx":"西风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"04","high":"高温 5℃","low":"低温 -5℃","ymd":"2025-01-04","week":"星期六","sunrise":"07:30","sunset":"17:01","aqi":86,"fx":"西南风","fl":"1级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"05","high":"高温 7℃","low":"低温 -2℃","ymd":"2025-01-05","week":"星期日","sunrise":"07:30","sunset":"17:02","aqi":75,"fx":"东北风","fl":"2级","type":"小雪","notice":"小雪虽美，赏雪别着凉"},{"date":"06","high":"高温 7℃","low":"低温 -2℃","ymd":"2025-01-06","week":"星期一","sunrise":"07:30","sunset":"17:03","aqi":31,"fx":"西北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"07","high":"高温 6℃","low":"低温 -2℃","ymd":"2025-01-07","week":"星期二","sunrise":"07:30","sunset":"17:04","aqi":32,"fx":"西北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"08","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-08","week":"星期三","sunrise":"07:30","sunset":"17:05","aqi":52,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"09","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-09","week":"星期四","sunrise":"07:30","sunset":"17:06","aqi":87,"fx":"西南风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"10","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-10","week":"星期五","sunrise":"07:29","sunset":"17:07","aqi":49,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"11","high":"高温 4℃","low":"低温 -2℃","ymd":"2025-01-11","week":"星期六","sunrise":"07:29","sunset":"17:08","aqi":46,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"12","high":"高温 3℃","low":"低温 -3℃","ymd":"2025-01-12","week":"星期日","sunrise":"07:29","sunset":"17:09","aqi":40,"fx":"西北风","fl":"3级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"13","high":"高温 3℃","low":"低温 -5℃","ymd":"2025-01-13","week":"星期一","sunrise":"07:29","sunset":"17:10","aqi":68,"fx":"南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"}],"yesterday":{"date":"29","high":"高温 6℃","low":"低温 -5℃","ymd":"2024-12-29","week":"星期日","sunrise":"07:29","sunset":"16:56","aqi":100,"fx":"西南风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"}}}
    [log] ###Log:  v  useTime: 0min: 0sec: 215ms
    [log] ###Log:  v  Response url: http://t.weather.sojson.com/api/weather/city/101030100
    [log] ###Log:  v  ***************** Response End *****************
    [log] ###Log:  v  useJsonAdapter: true

### For online APP interface information, you can also view request log information through embedded RxNet.

    Open debug log window: RxNet.showDebugWindow(context);
    Close debug log window: RxNet.closeDebugWindow();


## Debug Window:
![Debug Window](https://github.com/zhengzaihong/rxnet/blob/master/images/app_logcat.jpg)

## Also Supports HarmonyOS:
![HarmonyOS-example.gif](https://github.com/zhengzaihong/rxnet/blob/master/images/HarmonyOS-example.gif)



## 📝 Summary

### Core Points

1. **executeStream() Returns Stream**
    - Need to call `listen()` to start listening
    - Must save `StreamSubscription` for later cancellation
    - Immediate cancellation will cause callbacks not to execute
    - Should cancel in `dispose()` or on user action


2. **Choose the Appropriate Request Method**
    - Single request: `request()` or `execute()`
    - Polling request: `executeStream()`
    - Need to cancel: Use `CancelToken`

3. **Remember to Clean Up Resources**
    - Cancel subscriptions in `dispose()`
    - Avoid memory leaks
