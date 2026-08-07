
import 'package:flutter/material.dart';
import 'package:rxnet_plus/logcat/debug_page.dart';
import 'package:rxnet_plus/logcat/drag_box.dart';

import '../src/rx_net.dart';

///
/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2025-08-12
/// time: 15:56
/// describe: 优化调试界面
///
class DebugManager {
  static final DebugManager _instance = DebugManager._internal();
  factory DebugManager() => _instance;
  DebugManager._internal();

  OverlayEntry? _overlayEntry;

  void showDebugWindow(BuildContext context) {
    RxNet.I.setCollectLogs(true);
    closeDebugWindow();
    OverlayState? overlayState = Overlay.of(context);
    Size size = MediaQuery.of(context).size;
    _overlayEntry = OverlayEntry(
      builder: (context) => SizedBox(
        width: size.width,
        height: size.height,
        child: Center(
          child: DragBox(
              child: ValueListenableBuilder<Size>(
                  valueListenable: RxNet.debugWindow,
                  builder: (context, value, child) {
                    return SizedBox(
                      width: value.width,
                      height: value.height,
                      child: const DebugPage(),
                    );
                  })),
        ),
      ),
    );
    overlayState.insert(_overlayEntry!);
  }

  void closeDebugWindow() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }
}
