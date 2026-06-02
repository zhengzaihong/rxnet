import 'dart:async';
import 'zip_request.dart';

/// author:ZhengZaiHong
/// email:1096877329@qq.com
/// date:2026-06-02 11:27
/// describe: 跟踪请求执行的内部状态
/// Internal state for tracking request execution

class RequestState<T> {
  final ZipRequest<T> request;
  final Completer<T> completer;
  final int index;
  
  RequestState({
    required this.request,
    required this.completer,
    required this.index,
  });
  
  bool get isCompleted => completer.isCompleted;
}

/// Factory function to create a typed RequestState
/// This helps maintain type safety during request state initialization
RequestState<T> createRequestState<T>(ZipRequest<T> request, int index) {
  return RequestState<T>(
    request: request,
    completer: Completer<T>(),
    index: index,
  );
}
