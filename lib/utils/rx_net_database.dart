import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rxnet_plus/utils/rx_net_platform.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'log_util.dart';

///
/// author: zhengzaihong
/// email:1096877329@qq.com
/// date: 2023/9/9
/// time: 12:41
/// describe: 数据缓存 全平台支持（包括 Web 和 HarmonyOS）
/// 纯 Dart 实现的 NoSQL 数据库，支持所有平台：
/// - Android/iOS: 使用文件系统
/// - Windows/Linux/macOS: 使用文件系统
/// - Web: 使用 IndexedDB
/// - HarmonyOS: 使用文件系统（纯 Dart 实现）
///
class RxNetDataBase {
  static Database? _db;
  static final StoreRef<String, dynamic> _store = StoreRef.main();
  static bool isDatabaseReady = false;
  static final List<void Function(bool isOk)> _checkDataBaseListener = [];
  static Future<void>? _initFuture;

  RxNetDataBase();

  /// 初始化数据库
  /// 
  /// [databaseName] 数据库名称，默认为 'rxnet_cache.db'
  /// [databasePath] 自定义数据库路径（可选）
  /// 
  /// Web 平台会自动使用 IndexedDB，其他平台使用文件系统
  static Future<void> initDatabase({
    String databaseName = 'rxnet_cache.db',
    String? cacheName = 'network_cache',
    String? databasePath,
  }) {
    if (isDatabaseReady && _db != null) {
      return Future.value();
    }

    final pendingInit = _initFuture;
    if (pendingInit != null) {
      return pendingInit;
    }

    final future = _doInitDatabase(
      databaseName: databaseName,
      cacheName: cacheName,
      databasePath: databasePath,
    );
    _initFuture = future;
    return future;
  }

  /// 数据库还没初始完成，可能已经存在网络请求，先将其缓存；等待数据库完成后并返回数据后，将其全部回调全部清除。
  /// The database has not yet been initially completed, and there may already be network requests.
  /// Cache them first; wait for the database to complete and return data, and clear all their callbacks.
  @Deprecated('Await RxNet.init() or RxNetDataBase.ready instead')
  void setDataBaseReadListener(void Function(bool isOk) function) {
    if (isDatabaseReady && _db != null) {
      function(true);
      return;
    }

    _checkDataBaseListener.add(function);
  }

  /// 等待数据库初始化完成。
  Future<void> get ready => waitUntilReady();

  static Future<void> waitUntilReady() async {
    if (isDatabaseReady && _db != null) {
      return;
    }

    final initFuture = _initFuture;
    if (initFuture == null) {
      throw StateError(
        'RxNetDataBase has not been initialized. Call RxNet.init() first.',
      );
    }

    await initFuture;

    if (!isDatabaseReady || _db == null) {
      throw StateError('RxNetDataBase is not ready.');
    }
  }

  /// 操作符重载：读取数据
  Future operator [](dynamic key) async {
    return get(key);
  }

  /// 操作符重载：写入数据
  void operator []=(dynamic key, dynamic value) {
    put(key, value);
  }

  /// 获取数据
  /// 
  /// [key] 数据键
  /// 返回存储的值，如果不存在返回 null
  Future<T?> get<T>(dynamic key) async {
    final db = await _resolveDatabase();
    if (db == null) {
      return null;
    }

    try {
      final value = await _store.record(key.toString()).get(db);
      return value as T?;
    } catch (error, stackTrace) {
      LogUtil.v('RxNetDataBase: get $key error: $error\n$stackTrace');
      return null;
    }
  }

  /// 存储数据
  /// 
  /// [key] 数据键
  /// [value] 数据值（支持所有 JSON 可序列化的类型）
  Future put(
    dynamic key,
    dynamic value,
  ) async {
    final db = await _resolveDatabase();
    if (db == null) {
      return;
    }

    try {
      await _store.record(key.toString()).put(db, value);
    } catch (error, stacktrace) {
      LogUtil.v('RxNetDataBase: put error: $error\n$stacktrace');
    }
  }

  /// 清空所有数据
  Future<void> clean() async {
    final db = await _resolveDatabase();
    if (db == null) {
      return;
    }

    try {
      await _store.delete(db);
      LogUtil.v('RxNetDataBase: All data cleaned');
    } catch (error, stacktrace) {
      LogUtil.v('RxNetDataBase: clean error: $error\n$stacktrace');
    }
  }

  /// 删除指定键的数据
  /// 
  /// [key] 要删除的数据键
  Future<void> delete(String key) async {
    final db = await _resolveDatabase();
    if (db == null) {
      return;
    }

    try {
      await _store.record(key).delete(db);
    } catch (error, stacktrace) {
      LogUtil.v('RxNetDataBase: delete error: $error\n$stacktrace');
    }
  }

  /// 检查键是否存在
  /// 
  /// [key] 要检查的数据键
  /// 返回 true 如果键存在，否则返回 false
  Future<bool> exists(String key) async {
    final db = await _resolveDatabase();
    if (db == null) {
      return false;
    }

    try {
      final value = await _store.record(key).get(db);
      return value != null;
    } catch (error, stacktrace) {
      LogUtil.v('RxNetDataBase: exists error: $error\n$stacktrace');
      return false;
    }
  }

  /// 获取所有键
  /// 
  /// 返回数据库中所有键的列表
  Future<List<String>> getAllKeys() async {
    final db = await _resolveDatabase();
    if (db == null) {
      return [];
    }

    try {
      final records = await _store.find(db);
      return records.map((record) => record.key).toList();
    } catch (error, stacktrace) {
      LogUtil.v('RxNetDataBase: getAllKeys error: $error\n$stacktrace');
      return [];
    }
  }

  /// 获取数据库中的记录数量
  Future<int> count() async {
    final db = await _resolveDatabase();
    if (db == null) {
      return 0;
    }

    try {
      return await _store.count(db);
    } catch (error, stacktrace) {
      LogUtil.v('RxNetDataBase: count error: $error\n$stacktrace');
      return 0;
    }
  }

  /// 关闭数据库连接
  /// 
  /// 注意：关闭后需要重新调用 initDatabase 才能继续使用
  static Future<void> close() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      LogUtil.v('RxNetDataBase: Database closed');
    }

    _resetInitState();
  }

  static Future<void> _doInitDatabase({
    required String databaseName,
    required String? cacheName,
    required String? databasePath,
  }) async {
    try {
      if (kIsWeb) {
        // Web 平台：使用 IndexedDB
        LogUtil.v('RxNetDataBase: Initializing for Web platform (IndexedDB)');
        final factory = databaseFactoryWeb;
        _db = await factory.openDatabase(databaseName);
      } else {
        // 其他平台：使用文件系统
        String dbPath;

        if (databasePath != null) {
          // 使用自定义路径
          dbPath = p.join(databasePath, databaseName);
        } else {
          // 自动选择合适的路径
          try {
            if (RxNetPlatform.isWindows || RxNetPlatform.isMacOS) {
              final appDir = await getApplicationSupportDirectory();
              dbPath = p.join(appDir.path, cacheName, databaseName);
            } else if (RxNetPlatform.isLinux) {
              final appDir = await getApplicationSupportDirectory();
              dbPath = p.join(appDir.path, cacheName, databaseName);
            } else if (RxNetPlatform.isAndroid || RxNetPlatform.isIOS) {
              final appDir = await getApplicationDocumentsDirectory();
              dbPath = p.join(appDir.path, cacheName, databaseName);
            } else if (RxNetPlatform.isHarmonyOS) {
              // HarmonyOS 使用临时目录
              final appDir = await getTemporaryDirectory();
              dbPath = p.join(appDir.path, cacheName, databaseName);
            } else {
              // 默认使用文档目录
              final appDir = await getApplicationDocumentsDirectory();
              dbPath = p.join(appDir.path, cacheName, databaseName);
            }
          } catch (e) {
            // 如果获取路径失败，使用临时目录
            LogUtil.v(
              'RxNetDataBase: Failed to get app directory, using temp: $e',
            );
            final appDir = await getTemporaryDirectory();
            dbPath = p.join(appDir.path, cacheName, databaseName);
          }
        }

        LogUtil.v('RxNetDataBase: Initializing database at: $dbPath');
        final factory = databaseFactoryIo;
        _db = await factory.openDatabase(dbPath);
      }

      isDatabaseReady = true;
      LogUtil.v('RxNetDataBase: Database initialized successfully');
      _notifyReadyListeners(true);
    } catch (e, stackTrace) {
      LogUtil.v('RxNetDataBase: Failed to initialize database: $e\n$stackTrace');
      _db = null;
      _resetInitState(keepListeners: true);
      _notifyReadyListeners(false);
      rethrow;
    }
  }

  Future<Database?> _resolveDatabase() async {
    try {
      await ready;
      return _db;
    } catch (error, stackTrace) {
      LogUtil.v(
        'RxNetDataBase: Database not ready for operation: $error\n$stackTrace',
      );
      return null;
    }
  }

  static void _notifyReadyListeners(bool isOk) {
    final listeners = List<void Function(bool isOk)>.from(
      _checkDataBaseListener,
    );
    _checkDataBaseListener.clear();

    for (final callback in listeners) {
      callback(isOk);
    }
  }

  static void _resetInitState({bool keepListeners = false}) {
    isDatabaseReady = false;
    _initFuture = null;
    if (!keepListeners) {
      _checkDataBaseListener.clear();
    }
  }
}
