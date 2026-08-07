/// 缓存淘汰策略枚举
///
/// 用于配置缓存达到最大容量时的淘汰行为。
///
/// ```dart
/// final config = RxNetConfig(
///   baseUrl: "https://api.example.com",
///   cacheMaxSize: 500,
///   cacheEvictionPolicy: CacheEvictionPolicy.lru,
/// );
/// await RxNet.init(config: config);
/// ```
enum CacheEvictionPolicy {
  /// 不淘汰（默认），缓存条目不受数量限制
  none,

  /// 最近最少使用（Least Recently Used）
  /// 淘汰最后访问时间最久远的条目
  lru,

  /// 最不经常使用（Least Frequently Used）
  /// 淘汰访问次数最少的条目；次数相同时退化为 FIFO
  lfu,

  /// 先进先出（First In First Out）
  /// 淘汰最早创建的条目
  fifo,
}
