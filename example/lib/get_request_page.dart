import 'package:flutter/material.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';
import 'package:rxnet_example/bean/normal_water_info_entity.dart';

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
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const SizedBox(height: 40),
          TextButton(
            onPressed: () {
              RxNet().setEnv('release');
              request();
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.cyan),
            ),
            child: const Text("发起get请求",
                style: TextStyle(color: Colors.black, fontSize: 16)),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              RxNet().setEnv('test');
              request();
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.cyan),
            ),
            child: const Text("测试环境",
                style: TextStyle(color: Colors.black, fontSize: 16)),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              RxNet().setEnv('debug');
              request();
            },
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.cyan),
            ),
            child: const Text("debug环境测试",
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

  void request() async {
    // RxNet().setHeaders({
    //   "Authorization": "bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjo2LCJ1c2VyX3R5cGUiOmZhbHNlLCJleHAiOjE2ODM0NDM3ODh9.K1GPsVGsvKc_6LN2iMdow6HRT_J-mlisDUtg6o1_vyY",
    // });
    // RxNet().getCancelToken("tag");

    RxNet.get()
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setRestfulUrl(true)
         // .setCancelToken(tag)
        ///Restful  http://t.weather.sojson.com/api/weather/city/101030100
        // .setCacheMode(CacheMode.onlyCache)
        // .setJsonConvert((data) => NormalWaterInfoEntity.fromJson(data))
        .setJsonConvert((data)=> NormalWaterInfoEntity.fromJson(data))
        .execute<NormalWaterInfoEntity>(
            success: (data, source) {
              content = data.toString();
              sourcesType = source;
              setState(() {});
            },
            failure: (e) {
              content = "null";
              setState(() {});
              print("----------e$e");
            });
  }

  void request1() async {

    var data = await RxNet.get()
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

      setState(() {});
    }
}
