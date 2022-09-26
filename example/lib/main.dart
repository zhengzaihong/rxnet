import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';
import 'package:flutter_uikit_forzzh/uikitlib.dart';
import 'package:rxnet_example/get_request_page.dart';

import 'download_page.dart';

void main() {

  RxNet().init(
      baseUrl: "http://t.weather.sojson.com/",
      dbName: "test",   ///数据库名字
      tableName: "project", ///表明
      isDebug: true,   ///是否调试 打印日志
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
