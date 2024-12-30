
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownLoadPage extends StatefulWidget {

  const DownLoadPage({Key? key}) : super(key: key);

  @override
  State<DownLoadPage> createState() => _DownLoadPageState();
}

class _DownLoadPageState extends State<DownLoadPage> {

  SourcesType sourcesType =SourcesType.net;
  String content = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children:  <Widget>[
          const SizedBox(height: 40),

          TextButton(
            onPressed: (){
              download();
            },
            style: ButtonStyle(
              backgroundColor:MaterialStateProperty.all(Colors.cyan),
            ),
            child: const Text("下载",style: TextStyle(color: Colors.black,fontSize: 16)),),

          Expanded(child: Row(
            children: [
              Text("保存地址：$downloadPath",style: const TextStyle(color: Colors.black,fontSize: 16)),
            ],
          ))

        ],
      ),
    );
  }


  String downloadPath = "";
  void download() async{

    if(RxNetPlatform.isWeb){
      Downloader.downloadFile(url: "https://img2.woyaogexing.com/2022/08/02/b3b98b98ec34fb3b!400x400.jpg");
      return;
    }

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
            setState(() {
              downloadPath = appDocPath;
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
