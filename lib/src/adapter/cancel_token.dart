
/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2026-04-23 11:17
/// describe: 用于取消网络请求的令牌

class CancelToken {
  bool _isCancelled = false;
  String? _cancelReason;
  final List<void Function(String?)> _callbacks = [];

  /// 是否已取消
  bool get isCancelled => _isCancelled;

  /// 取消原因
  String? get cancelReason => _cancelReason;

  /// 取消请求
  /// 
  /// [reason] 取消原因（可选）
  void cancel([String? reason]) {
    if (_isCancelled) {
      return; // 已经取消，不重复执行
    }

    _isCancelled = true;
    _cancelReason = reason ?? 'Request cancelled';

    // 通知所有回调
    for (final callback in _callbacks) {
      try {
        callback(_cancelReason);
      } catch (e) {
        // 忽略回调中的错误
      }
    }

    // 清空回调列表
    _callbacks.clear();
  }

  /// 添加取消回调
  /// 
  /// 当请求被取消时，会调用此回调
  /// 如果已经取消，立即调用回调
  void whenCancel(void Function(String?) callback) {
    if (_isCancelled) {
      callback(_cancelReason);
    } else {
      _callbacks.add(callback);
    }
  }

  /// 移除取消回调
  void removeCallback(void Function(String?) callback) {
    _callbacks.remove(callback);
  }

  /// 清除所有回调
  void clearCallbacks() {
    _callbacks.clear();
  }

  /// 重置取消状态（用于测试）
  void reset() {
    _isCancelled = false;
    _cancelReason = null;
    _callbacks.clear();
  }

  @override
  String toString() {
    return 'CancelToken(isCancelled: $_isCancelled, reason: $_cancelReason)';
  }
}
