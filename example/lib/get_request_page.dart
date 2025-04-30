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
                  request(code: '101030100');
                  // request1();
                },
                style: ButtonStyle(
                  backgroundColor: WidgetStateProperty.all(Colors.cyan),
                ),
                child: const Text("发起get请求",
                    style: TextStyle(color: Colors.black, fontSize: 16)),
              ),

              TextButton(
                onPressed: () {
                  RxNet().showDebugWindow(context);
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
                      style:
                          const TextStyle(color: Colors.black, fontSize: 12))),
            ],
          ))
        ],
      ),
    );
  }

  void request({String? code}) async {
    // RxNet().setHeaders({
    //   "User-Agent": "PostmanRuntime-ApipostRuntime/1.1.0",
    //   "Cache-Control": "no-cache",
    //   "Accept": "*",
    //   "Accept-Encoding": "gzip, deflate, br",
    //   "Connection": "keep-alive",
    // });

    RxNet.get()
        .setPath('api/weather/')
        .setParam("city", code??"101030100")
        .setRestfulUrl(true)
         // .setCancelToken(tag)
        ///Restful  http://t.weather.sojson.com/api/weather/city/101030100
        .setCacheMode(CacheMode.cacheNoneToRequest)
        // .setJsonConvert(NewWeatherInfo.fromJson)
        .setJsonConvert(NewWeatherInfo.fromJson)
        .setRetryCount(2)  //重试次数
        .setRetryInterval(7000) //毫秒
        .setFailRetry(true)
        .setCacheInvalidationTime(1000*10)  //毫秒
        // .setRequestIgnoreCacheTime()
        .execute<NewWeatherInfo>(
            success: (data, source) {
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
  }

  void request1() async {

    final data = await RxNet.get()
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setRestfulUrl(true)
        .setCacheMode(CacheMode.onlyRequest)
        // .setJsonConvert((data) => NewWeatherInfo.fromJson(data))
        .setJsonConvert(NewWeatherInfo.fromJson)
        .executeAsync();

      debugPrint("--------->#${data.isError}");
      var result = data.value;

      // content = jsonEncode(result);

      content = jsonEncode(result?.toJson());
      sourcesType = data.model;

      setState(() {});
    }
}
