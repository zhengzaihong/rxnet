import 'dart:convert';
import '../../src/adapter/interceptor/adapter_interceptor.dart';
import '../../src/adapter/models/adapter_request.dart';
import '../../src/adapter/models/adapter_response.dart';
import '../../src/adapter/exceptions/adapter_exception.dart';
import '../../utils/log_util.dart';

///
/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2026-04-20
/// describe: 适配器版本的日志拦截器
/// 实现 AdapterInterceptor 接口，与具体网络库解耦
///

void log2Console(Object object) {
  LogUtil.v(object);
}

/// 适配器版本的日志拦截器
/// 
/// 与 RxNetLogInterceptor 功能相同，但实现了 AdapterInterceptor 接口
/// 可以与任何适配器一起使用
class RxNetLogAdapterInterceptor implements AdapterInterceptor {
  RxNetLogAdapterInterceptor({
    this.request = true,
    this.requestHeader = true,
    this.requestBody = true,
    this.responseHeader = true,
    this.responseBody = true,
    this.error = true,
    this.logPrint = log2Console,
  });

  /// 是否打印请求参数
  final bool request;

  /// 是否打印请求头
  final bool requestHeader;

  /// 是否打印请求参数 post
  final bool requestBody;

  /// 是否打印响应数据
  final bool responseBody;

  /// 是否打印响应头
  final bool responseHeader;

  /// 是否打印错误信息
  final bool error;

  /// 日志打印函数
  final void Function(Object object) logPrint;

  final Map<String, DateTime> _requestMaps = {};

  @override
  Future<void> onRequest(
    AdapterRequest request,
    RequestInterceptorHandler handler,
  ) async {
    logPrint('***************** Request Start *****************');
    
    final uri = request.buildFullUrl();
    _requestMaps[uri] = DateTime.now();
    
    printKV('Request uri start', uri);
    
    if (this.request) {
      printKV('method', request.method.toString());
      printKV('responseType', request.responseType.toString());
      printKV('connectTimeout', request.connectTimeout?.inMicroseconds ?? "");
      printKV('receiveTimeout', request.receiveTimeout?.inMicroseconds ?? "");
      printKV('sendTimeout', request.sendTimeout?.inMicroseconds ?? "");
      printKV('extra', request.extra);
    }
    
    if (requestHeader) {
      logPrint('Request Headers:');
      printAll(jsonEncode(request.headers));
    }
    
    if (requestBody) {
      if (request.rawBody != null) {
        logPrint("rawBody:");
        _printBody(request.rawBody);
      }
      if (request.bodyParams.isNotEmpty) {
        logPrint("bodyParams:");
        _printBody(request.bodyParams);
      }
    }
    
    if (request.queryParams.isNotEmpty) {
      logPrint("queryParams:");
      printAll(jsonEncode(request.queryParams));
    }
    printKV('Request uri end', uri);
    logPrint('***************** Request End *****************');
    
    // 继续请求
    handler.next(request);
  }

  @override
  Future<void> onResponse(
    AdapterResponse response,
    ResponseInterceptorHandler handler,
  ) async {
    logPrint("***************** Response Start *****************");
    
    _printResponse(response);
    
    // 继续响应
    handler.next(response);
  }

  @override
  Future<void> onError(
    AdapterException error,
    ErrorInterceptorHandler handler,
  ) async {
    if (this.error) {
      logPrint('***************** AdapterException Info Start *****************:');
      logPrint("type: ${error.type}");
      logPrint("message: ${error.message}");
      logPrint("statusCode: ${error.statusCode}");
      
      if (error.response != null) {
        _printResponse(error.response!);
      }
      
      if (error.originalError != null) {
        logPrint("originalError: ${error.originalError}");
      }
      
      logPrint('***************** AdapterException Info End *****************:');
    }
    
    // 继续错误处理
    handler.next(error);
  }

  void _printResponse(AdapterResponse response) {
    final uri = response.request.buildFullUrl();
    logPrint('Response url start: $uri');
    if (responseHeader) {
      printKV('statusCode', response.statusCode);
      printKV('statusMessage', response.statusMessage ?? "");
      
      if (response.isRedirect) {
        printKV('redirect', response.redirectUrl ?? "");
      }
      
      if (response.headers.isNotEmpty) {
        logPrint("Response Headers:");
        response.headers.forEach((key, values) {
          printKV(" $key", values.join(","));
        });
      }
    }
    
    if (responseBody) {
      logPrint("Response Data:");
      try {
        printAll(jsonEncode(response.data));
      } catch (e) {
        printAll(response.data.toString());
      }
    }


    DateTime oldTime = _requestMaps[uri] ?? DateTime.now();
    DateTime responseTime = DateTime.now();
    Duration duration = responseTime.difference(oldTime);
    
    logPrint('useTime:${duration.inMinutes}分 | ${duration.inSeconds}秒 | ${duration.inMilliseconds}毫秒');
    logPrint('Response url end: $uri');
    
    logPrint("***************** Response End *****************");
  }

  void printKV(String key, Object v) {
    logPrint('$key: $v');
  }

  void printAll(String msg) {
    msg.toString().split("\n").forEach(logPrint);
  }

  /// 安全地打印请求体，处理文件类型
  void _printBody(dynamic body) {
    try {
      if (body == null) {
        printAll("null");
        return;
      }

      // 如果是 Map，检查是否包含文件类型
      if (body is Map) {
        final safeBody = <String, dynamic>{};
        body.forEach((key, value) {
          if (_isFileType(value)) {
            safeBody[key] = "[File: ${_getFileDescription(value)}]";
          } else if (value is List && value.any(_isFileType)) {
            safeBody[key] = "[Files: ${value.length} items]";
          } else {
            safeBody[key] = value;
          }
        });
        printAll(jsonEncode(safeBody));
      } else if (_isFileType(body)) {
        printAll("[File: ${_getFileDescription(body)}]");
      } else {
        // 尝试 JSON 编码
        printAll(jsonEncode(body));
      }
    } catch (e) {
      // 如果 JSON 编码失败，使用 toString
      printAll(body.toString());
    }
  }

  /// 检查是否是文件类型
  bool _isFileType(dynamic value) {
    // 检查常见的文件类型
    final typeName = value.runtimeType.toString();
    return typeName.contains('MultipartFile') ||
           typeName.contains('File') ||
           typeName.contains('UploadFileInfo');
  }

  /// 获取文件描述信息
  String _getFileDescription(dynamic file) {
    try {
      // 尝试获取文件名或路径
      if (file is Map && file.containsKey('filename')) {
        return file['filename'].toString();
      }
      return file.runtimeType.toString();
    } catch (e) {
      return 'unknown';
    }
  }
}
