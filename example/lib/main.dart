import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';
import 'package:flutter_uikit_forzzh/uikitlib.dart';
import 'package:rxnet_example/get_request_page.dart';
import 'download_page.dart';
// import 'package:connectivity_plus/connectivity_plus.dart';

void main() async {
  await RxNet.init(
      baseUrl: "http://t.weather.sojson.com/",
      // cacheDir: "xxx",   ///缓存目录
      // cacheName: "local_cache", ///缓存文件
      baseCacheMode: CacheMode.REQUEST_FAILED_READ_CACHE,
      //请求失败读取缓存数据
      baseCheckNet: checkNet,
      //全局检查网络，所有的请求都走这个方法
      cacheInvalidationTime: 365 * 24 * 60 * 60 * 1000,
      //缓存时效毫秒，默认时间
      // baseUrlEnv: {  ///支持多环境 baseUrl调试，RxNet.setDefaultEnv("test") 方式切换;
      //   "test": "http://t.weather.sojson1.com/",
      //   "debug": "http://t.weather.sojson2.com/",
      //   "release": "http://t.weather.sojson.com/",
      // },
      interceptors: [
        //TokenInterceptor // token拦截器，更多功能请自定义拦截器
        ///日志拦截器
        RxNetLogInterceptor()
        //ResponseInterceptor() //响应拦截器，预处理结果
      ]);
  //
  //   RxNet.getDefaultClient()?.httpClientAdapter = IOHttpClientAdapter(
  //     createHttpClient: () {
  //       final client = HttpClient();
  //       // 在这里进行自定义配置，例如证书校验等：
  //       // 设置为 false，表示默认拒绝所有无效证书
  //       client.badCertificateCallback = (X509Certificate cert, String host, int port) {
  //         // 你可以在这里添加更复杂的校验逻辑，例如校验证书指纹或颁发机构
  //         // 你的可能是xx.pem 等文件，读取出来再校验
  //         const trustedFingerprint = 'AB:CD:EF:12:34:56:78:90:AB:CD:EF:12:34:56:78:90:AB:CD:EF:12';
  //         final certFingerprint = cert.sha1.toString().toUpperCase();
  //         final isTrusted = certFingerprint == trustedFingerprint;
  //         // 只有当证书可信时才允许请求
  //         return isTrusted;
  //       };
  //       return client;
  //     },
  //   );

  RxNet.saveCache("name", "张三");
  RxNet.readCache("name").then((value) {
    LogUtil.v(value); //输出：张三
  });
  //或者
  Future.delayed(const Duration(seconds: 5), () async {
    final result = await RxNet.readCache("name");
    LogUtil.v(result); //输出：张三
  });

  runApp(const MyApp());
}

Future<bool> checkNet() async {
  // var connectivityResult = await (Connectivity().checkConnectivity());
  // if (connectivityResult == ConnectivityResult.none) {
  //   Toast.show("当前无网络");
  //   return false;
  // }
  return Future.value(true);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter RxNet',
      navigatorKey: Toast.navigatorState,
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
          hGap(10),
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
                backgroundColor: WidgetStateProperty.all(Colors.cyan),
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
