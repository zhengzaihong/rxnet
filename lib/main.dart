import 'dart:collection';

import 'package:flutter/material.dart';
import 'package:rxnet/net/RxNet.dart';
import 'package:rxnet/net/cache_mode.dart';
import 'package:rxnet/net/interceptor/CustomLogInterceptor.dart';

void main() {
  RxNet().init(baseUrl: "",interceptors: [
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
    RxNet.get<Map<String,dynamic>>()
        .setPath("https://openapi.dataoke.com/api/goods/get-dtk-search-goods")
        .setCacheMode(CacheMode.firstCacheThenRequest)
        .call(success: (data,mo){
          print("---------->$data");
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
