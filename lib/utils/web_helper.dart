import 'dart:html';
import 'package:rxnet_plus/utils/rx_net_platform.dart';



///下载文件 Web端
///[url] 下载路径，get方式，有参数需拼接在连接上
void download({required String? url}) {
  if (RxNetPlatform.isWeb) {
    AnchorElement(href: url)
      ..download = url
      ..click();
  }
}
