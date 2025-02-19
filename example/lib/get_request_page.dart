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
  // 35b3914e389f495d790f30b455004910c318c6743719fca30b4f58094bcc42c1
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
          TextButton(
            onPressed: () {
              request(code: '101030100');
              // request1();
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.cyan),
            ),
            child: const Text("发起get请求",
                style: TextStyle(color: Colors.black, fontSize: 16)),
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
    // RxNet().getCancelToken("tag");

    RxNet.get()
        .setPath('api/weather/')
        // .setPath('api/v1/default/getWeather')
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
        // .execute(
        .execute<NewWeatherInfo>(
            success: (data, source) {
              content = jsonEncode(data);
              sourcesType = source;
              setState(() {});
            },
            failure: (e) {
              content = "";
              setState(() {});
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

      print("--------->#${data.isError}");
      print("--------->#${data.error}");
      var result = data.value;

      // print("--------->#${result}");
      // content = jsonEncode(result);

      content = jsonEncode(result?.toJson());
      sourcesType = data.model;

      setState(() {});
    }
}
