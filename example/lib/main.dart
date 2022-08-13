import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:rxnet_example/bean/BaseBean.dart';
import 'package:rxnet_example/bean/water_info_entity.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';

void main() {
  RxNet().init(
      baseUrl: "http://t.weather.sojson.com/",
      dbName: "test", ///数据库名字
      tableName: "project" ,///表明
      isDebug: true, ///是否调试 打印日志
      interceptors: [  ///拦截器
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
    return Scaffold(
      body: Column(
        children:  <Widget>[
          SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: (){
                    request();
                  },
                  style: ButtonStyle(
                    backgroundColor:MaterialStateProperty.all(Colors.cyan),
                  ),
                  child: Text("发起get请求",style: TextStyle(color: Colors.black,fontSize: 16)),),


                TextButton(
                  onPressed: (){
                    download();
                  },
                  style: ButtonStyle(
                    backgroundColor:MaterialStateProperty.all(Colors.cyan),
                  ),
                  child: Text("下载",style: TextStyle(color: Colors.black,fontSize: 16)),),
          ]),

          Expanded(child:Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text("数据来源：${sourcesType == SourcesType.net ? "网络" :"缓存"}",style: const TextStyle(color: Colors.black,fontSize: 16)),
              Expanded(
                flex: 2,
                  child: Text(content,style:const TextStyle(color: Colors.black,fontSize: 12))),

              Expanded(child: Row(
                children: [
                  Text("保存地址：$downloadPath",style: const TextStyle(color: Colors.black,fontSize: 16)),
                ],
              ))
            ],
          ))

        ],
      ),
    );
  }


  SourcesType sourcesType =SourcesType.net;
  String content = "";

  void request() {
    RxNet.get()
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setEnableRestfulUrl(true) ///Restful
        .setCacheMode(CacheMode.onlyRequest)
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
              content = data.toString();
            }
            print("---------->${data.toString()}");
            ///数据来源是网络
            /// 界面上可以分别处理或提示 来源等
            if(source == SourcesType.net){
            }else{
              /// 本地数据库
            }
            setState(() {});
      });
  }

  String downloadPath = "";
  void download() async{

    requestPermission();
    Directory? appDocDir =  await getExternalStorageDirectory();
    String? appDocPath = "${appDocDir?.path}/test.jpg";


    RxNet.get()
        .setPath("https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg")
        .download(
          savePath:appDocPath,
          onReceiveProgress: (len,total){
            print("len:$len,total:$total");
            if(len ==total){
              downloadPath = appDocPath;
              setState(() {

              });
            }
          });

  }

  ///请求系统权限，让用户确认授权
  void requestPermission()  {
    List<Permission> permissions = <Permission>[
      Permission.storage
    ];

    for (var element in permissions) {
      element.request().then((value){
        print("------permissions：${value.name}");
      });
    }
  }


}
