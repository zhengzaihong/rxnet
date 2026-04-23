import 'adapter_request.dart';


/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2026-04-21 16:04
/// describe: 统一的响应包装模型

/// 屏蔽不同网络库的响应差异，提供统一的响应接口
class AdapterResponse<T> {
  /// 状态码
  final int statusCode;
  
  /// 状态消息
  final String? statusMessage;
  
  /// 响应数据
  final T? data;
  
  /// 响应头
  final Map<String, List<String>> headers;
  
  /// 请求信息
  final AdapterRequest request;
  
  /// 是否重定向
  final bool isRedirect;
  
  /// 重定向 URL
  final String? redirectUrl;
  
  /// 额外信息
  final Map<String, dynamic> extra;
  
  const AdapterResponse({
    required this.statusCode,
    this.statusMessage,
    this.data,
    required this.headers,
    required this.request,
    this.isRedirect = false,
    this.redirectUrl,
    this.extra = const {},
  });
  
  /// 是否成功 (2xx)
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  
  /// 获取响应头值
  /// 
  /// [name] 响应头名称（不区分大小写）
  /// Returns: 第一个匹配的响应头值，如果不存在则返回 null
  String? getHeader(String name) {
    final values = headers[name.toLowerCase()];
    return values?.isNotEmpty == true ? values!.first : null;
  }
  
  /// 获取所有响应头值
  /// 
  /// [name] 响应头名称（不区分大小写）
  /// Returns: 所有匹配的响应头值列表，如果不存在则返回 null
  List<String>? getHeaders(String name) {
    return headers[name.toLowerCase()];
  }
  
  /// 复制并修改
  AdapterResponse<T> copyWith({
    int? statusCode,
    String? statusMessage,
    T? data,
    Map<String, List<String>>? headers,
    AdapterRequest? request,
    bool? isRedirect,
    String? redirectUrl,
    Map<String, dynamic>? extra,
  }) {
    return AdapterResponse<T>(
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      data: data ?? this.data,
      headers: headers ?? this.headers,
      request: request ?? this.request,
      isRedirect: isRedirect ?? this.isRedirect,
      redirectUrl: redirectUrl ?? this.redirectUrl,
      extra: extra ?? this.extra,
    );
  }
  
  @override
  String toString() {
    return 'AdapterResponse(statusCode: $statusCode, '
        'statusMessage: $statusMessage, '
        'isSuccess: $isSuccess, '
        'dataType: ${data.runtimeType})';
  }
}
