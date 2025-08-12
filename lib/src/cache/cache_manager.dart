
import 'dart:io';
import 'package:hive/hive.dart';

import '../../utils/rx_net_database.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2025-08-12
/// create_time: 16:32
/// describe: 本地数据库--缓存使用
/// 支持少量键值对的方式代替数据库存储
///
class CacheManager {
  RxNetDataBase? _dataBase;

  Future<void> init(Directory? cacheDir, String cacheName, HiveCipher? encryptionCipher) async {
    _dataBase = RxNetDataBase();
    await RxNetDataBase.initDatabase(
        directory: cacheDir,
        hiveBoxName: cacheName,
        encryptionCipher: encryptionCipher);
  }

  Future<void> saveCache(String key, dynamic value) async {
    return await _dataBase?.put(key, value);
  }

  Future<dynamic> readCache(String key) async {
    return await _dataBase?.get(key);
  }

  RxNetDataBase? getDb() {
    return _dataBase;
  }
}
