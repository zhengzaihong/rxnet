import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxnet/rxnet_lib.dart';
import 'package:rxnet_example/bean/BaseBean.dart';
import 'package:rxnet_example/bean/water_info_entity.dart';

void main() {
  RxNet().init(
      baseUrl: "http://t.weather.sojson.com/",
      interceptors: [
      CustomLogInterceptor()
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'Flutter Rxnet',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Rxnet Home Page'),
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
    test();
    return Scaffold(
      body: Center(
        child: Column(
          // horizontal).
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
          ],
        ),
      ),
    );
  }


  void test() async{
    RxNet.get()
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setEnableRestfulUrl(true) ///Restful
        .setCacheMode(CacheMode.onlyCache)
        .setJsonConvertAdapter(
          JsonConvertAdapter<WaterInfoEntity>((data){
            ///这里利用了idea jsonToDart 插件
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
            print("---------数据：->${source.name}");
            print("---------222->${data.toString()}");
            ///数据来源是网络
            /// 界面上可以分别处理或提示 来源等
            if(source == SourcesType.net){
            }else{
              /// 本地数据库
            }
         });
  }

  void download() async{

    requestPermission();
    Directory? appDocDir =  await getExternalStorageDirectory();
    String? appDocPath = appDocDir?.path;

    print("------>${appDocPath}");

    RxNet.get()
        .setPath("https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
        .download(
          savePath:"${appDocPath}/55.jpg",
          onReceiveProgress: (len,total){
            print("len:$len,total:$total");
          });
  }

  ///请求系统权限，让用户确认授权
  void requestPermission()  {
    List<Permission> permissions = <Permission>[
      Permission.storage
    ];

    permissions.forEach((element) {
      element.request().then((value){
        print("------permissions：${value.name}");
      });
    });

  }


}
