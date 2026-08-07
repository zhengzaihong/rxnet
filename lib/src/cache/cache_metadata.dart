/// 缓存条目元数据
///
/// 记录每个缓存条目的访问信息，用于 LRU/LFU/FIFO 淘汰策略。
class CacheMetadata {
  /// 条目创建时间（毫秒时间戳）
  final int createdAt;

  /// 最后访问时间（毫秒时间戳），每次读取时更新
  int lastAccessedAt;

  /// 访问次数，每次读取时递增
  int accessCount;

  CacheMetadata({
    required this.createdAt,
    int? lastAccessedAt,
    int? accessCount,
  })  : lastAccessedAt = lastAccessedAt ?? createdAt,
        accessCount = accessCount ?? 0;

  /// 记录一次访问（更新 lastAccessedAt 和 accessCount）
  void recordAccess() {
    lastAccessedAt = DateTime.now().millisecondsSinceEpoch;
    accessCount++;
  }

  /// 序列化为 Map，用于存储到数据库
  Map<String, dynamic> toMap() => {
        'createdAt': createdAt,
        'lastAccessedAt': lastAccessedAt,
        'accessCount': accessCount,
      };

  /// 从 Map 反序列化
  factory CacheMetadata.fromMap(Map<String, dynamic> map) => CacheMetadata(
        createdAt: map['createdAt'] as int,
        lastAccessedAt: map['lastAccessedAt'] as int?,
        accessCount: map['accessCount'] as int?,
      );

  @override
  String toString() =>
      'CacheMetadata(createdAt: $createdAt, lastAccessedAt: $lastAccessedAt, accessCount: $accessCount)';
}
