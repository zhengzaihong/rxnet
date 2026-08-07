import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:rxnet_plus/utils/rx_net_platform.dart';
import 'package:sembast/sembast_io.dart';
import 'package:sembast_web/sembast_web.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'log_util.dart';

///
/// author: ZhengZaiHong
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
  // 实例级别状态
  Database? _db;
  bool isDatabaseReady = false;
  Future<void>? _initFuture;

  // StoreRef 不含状态，可以安全共享
  static final StoreRef<String, dynamic> _store = StoreRef.main();

  // 缓存条目元数据 Store（用于 LRU/LFU/FIFO 淘汰策略）
  static final StoreRef<String, dynamic> _metadataStore = StoreRef('_metadata');

  // 用于静态方法向后兼容的默认实例
  static final RxNetDataBase _staticInstance = RxNetDataBase();

  RxNetDataBase();

  // ==================== 静态方法（向后兼容，委托给默认实例） ====================

  /// 初始化数据库（静态方法，向后兼容单例模式）
  static Future<void> initDatabase({
    String databaseName = 'rxnet_cache.db',
    String? cacheName = 'network_cache',
    String? databasePath,
  }) {
    return _staticInstance.init(
      databaseName: databaseName,
      cacheName: cacheName,
      databasePath: databasePath,
    );
  }

  /// 等待数据库初始化完成（静态方法，向后兼容）
  static Future<void> waitUntilReady() async {
    return _staticInstance.ready;
  }

  /// 关闭数据库连接（静态方法，向后兼容）
  static Future<void> close() async {
    return _staticInstance.closeInstance();
  }

  /// 获取默认实例的数据库就绪状态（静态方法，向后兼容）
  static bool get isReady => _staticInstance.isDatabaseReady;

  // ==================== 实例方法 ====================

  /// 初始化数据库（实例方法，支持多实例独立配置）
  Future<void> init({
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

  /// 等待数据库初始化完成
  Future<void> get ready async {
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
  Future put(dynamic key, dynamic value) async {
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

  /// 按前缀清理缓存
  Future<int> clearByPrefix(String prefix) async {
    final db = await _resolveDatabase();
    if (db == null) {
      return 0;
    }

    try {
      final records = await _store.find(db);
      final keysToDelete = records
          .where((record) => record.key.startsWith(prefix))
          .map((record) => record.key)
          .toList();

      for (final key in keysToDelete) {
        await _store.record(key).delete(db);
      }

      LogUtil.v(
          'RxNetDataBase: Cleared ${keysToDelete.length} records with prefix "$prefix"');
      return keysToDelete.length;
    } catch (error, stacktrace) {
      LogUtil.v('RxNetDataBase: clearByPrefix error: $error\n$stacktrace');
      return 0;
    }
  }

  /// 按正则模式清理缓存
  Future<int> clearByPattern(RegExp pattern) async {
    final db = await _resolveDatabase();
    if (db == null) {
      return 0;
    }

    try {
      final records = await _store.find(db);
      final keysToDelete = records
          .where((record) => pattern.hasMatch(record.key))
          .map((record) => record.key)
          .toList();

      for (final key in keysToDelete) {
        await _store.record(key).delete(db);
      }

      LogUtil.v(
          'RxNetDataBase: Cleared ${keysToDelete.length} records matching pattern');
      return keysToDelete.length;
    } catch (error, stacktrace) {
      LogUtil.v('RxNetDataBase: clearByPattern error: $error\n$stacktrace');
      return 0;
    }
  }

  /// 获取缓存大小估算值（字节）
  Future<int> estimateSizeInBytes() async {
    final db = await _resolveDatabase();
    if (db == null) {
      return 0;
    }

    try {
      final records = await _store.find(db);
      int totalSize = 0;
      for (final record in records) {
        totalSize += record.key.length * 2;
        totalSize += record.value.toString().length * 2;
      }
      return totalSize;
    } catch (error, stacktrace) {
      LogUtil.v(
          'RxNetDataBase: estimateSizeInBytes error: $error\n$stacktrace');
      return 0;
    }
  }

  /// 写入缓存条目元数据（用于淘汰策略）
  Future<void> putMetadata(String key, Map<String, dynamic> metadata) async {
    final db = await _resolveDatabase();
    if (db == null) return;
    try {
      await _metadataStore.record(key).put(db, metadata);
    } catch (e, st) {
      LogUtil.v('RxNetDataBase: putMetadata error: $e\n$st');
    }
  }

  /// 读取缓存条目元数据
  Future<Map<String, dynamic>?> getMetadata(String key) async {
    final db = await _resolveDatabase();
    if (db == null) return null;
    try {
      final value = await _metadataStore.record(key).get(db);
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    } catch (e, st) {
      LogUtil.v('RxNetDataBase: getMetadata error: $e\n$st');
      return null;
    }
  }

  /// 读取所有缓存条目元数据
  Future<List<MapEntry<String, Map<String, dynamic>>>> getAllMetadata() async {
    final db = await _resolveDatabase();
    if (db == null) return [];
    try {
      final records = await _metadataStore.find(db);
      return records
          .map((r) => MapEntry(r.key, r.value as Map<String, dynamic>))
          .toList();
    } catch (e, st) {
      LogUtil.v('RxNetDataBase: getAllMetadata error: $e\n$st');
      return [];
    }
  }

  /// 删除缓存条目元数据
  Future<void> deleteMetadata(String key) async {
    final db = await _resolveDatabase();
    if (db == null) return;
    try {
      await _metadataStore.record(key).delete(db);
    } catch (e, st) {
      LogUtil.v('RxNetDataBase: deleteMetadata error: $e\n$st');
    }
  }

  /// 清空所有缓存条目元数据
  Future<void> cleanMetadata() async {
    final db = await _resolveDatabase();
    if (db == null) return;
    try {
      await _metadataStore.delete(db);
    } catch (e, st) {
      LogUtil.v('RxNetDataBase: cleanMetadata error: $e\n$st');
    }
  }

  /// 关闭当前实例的数据库连接
  Future<void> closeInstance() async {
    if (_db != null) {
      await _db!.close();
      _db = null;
      LogUtil.v('RxNetDataBase: Database closed');
    }

    _resetInitState();
  }

  // ==================== 私有方法 ====================

  Future<void> _doInitDatabase({
    required String databaseName,
    required String? cacheName,
    required String? databasePath,
  }) async {
    try {
      if (kIsWeb) {
        LogUtil.v('RxNetDataBase: Initializing for Web platform (IndexedDB)');
        final factory = databaseFactoryWeb;
        _db = await factory.openDatabase(databaseName);
      } else {
        String dbPath;

        if (databasePath != null) {
          dbPath = p.join(databasePath, databaseName);
        } else {
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
              final appDir = await getTemporaryDirectory();
              dbPath = p.join(appDir.path, cacheName, databaseName);
            } else {
              final appDir = await getApplicationDocumentsDirectory();
              dbPath = p.join(appDir.path, cacheName, databaseName);
            }
          } catch (e) {
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
    } catch (e, stackTrace) {
      LogUtil.v(
          'RxNetDataBase: Failed to initialize database: $e\n$stackTrace');
      _db = null;
      _resetInitState(keepListeners: true);
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

  void _resetInitState({bool keepListeners = false}) {
    isDatabaseReady = false;
    _initFuture = null;
  }
}
