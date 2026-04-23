import '../models/adapter_response.dart';

/// 适配器异常类型
enum AdapterExceptionType {
  /// 连接超时
  connectTimeout,
  
  /// 发送超时
  sendTimeout,
  
  /// 接收超时
  receiveTimeout,
  
  /// 响应错误（4xx, 5xx）
  response,
  
  /// 请求被取消
  cancel,
  
  /// 连接错误（网络不可用等）
  connectionError,
  
  /// 未知错误
  unknown,
}

/// 适配器异常基类
/// 
/// 统一不同网络库的异常类型
class AdapterException implements Exception {
  /// 错误消息
  final String message;
  
  /// 异常类型
  final AdapterExceptionType type;
  
  /// HTTP 状态码（如果有）
  final int? statusCode;
  
  /// 响应对象（如果有）
  final AdapterResponse? response;
  
  /// 原始错误对象
  final dynamic originalError;
  
  /// 堆栈跟踪
  final StackTrace? stackTrace;
  
  AdapterException({
    required this.message,
    required this.type,
    this.statusCode,
    this.response,
    this.originalError,
    this.stackTrace,
  });
  
  /// 创建连接超时异常
  factory AdapterException.connectTimeout({
    String? message,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return AdapterException(
      message: message ?? 'Connection timeout',
      type: AdapterExceptionType.connectTimeout,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }
  
  /// 创建发送超时异常
  factory AdapterException.sendTimeout({
    String? message,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return AdapterException(
      message: message ?? 'Send timeout',
      type: AdapterExceptionType.sendTimeout,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }
  
  /// 创建接收超时异常
  factory AdapterException.receiveTimeout({
    String? message,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return AdapterException(
      message: message ?? 'Receive timeout',
      type: AdapterExceptionType.receiveTimeout,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }
  
  /// 创建响应错误异常
  factory AdapterException.response({
    required int statusCode,
    String? message,
    AdapterResponse? response,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return AdapterException(
      message: message ?? 'Response error: $statusCode',
      type: AdapterExceptionType.response,
      statusCode: statusCode,
      response: response,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }
  
  /// 创建取消异常
  factory AdapterException.cancel({
    String? message,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return AdapterException(
      message: message ?? 'Request cancelled',
      type: AdapterExceptionType.cancel,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }
  
  /// 创建连接错误异常
  factory AdapterException.connectionError({
    String? message,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return AdapterException(
      message: message ?? 'Connection error',
      type: AdapterExceptionType.connectionError,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }
  
  /// 创建未知错误异常
  factory AdapterException.unknown({
    String? message,
    dynamic originalError,
    StackTrace? stackTrace,
  }) {
    return AdapterException(
      message: message ?? 'Unknown error',
      type: AdapterExceptionType.unknown,
      originalError: originalError,
      stackTrace: stackTrace,
    );
  }
  
  @override
  String toString() {
    final buffer = StringBuffer('AdapterException: $message');
    buffer.write(' (type: $type');
    if (statusCode != null) {
      buffer.write(', statusCode: $statusCode');
    }
    buffer.write(')');
    
    if (originalError != null) {
      buffer.write('\nOriginal error: $originalError');
    }
    
    if (stackTrace != null) {
      buffer.write('\nStack trace:\n$stackTrace');
    }
    
    return buffer.toString();
  }
}
