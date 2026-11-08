/// 可选接口：支持释放底层资源的网络适配器。
///
/// 自定义适配器实现该接口后，[RxNet.dispose] 会自动调用 [close]。
/// 不实现该接口的适配器保持兼容，不会被强制关闭。
abstract class ClosableNetworkAdapter {
  /// 释放底层客户端、连接池、回调等资源
  Future<void> close();
}