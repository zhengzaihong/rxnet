import 'package:flutter/material.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';
import 'package:flutter_uikit_forzzh/uikitlib.dart';
import 'package:rxnet_example/get_request_page.dart';
import 'download_page.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

void main() async{

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


  runApp(const MyApp());
}



Future<bool> checkNet() async{
  var connectivityResult = await (Connectivity().checkConnectivity());
  if (connectivityResult == ConnectivityResult.none) {
    print( "当前无网络");
    return true;
  }
  return Future.value(true);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter RxNet',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter RxNet Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          buildButton("getDemo", const GetRequestPage()),
          buildButton("download demo", const DownLoadPage())
        ],
      ),
    );
  }

  Widget buildButton(String name, Widget page) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          height: 60,
          width: 200,
          margin: const EdgeInsets.only(top: 30),
          child: GestureDetector(
              child: Row(children: [
            Expanded(
                child: TextButton(
              onPressed: () {
                RouteUtils.push(context, page);
              },
              style: ButtonStyle(
                backgroundColor: MaterialStateProperty.all(Colors.cyan),
              ),
              child: Text(name,
                  style: const TextStyle(color: Colors.black, fontSize: 16)),
            ))
          ])),
        )
      ],
    );
  }
}
