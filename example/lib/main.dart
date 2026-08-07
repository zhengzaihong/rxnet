import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxnet_plus/rxnet_lib.dart';
import 'package:uikit_plus/toast/toast_utils.dart';
import 'package:uikit_plus/uikit_lib.dart';
import 'enhanced_example.dart';

void main() async {
  final adapter = DioAdapter();
  // adapter.dio.httpClientAdapter = IOHttpClientAdapter(
  //   createHttpClient: () {
  //     final client = HttpClient();
  //     client.badCertificateCallback = (cert, host, port) {
  //       // // 获取证书 DER
  //       // final der = cert.der;
  //       // final sha256 = sha256Convert(der);
  //       // const trustedFingerprint = "YOUR_SHA256_FINGERPRINT";
  //       // return sha256 == trustedFingerprint;
  //       return true;
  //     };
  //     return client;
  //   },
  // );

  // IOClient createPinnedClient() {
  //   final HttpClient httpClient = HttpClient();
  //   httpClient.badCertificateCallback =
  //       (X509Certificate cert, String host, int port) {
  //     // // 获取证书 DER
  //     // final der = cert.der;
  //     // final sha256 = sha256Convert(der);
  //     // const trustedFingerprint = "YOUR_SHA256_FINGERPRINT";
  //     // return sha256 == trustedFingerprint;
  //         return true;
  //   };
  //   return IOClient(httpClient);
  // }
  // final adapter2 = HttpAdapter(client: createPinnedClient());

  await RxNet.init(
      config: RxNetConfig(
          isDebug: kDebugMode,
          baseUrl: "http://t.weather.sojson.com/",
          cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
          baseCheckNet: checkNet,
          adapter: adapter,
          cacheInvalidationTime: 365 * 24 * 60 * 60 * 1000,
          adapterBaseOptions: const AdapterBaseOptions(
            connectTimeout: Duration(seconds: 10),
            sendTimeout:  Duration(seconds: 10),
            receiveTimeout: Duration(seconds: 30),
            headers: {'Authorization': 'Bearer token'},
          ),
          interceptors: [
            RxNetLogAdapterInterceptor(),
      ]));

  await RxNet.saveCache("name", "张三");
  final value = await RxNet.readCache<String>("name");
  LogUtil.v("value:$value"); //输出：张三
  //或者
  Future.delayed(const Duration(seconds: 5), () async {
    final result = await RxNet.readCache<String>("name");
    LogUtil.v("result:$result"); //输出：张三
  });

  runApp(const MyApp());
}

Future<bool> checkNet() async {
  // var connectivityResult = await (Connectivity().checkConnectivity());
  // if (connectivityResult == ConnectivityResult.none) {
  //   Toast.show("当前无网络");
  //   return false;
  // }
  return Future.value(true);
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter RxNet',
      navigatorKey: Toast.navigatorState,
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const EnhancedExample(),
    );
  }
}
