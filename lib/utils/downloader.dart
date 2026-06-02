import 'native_helper.dart'
    if (dart.library.io) 'native_helper.dart'
    if (dart.library.html) 'web_helper.dart' as downloader;

///
/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2023/9/26
/// time: 12:17
/// describe: 只提供给 web端
///
class Downloader {
  Downloader._();

  ///下载文件 Web端
  ///[url] 下载路径，get方式，有参数需拼接在连接上
  static void downloadFile({required String? url}) {
    downloader.download(url: url);
  }
}
