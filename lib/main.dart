import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:rxnet/rxnet_lib.dart';
import 'package:rxnet/test/BaseBean.dart';
import 'package:rxnet/test/test_json_convert_entity.dart';
import 'package:permission_handler/permission_handler.dart';

void main() {
  RxNet().init(baseUrl: "https://openapi.dataoke.com/",interceptors: [
    CustomLogInterceptor()
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {

    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
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

    requestPermission();
    Directory? appDocDir =  await getApplicationSupportDirectory();
    String? appDocPath = appDocDir?.path;
    print("------>${appDocPath}");

    RxNet.get()
        .setPath("api/goods/get-dtk-search-goods")
        .setCacheMode(CacheMode.firstCacheThenRequest)
        .setJsonConvertAdapter(
        JsonConvertAdapter<TestJsonConvertEntity>((data){
          var base =  BaseBean<TestJsonConvertEntity>.fromJson(data);
          return base.data;
        }))
        .download(
        url: "https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg",
        savePath:"${appDocPath}/55.jpg",
        onReceiveProgress: (len,total){
          print("len:$len,total:$total");

        }
    );
    // .execute(success: (data,mo){
    //   if(data is TestJsonConvertEntity){
    //     print("---------->${data.pageId}");
    //   }
    //   print("----------333>${(mo as SourcesType).name}");
    // });
  }

  /**
   * 请求系统权限，让用户确认授权
   */
  void requestPermission()  {
    List<Permission> permissions = <Permission>[
      Permission.storage
    ];
    permissions.forEach((element) {
      element.request();
    });

  }


}
