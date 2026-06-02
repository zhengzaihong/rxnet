/// author:郑再红
/// email:1096877329@qq.com
/// date:2026-06-02 11:28
/// describe:带有上下文的请求错误包装器
/// Wrapper for request errors with context

class ZipRequestError {
  final int index;
  final String? tag;
  final dynamic error;
  final StackTrace? stackTrace;
  
  ZipRequestError({
    required this.index,
    this.tag,
    required this.error,
    this.stackTrace,
  });
  
  @override
  String toString() {
    final tagInfo = tag != null ? ' (tag: $tag)' : '';
    return 'ZipRequestError at index $index$tagInfo: $error';
  }
}
