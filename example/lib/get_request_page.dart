import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';
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

  void request()  {

    //// 公共请求头 public request header
    RxNet.setGlobalHeaders({
      "User-Agent": "PostmanRuntime-ApipostRuntime/1.1.0",
      "Cache-Control": "no-cache",
      "Accept": "*",
      "Accept-Encoding": "gzip, deflate, br",
      "Connection": "keep-alive",
    });

    RxNet.get()
        .setPath('api/weather/')
        .setParam("city", "101030100")
        // .setParam("area", "9000")
        ///Restful  http://t.weather.sojson.com/api/weather/city/101030100
        .setRestfulUrl(true)
         // .setCancelToken(tag)
        .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
        .setRetryCount(2)  //重试次数
        .setRetryInterval(7000) //毫秒
        // .setLoop(true)
        .setContentType(ContentTypes.json) //application/json
        // .setCacheInvalidationTime(1000*10)  //毫秒
        // .setRequestIgnoreCacheTime(true)
        .setJsonConvert(NewWeatherInfo.fromJson)
        .execute<NewWeatherInfo>(
            success: (data, source) {
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

  Stream<RxResult>? _pollingSubscription;
  void test(){
    _pollingSubscription = RxNet.get()
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
    //           content = jsonEncode(data.error);
    //         }
    //       });
    // });
    _pollingSubscription?.listen((data){
            setState(() {
              count++;
              if (data.isSuccess) {
                var result = data.value;
                content ="$count : ${jsonEncode(result)}";
                sourcesType = data.model;
              } else {
                content = jsonEncode(data.error);
              }
            });
    });
  }

  void requestData() async {
    final data = await RxNet.get()
        .setPath("api/weather")
        .setParam("city", "101030100")
        // .setParam("area", "9000")
        .setRestfulUrl(true)
        .setLoop(true) //
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
