import 'dart:async';
import 'dart:io';
import 'package:flutter_rxnet_forzzh/utils/LogUtil.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'PlatformTools.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2023/9/9
/// create_time: 12:41
/// describe: 数据缓存
///
extension HiveExt on HiveInterface {
  Future<Box<T>> openBoxSafe<T>(String name,
      {HiveCipher? encryptionCipher}) async {
    try {
      return await openBox<T>(
        name,
        encryptionCipher: encryptionCipher,
        compactionStrategy: (entries, deleted) => false,
      );
    } catch (error) {
      await Hive.deleteBoxFromDisk(name);
      return openBox<T>(name);
    }
  }
}

class RxNetDataBase {
  static Future<Box<dynamic>>? _box;
  static bool isDatabaseReady = false;
  static final List<Function> _checkDataBaseListener = [];

  RxNetDataBase();

  static Future initDatabase({
    Directory? directory,
    String? hiveBoxName = 'local_cache',
    HiveCipher? encryptionCipher,
  }) {
    Future future = Future(() async {
      Directory? appDir = directory;

      try{
        if (PlatformTools.isWindows) {
          appDir = appDir??await getApplicationSupportDirectory();
        } else if (PlatformTools.isLinux) {
          final home = Platform.environment['HOME'];
          appDir = appDir??Directory(join(home!, '.rxnet_local_cache'));
        } else if(PlatformTools.isAndroidOrIOS){
          appDir = appDir??await getTemporaryDirectory();
        } else{
          appDir = appDir??await getApplicationDocumentsDirectory();
        }
      }catch (e){
        appDir = appDir??await getTemporaryDirectory();
      }
      Hive.init(p.join(appDir.path, 'rxnet_local_cache'));
      _box = Hive.openBoxSafe(hiveBoxName!, encryptionCipher: encryptionCipher);
      isDatabaseReady = true;
      for (var callBack in _checkDataBaseListener) {
        callBack.call(isDatabaseReady);
      }
      _checkDataBaseListener.clear();
    });
    return future;
  }

  ///数据库还没初始完成，可能已经存在网络请求，先将其缓存
  ///等待数据库完成后并返回数据后，将其全部回调全部清除。
  static void setDataBaseReadListener(Function(bool isOk) function) {
    if (!isDatabaseReady) {
      _checkDataBaseListener.add(function);
    }
  }

  FutureOr operator [](dynamic key) async {
    return get(key);
  }

  void operator []=(dynamic key, dynamic value) {
    put(key, value);
  }

  Future<T?> get<T>(dynamic key) async {
    final box = await _box;
    try {
      return box?.get(key) as T?;
    } catch (error, stackTrace) {
      LogUtil.v('get $key error: $error\n$stackTrace');
    }
  }

  Future put(
    dynamic key,
    dynamic value,
  ) async {
    final box = await _box;
    try {
      await box?.put(key, value);
    } catch (error, stacktrace) {
      LogUtil.v('LocalData put error: $error\n$stacktrace');
    }
  }

  Future<void> clean() async {
    final box = await _box;
    return box?.deleteAll(box.keys);
  }

  Future<void> delete(String key) async {
    final box = await _box;
    final resp = await box?.get(key);
    if (resp == null) return Future.value();

    await box?.delete(key);
  }

  Future<bool> exists(String key) async {
    final box = await _box;
    return box!.containsKey(key);
  }
}
