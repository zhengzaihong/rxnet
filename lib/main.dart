import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rxnet/net/RxNet.dart';
import 'package:rxnet/net/cache_mode.dart';
import 'package:rxnet/net/interceptor/CustomLogInterceptor.dart';
import 'package:rxnet/net/json_convert_adapter.dart';
import 'package:rxnet/test/BaseBean.dart';
import 'package:rxnet/test/test_json_convert_entity.dart';

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
    RxNet.get()
        .setPath("api/goods/get-dtk-search-goods")
        .setCacheMode(CacheMode.firstCacheThenRequest)
        .setJsonConvertAdapter(
         JsonConvertAdapter<TestJsonConvertEntity>((data){
           var base =  BaseBean<TestJsonConvertEntity>.fromJson(data);
           return base.data;
         }))
        .call(success: (data,mo){
          if(data is TestJsonConvertEntity){
            print("---------->${data.pageId}");
          }
          print("---------22222->${data}");
          print("----------333>${(mo as DataModel).name}");
    });

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
}
