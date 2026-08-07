import 'dart:convert';
import 'package:rxnet_plus/rxnet_lib.dart';
import 'package:rxnet_plus/utils/net_utils.dart';
import 'package:rxnet_plus/utils/rx_net_database.dart';

/// author:郑再红
/// email:1096877329@qq.com
/// date:2026-08-06 16:45
/// describe:缓存辅助类

class RxNetCache {
  RxNetDataBase? _database;
  int _cacheInvalidationTime;

  /// 最大缓存条目数（0 表示不限制）
  int _maxCacheSize;

  /// 缓存淘汰策略
  CacheEvictionPolicy _evictionPolicy;

  RxNetCache({
    RxNetDataBase? database,
    int cacheInvalidationTime = 365 * 24 * 60 * 60 * 1000,
    int maxCacheSize = 0,
    CacheEvictionPolicy evictionPolicy = CacheEvictionPolicy.none,
  })  : _database = database,
        _cacheInvalidationTime = cacheInvalidationTime,
        _maxCacheSize = maxCacheSize,
        _evictionPolicy = evictionPolicy;

  void setDatabase(RxNetDataBase database) {
    _database = database;
  }

  void setCacheInvalidationTime(int time) {
    _cacheInvalidationTime = time;
  }

  void setMaxCacheSize(int size) {
    _maxCacheSize = size;
  }

  void setEvictionPolicy(CacheEvictionPolicy policy) {
    _evictionPolicy = policy;
  }

  /// 当前最大缓存条目数
  int get maxCacheSize => _maxCacheSize;

  /// 当前淘汰策略
  CacheEvictionPolicy get evictionPolicy => _evictionPolicy;

  Future<void> put(String key, dynamic value) async {
    await _database?.put(key, value);
    await _updateMetadataOnWrite(key);
    await _enforceEviction();
  }

  Future<T?> get<T>(String key) async {
    final result = await _database?.get<T>(key);
    if (result != null) {
      await _updateMetadataOnAccess(key);
    }
    return result;
  }

  Future<void> remove(String key) async {
    await _database?.delete(key);
    await _database?.deleteMetadata(key);
  }

  Future<void> saveNetworkCache({
    required String path,
    required Map<String, dynamic> params,
    required dynamic responseData,
    List<String>? ignoreKeys,
  }) async {
    final cacheKey =
        NetUtils.getCacheKeyFromPath(path, params, ignoreKeys ?? []);
    final map = <String, dynamic>{
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'data': responseData,
    };
    await _database?.put(cacheKey, jsonEncode(map));
    await _updateMetadataOnWrite(cacheKey);
    await _enforceEviction();
  }

  Future<dynamic> readNetworkCache({
    required String path,
    required Map<String, dynamic> params,
    List<String>? ignoreKeys,
    int? cacheInvalidationTime,
  }) async {
    final cacheKey =
        NetUtils.getCacheKeyFromPath(path, params, ignoreKeys ?? []);
    final cached = await _database?.get<String>(cacheKey);
    if (cached == null) {
      return null;
    }

    final cacheData = jsonDecode(cached);
    final timestamp = cacheData['timestamp'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;
    final ttl = cacheInvalidationTime ?? _cacheInvalidationTime;

    if (ttl > 0 && (now - timestamp) > ttl) {
      // 缓存已过期，删除该条目
      await remove(cacheKey);
      return null;
    }

    await _updateMetadataOnAccess(cacheKey);
    return cacheData['data'];
  }

  Future<void> clearAll() async {
    await _database?.clean();
    await _database?.cleanMetadata();
  }

  Future<void> clearByPrefix(String prefix) async {
    final keys = await _database?.getAllKeys() ?? [];
    for (final key in keys) {
      if (key.startsWith(prefix)) {
        await _database?.delete(key);
        await _database?.deleteMetadata(key);
      }
    }
  }

  Future<void> clearByPattern(String pattern) async {
    final regExp = RegExp(pattern);
    final keys = await _database?.getAllKeys() ?? [];
    for (final key in keys) {
      if (regExp.hasMatch(key)) {
        await _database?.delete(key);
        await _database?.deleteMetadata(key);
      }
    }
  }

  Future<int> getCacheSize() async {
    return await _database?.count() ?? 0;
  }

  Future<List<String>> getAllKeys() async {
    return await _database?.getAllKeys() ?? [];
  }

  Future<bool> exists(String key) async {
    return await _database?.exists(key) ?? false;
  }

  // ==================== 淘汰策略相关 ====================

  /// 写入时更新元数据
  Future<void> _updateMetadataOnWrite(String key) async {
    if (_evictionPolicy == CacheEvictionPolicy.none) return;
    final meta = CacheMetadata(
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _database?.putMetadata(key, meta.toMap());
  }

  /// 读取命中时更新元数据
  Future<void> _updateMetadataOnAccess(String key) async {
    if (_evictionPolicy == CacheEvictionPolicy.none) return;
    final raw = await _database?.getMetadata(key);
    final meta =
        raw != null ? CacheMetadata.fromMap(raw) : CacheMetadata(createdAt: 0);
    meta.recordAccess();
    await _database?.putMetadata(key, meta.toMap());
  }

  /// 检查并执行淘汰
  Future<void> _enforceEviction() async {
    if (_evictionPolicy == CacheEvictionPolicy.none) return;
    if (_maxCacheSize <= 0) return;

    final currentSize = await getCacheSize();
    if (currentSize <= _maxCacheSize) return;

    final keys = await getAllKeys();
    if (keys.isEmpty) return;

    // 加载所有元数据
    final allMeta = await _database?.getAllMetadata() ?? [];
    final metaMap = <String, CacheMetadata>{};
    for (final entry in allMeta) {
      metaMap[entry.key] = CacheMetadata.fromMap(entry.value);
    }

    // 根据策略排序，选出需要淘汰的 key
    final keysToRemove = _selectKeysToEvict(keys, metaMap,
        currentSize - _maxCacheSize);

    for (final key in keysToRemove) {
      await _database?.delete(key);
      await _database?.deleteMetadata(key);
    }
  }

  /// 根据淘汰策略选择需要淘汰的 key
  List<String> _selectKeysToEvict(
    List<String> allKeys,
    Map<String, CacheMetadata> metaMap,
    int count,
  ) {
    final candidates = <String>[];
    // 排除无元数据的 key（保守策略：不淘汰）
    for (final key in allKeys) {
      if (metaMap.containsKey(key)) {
        candidates.add(key);
      }
    }

    if (candidates.isEmpty) return [];
    final toRemove = candidates.length < count ? candidates.length : count;

    switch (_evictionPolicy) {
      case CacheEvictionPolicy.lru:
        // 按 lastAccessedAt 升序排列，最早访问的排前面
        candidates.sort((a, b) {
          final ma = metaMap[a]!;
          final mb = metaMap[b]!;
          return ma.lastAccessedAt.compareTo(mb.lastAccessedAt);
        });
        return candidates.sublist(0, toRemove);

      case CacheEvictionPolicy.lfu:
        // 按 accessCount 升序排列，最少访问的排前面
        // 相同时按 lastAccessedAt 升序（退化为 FIFO）
        candidates.sort((a, b) {
          final ma = metaMap[a]!;
          final mb = metaMap[b]!;
          final cmp = ma.accessCount.compareTo(mb.accessCount);
          if (cmp != 0) return cmp;
          return ma.lastAccessedAt.compareTo(mb.lastAccessedAt);
        });
        return candidates.sublist(0, toRemove);

      case CacheEvictionPolicy.fifo:
        // 按 createdAt 升序排列，最早创建的排前面
        candidates.sort((a, b) {
          final ma = metaMap[a]!;
          final mb = metaMap[b]!;
          return ma.createdAt.compareTo(mb.createdAt);
        });
        return candidates.sublist(0, toRemove);

      case CacheEvictionPolicy.none:
        return [];
    }
  }
}
