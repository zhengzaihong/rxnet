总结与建议

* 对于普通请求：你可以安全地使用 execute() 或 await request()，资源会自动释放。
* 对于循环请求：
    * 不要使用 await request()，因为它现在只会给你第一个结果。
    * 必须使用 executeStream().listen()，并保存它返回的 StreamSubscription 对象。
    * 在你不再需要接收轮询结果时（例如，在 Flutter 的 StatefulWidget 的 dispose 方法中），必须调用
      `subscription.cancel()` 来停止轮询并释放资源。

正确使用循环请求的示例代码：


     import 'dart:async';
     import 'package:flutter/material.dart';
    
     class MyWidget extends StatefulWidget {
      @override
       _MyWidgetState createState() => _MyWidgetState();
     }
    
     class _MyWidgetState extends State<MyWidget> {

        StreamSubscription? _pollingSubscription;
        
        @override
        void initState() {
         super.initState();
         startPolling();
        }
        
        void startPolling() {
         // 取消之前的订阅，以防万一
         _pollingSubscription?.cancel();
        
         _pollingSubscription = RxNet.get()
             .setPath("your/api")
             .setLoop(true, interval: Duration(seconds: 7))
             .executeStream() // 直接使用 executeStream
             .listen((result) {
           if (result.isSuccess) {
             print("Polling success: ${result.value}");
           } else {
             print("Polling attempt failed: ${result.error}");
           }
         });
        }
        
        @override
        void dispose() {
         // 这是最关键的一步！
         // 在 Widget 销毁时，取消订阅以停止轮询并释放内存。
         _pollingSubscription?.cancel();
         super.dispose();
        }
        
        @override
        Widget build(BuildContext context) {
         // ... your widget UI
         return Container();
        }
 }