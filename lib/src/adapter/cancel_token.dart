
/// Token for cancelling network requests.
/// 
/// 用于取消网络请求的令牌。
/// 
/// This class provides a mechanism to cancel ongoing network requests.
/// When a request is cancelled, all registered callbacks will be notified.
/// 
/// 此类提供了取消正在进行的网络请求的机制。
/// 当请求被取消时，所有注册的回调都会被通知。
/// 
/// Example / 示例:
/// ```dart
/// final cancelToken = CancelToken();
/// 
/// // Start a request with cancel token
/// // 使用取消令牌启动请求
/// RxNet.get()
///   .setPath("/data")
///   .setCancelToken(cancelToken)
///   .request();
/// 
/// // Cancel the request
/// // 取消请求
/// cancelToken.cancel("User cancelled");
/// ```
/// 
/// See also / 另见:
/// - [AdapterRequest.cancelToken] for using cancel tokens in requests
/// - [NetworkAdapter.cancel] for adapter-level cancellation
/// 
/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2026-04-23 11:17
class CancelToken {
  bool _isCancelled = false;
  String? _cancelReason;
  final List<void Function(String?)> _callbacks = [];

  /// Whether the request has been cancelled.
  /// 
  /// 请求是否已被取消。
  bool get isCancelled => _isCancelled;

  /// The reason for cancellation.
  /// 
  /// 取消的原因。
  String? get cancelReason => _cancelReason;

  /// Cancels the request.
  /// 
  /// 取消请求。
  /// 
  /// Parameters / 参数:
  /// - [reason]: Optional reason for cancellation / 取消原因（可选）
  /// 
  /// If the request is already cancelled, this method does nothing.
  /// All registered callbacks will be notified when the request is cancelled.
  /// 
  /// 如果请求已经被取消，此方法不执行任何操作。
  /// 当请求被取消时，所有注册的回调都会被通知。
  /// 
  /// Example / 示例:
  /// ```dart
  /// cancelToken.cancel("User cancelled the operation");
  /// ```
  void cancel([String? reason]) {
    if (_isCancelled) {
      return; // Already cancelled / 已经取消，不重复执行
    }

    _isCancelled = true;
    _cancelReason = reason ?? 'Request cancelled';

    // Notify all callbacks / 通知所有回调
    for (final callback in _callbacks) {
      try {
        callback(_cancelReason);
      } catch (e) {
        // Ignore errors in callbacks / 忽略回调中的错误
      }
    }

    // Clear callback list / 清空回调列表
    _callbacks.clear();
  }

  /// Adds a cancellation callback.
  /// 
  /// 添加取消回调。
  /// 
  /// The callback will be invoked when the request is cancelled.
  /// If the request is already cancelled, the callback is invoked immediately.
  /// 
  /// 当请求被取消时，会调用此回调。
  /// 如果已经取消，立即调用回调。
  /// 
  /// Parameters / 参数:
  /// - [callback]: Function to call when cancelled / 取消时调用的函数
  /// 
  /// Example / 示例:
  /// ```dart
  /// cancelToken.whenCancel((reason) {
  ///   print('Request cancelled: $reason');
  /// });
  /// ```
  void whenCancel(void Function(String?) callback) {
    if (_isCancelled) {
      callback(_cancelReason);
    } else {
      _callbacks.add(callback);
    }
  }

  /// Removes a cancellation callback.
  /// 
  /// 移除取消回调。
  /// 
  /// Parameters / 参数:
  /// - [callback]: The callback to remove / 要移除的回调
  void removeCallback(void Function(String?) callback) {
    _callbacks.remove(callback);
  }

  /// Clears all callbacks.
  /// 
  /// 清除所有回调。
  void clearCallbacks() {
    _callbacks.clear();
  }

  /// Resets the cancellation state (for testing).
  /// 
  /// 重置取消状态（用于测试）。
  /// 
  /// This method is primarily intended for testing purposes.
  /// It resets the token to its initial state.
  /// 
  /// 此方法主要用于测试目的。
  /// 它将令牌重置为初始状态。
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
