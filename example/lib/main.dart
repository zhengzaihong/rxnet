import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:rxnet_plus/rxnet_lib.dart';

import 'demo/demo_app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await RxNet.init(
    config: RxNetConfig(
      isDebug: kDebugMode,
      baseUrl: 'https://jsonplaceholder.typicode.com',
      cacheMode: CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST,
      cacheMaxSize: 200,
      cacheEvictionPolicy: CacheEvictionPolicy.lru,
      adapter: DioAdapter(),
      adapterBaseOptions: const AdapterBaseOptions(
        connectTimeout: Duration(seconds: 10),
        sendTimeout: Duration(seconds: 15),
        receiveTimeout: Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
      interceptors: [
        RxNetLogAdapterInterceptor(logSensitiveData: false),
      ],
    ),
  );

  runApp(const RxNetDemoApp());
}