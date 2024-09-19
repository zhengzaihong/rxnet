import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2024/9/10
/// create_time: 14:53
/// describe: 展示调试界面
///
class DebugPage extends StatelessWidget {

  const DebugPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifier = RxNet().debugWindowSizeNotifier;
    final logNotifier = RxNet().logsNotifier;
    return Scaffold(
      appBar: AppBar(
        elevation: 2,
        title: const Text('调试界面'),
        actions: [

          ElevatedButton(
            onPressed: () {
              final size = notifier.value;
              notifier.value = Size(size.width+50, size.height);
            },
            child: const Text('加宽'),
          ),

          ElevatedButton(
            onPressed: () {
              final size = notifier.value;
              notifier.value = Size(size.width-50, size.height);
            },
            child: const Text('减宽'),
          ),

          ElevatedButton(
            onPressed: () {
              final size = notifier.value;
              notifier.value = Size(size.width, size.height+50);
            },
            child: const Text('加高'),
          ),
          ElevatedButton(
            onPressed: () {
              final size = notifier.value;
              notifier.value = Size(size.width, size.height-50);
            },
            child: const Text('减高'),
          ),

          ElevatedButton(
            onPressed: () {
              RxNet().closeDebugWindow();
            },
            child: const Text('关闭调试'),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ValueListenableBuilder<List<String>>(
              valueListenable: logNotifier,
              builder: (context, logs, widget) {
                return ListView.builder(
                  itemCount: RxNet().logsNotifier.value.length,
                  itemBuilder: (context, index) {
                    return Text(RxNet().logsNotifier.value[index],style: TextStyle(fontSize: 12),);
                  },
                );
              },
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              ElevatedButton(
                onPressed: () {
                  RxNet().clearLogs();
                },
                child: const Text('清除日志'),
              ),
              ElevatedButton(
                onPressed: () {
                  StringBuffer buffer = StringBuffer();
                  final logs = RxNet().logsNotifier.value;
                  for (int i = 0; i < logs.length; i++) {
                    buffer.write(logs[i]);
                    buffer.write("\r\n");
                  }
                  Clipboard.setData(ClipboardData(text: buffer.toString()))
                      .then((_) {
                     ScaffoldMessenger.of(context).showSnackBar(
                       const SnackBar(
                         content: Text('复制成功'),
                       ),
                     );
                  });
                },
                child: const Text('复制日志信息'),
              ),
            ],
          )
        ],
      ),
    );
  }
}
