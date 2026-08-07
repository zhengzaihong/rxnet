import 'dart:math';


/// author:郑再红
/// email:1096877329@qq.com
/// date:2026-08-05 15:47
/// describe: 重试策略枚举
///
enum RetryStrategy {
  /// 固定间隔重试（默认行为）
  fixed,

  /// 指数退避重试
  exponentialBackoff,

  /// 指数退避 + 随机抖动重试
  exponentialBackoffWithJitter,
}

/// 重试策略配置类
///
/// 用于配置请求重试行为，支持固定间隔、指数退避、指数退避+抖动三种策略。
///
/// ## 使用示例
///
/// ```dart
/// // 固定间隔重试（向后兼容）
/// RxNet.get()
///   .setPath("/api/data")
///   .setRetryCount(3, interval: Duration(seconds: 2))
///   .request();
///
/// // 指数退避重试
/// RxNet.get()
///   .setPath("/api/data")
///   .setRetryPolicy(RetryPolicy(
///     maxRetries: 3,
///     strategy: RetryStrategy.exponentialBackoff,
///     baseInterval: Duration(seconds: 1),
///   ))
///   .request();
///
/// // 指数退避 + 抖动重试
/// RxNet.get()
///   .setPath("/api/data")
///   .setRetryPolicy(RetryPolicy(
///     maxRetries: 5,
///     strategy: RetryStrategy.exponentialBackoffWithJitter,
///     baseInterval: Duration(seconds: 1),
///     maxInterval: Duration(seconds: 30),
///   ))
///   .request();
/// ```
class RetryPolicy {
  /// 最大重试次数
  final int maxRetries;

  /// 重试策略
  final RetryStrategy strategy;

  /// 基础间隔时间（固定间隔使用，指数退避的基础值）
  final Duration baseInterval;

  /// 最大间隔时间（仅指数退避策略使用，防止间隔过长）
  final Duration? maxInterval;

  /// 退避倍数（默认 2.0）
  final double backoffMultiplier;

  const RetryPolicy({
    this.maxRetries = 3,
    this.strategy = RetryStrategy.fixed,
    this.baseInterval = const Duration(seconds: 1),
    this.maxInterval,
    this.backoffMultiplier = 2.0,
  });

  /// 计算第 [attempt] 次重试的延迟时间（从 0 开始计数）
  Duration getDelay(int attempt) {
    switch (strategy) {
      case RetryStrategy.fixed:
        return baseInterval;

      case RetryStrategy.exponentialBackoff:
        final delay = baseInterval * pow(backoffMultiplier, attempt).toInt();
        if (maxInterval != null && delay > maxInterval!) {
          return maxInterval!;
        }
        return delay;

      case RetryStrategy.exponentialBackoffWithJitter:
        final exponentialDelay =
            baseInterval * pow(backoffMultiplier, attempt).toInt();
        final jitter = Random().nextDouble() * exponentialDelay.inMilliseconds;
        final delay =
            Duration(milliseconds: (exponentialDelay.inMilliseconds + jitter) ~/ 2);
        if (maxInterval != null && delay > maxInterval!) {
          return maxInterval!;
        }
        return delay;
    }
  }

  /// 固定间隔重试的工厂方法（兼容旧 API 行为）
  factory RetryPolicy.fixed({
    int maxRetries = 3,
    Duration interval = const Duration(seconds: 1),
  }) {
    return RetryPolicy(
      maxRetries: maxRetries,
      strategy: RetryStrategy.fixed,
      baseInterval: interval,
    );
  }

  /// 指数退避重试的工厂方法
  factory RetryPolicy.exponentialBackoff({
    int maxRetries = 3,
    Duration baseInterval = const Duration(seconds: 1),
    Duration? maxInterval,
    double backoffMultiplier = 2.0,
  }) {
    return RetryPolicy(
      maxRetries: maxRetries,
      strategy: RetryStrategy.exponentialBackoff,
      baseInterval: baseInterval,
      maxInterval: maxInterval,
      backoffMultiplier: backoffMultiplier,
    );
  }

  /// 指数退避 + 抖动重试的工厂方法
  factory RetryPolicy.exponentialBackoffWithJitter({
    int maxRetries = 5,
    Duration baseInterval = const Duration(seconds: 1),
    Duration? maxInterval,
    double backoffMultiplier = 2.0,
  }) {
    return RetryPolicy(
      maxRetries: maxRetries,
      strategy: RetryStrategy.exponentialBackoffWithJitter,
      baseInterval: baseInterval,
      maxInterval: maxInterval,
      backoffMultiplier: backoffMultiplier,
    );
  }

  @override
  String toString() {
    return 'RetryPolicy(maxRetries: $maxRetries, strategy: $strategy, '
        'baseInterval: $baseInterval)';
  }
}
