import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';
import 'package:flutter_uikit_forzzh/ext/top_view.dart';
import 'bean/new_weather_info.dart';

class GetRequestPage extends StatefulWidget {
  const GetRequestPage({Key? key}) : super(key: key);

  @override
  State<GetRequestPage> createState() => _GetRequestPageState();
}

class _GetRequestPageState extends State<GetRequestPage> {
  SourcesType sourcesType = SourcesType.net;
  String content = "";
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("get请求示例，其它请求：RxNet.post,RxNet.put等同样适用方式"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 40),
          
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: () {
                  // test();
                  // request();
                  requestData();
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.cyan),
                ),
                child: const Text("发起get请求",
                    style: TextStyle(color: Colors.black, fontSize: 16)),
              ),
              hGap(20),
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
          const SizedBox(height: 20),
          Expanded(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text("数据来源：${sourcesType == SourcesType.net ? "网络" : "缓存"}",
                  style: const TextStyle(color: Colors.black, fontSize: 16)),
              Expanded(
                  flex: 2,
                  child: Text(content,
                      style: const TextStyle(color: Colors.black, fontSize: 12))),
            ],
          ))
        ],
      ),
    );
  }

  var count = 1;

  CancelToken pageRequestToken = CancelToken();

    @override
    void dispose() {
      pageRequestToken.cancel();
      _subscription?.cancel();
      super.dispose();
    }

  void request()  {

    //// 公共请求头 public request header
    RxNet.setGlobalHeaders({
      "Accept-Encoding": "gzip, deflate, br",
      "Connection": "keep-alive",
    });

    RxNet.get()
        .setPath('api/weather/')
        .setParam("city", "101030100")
        .setRestfulUrl(true) // http://t.weather.sojson.com/api/weather/city/101030100
        .setCancelToken(pageRequestToken) //取消请求的CancelToken
        .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
        //.setRetryCount(2, interval: const Duration(seconds: 7))  //失败重试，重试2次,每次间隔7秒
        // .setLoop(true) // 定时请求
        .setContentType(ContentTypes.json) //application/json
        .setResponseType(ResponseType.json) //json
        // .setCacheInvalidationTime(1000*10)  //本次请求的缓存失效时间-毫秒
        // .setRequestIgnoreCacheTime(true)  // 是否直接忽略缓存失效时间
        .setJsonConvert(NewWeatherInfo.fromJson) //解析成NewWeatherInfo对象
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
              //Callback that is always executed after a request succeeds or fails, used to cancel loading animations, etc.
              //请求成功或失败后始终都会执行的回调，用于取消加载动画等
         });
  }

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
     _subscription?.cancel();
    }

  void requestData() async {
    final data = await RxNet.get()
        .setPath("api/weather")
        .setParam("city", "101030100")
        // .setParam("area", "9000")
        .setRestfulUrl(true)
        // .setRetryCount(2)  //重试次数
        // .setRetryInterval(7000) //毫秒
        .setCacheMode(CacheMode.ONLY_REQUEST)
        .setJsonConvert(NewWeatherInfo.fromJson)
        .request();

      setState(() {
        count++;
        var result = data.value;
        content ="$count : ${jsonEncode(result)}";
        sourcesType = data.model;
      });
    }


    void newInstanceRequest() async {
      // 为这个实例进行独立的初始化配置
      final apiService = RxNet.create();
      await apiService.initNet(baseUrl: "https://api.yourdomain.com");
      // apiService.setHeaders(xxx)
      final response = await apiService.getRequest()
          .setPath("/users/1")
          .setJsonConvert(NewWeatherInfo.fromJson)
          .request();

      final weatherInfo = response.value;
    }
}
