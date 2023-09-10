import 'dart:async';
import 'dart:io';

import 'package:flutter_rxnet_forzzh/utils/LogUtil.dart';
import 'package:hive/hive.dart';
import 'package:path/path.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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


class HiveDataBase {

  static Future<Box<dynamic>>? _box;

  HiveDataBase({
    String? directory,
    String? hiveBoxName = 'local_cache',
    HiveCipher? encryptionCipher,
  }) {
    if (directory != null) {
       Hive.init(directory);
    }else{
      Directory appDir;
      Future(() async {
        if (Platform.isWindows) {
          appDir = await getApplicationSupportDirectory();
        }else if (Platform.isLinux) {
          final home = Platform.environment['HOME'];
          appDir = Directory(join(home!, '.rxnet_local_cache'));
        } else{
          appDir = await getApplicationDocumentsDirectory();
        }
        Hive.init(p.join(appDir.path, 'rxnet_local_cache'));
        _box = Hive.openBoxSafe(hiveBoxName!, encryptionCipher: encryptionCipher);
      });
      return;
    }
    _box = Hive.openBoxSafe(hiveBoxName!, encryptionCipher: encryptionCipher);
  }

  FutureOr operator [](dynamic key) async {
    return get(key);
  }

  void operator []=(dynamic key, dynamic value) {
    put(value, key);
  }

  Future<T?> get<T>(dynamic key) async {
    final box = await _box;
    try {
      return box?.get(key) as T?;
    } catch (error, stackTrace) {
      LogUtil.v('get $key error: $error\n$stackTrace');
    }
  }

  Future put(dynamic value, [dynamic key]) async {
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
