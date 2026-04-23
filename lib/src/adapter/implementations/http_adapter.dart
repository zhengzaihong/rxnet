import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../net/type/http_method.dart';
import '../network_adapter.dart';
import '../models/adapter_request.dart';
import '../models/adapter_response.dart';
import '../interceptor/adapter_interceptor.dart';
import '../exceptions/adapter_exception.dart';
import '../cancel_token.dart' as adapter_cancel;


/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2026-04-23 11:28
/// describe: 基于 http 包实现 NetworkAdapter 接口，提供轻量级的网络请求功能

class HttpAdapter implements NetworkAdapter {
  final http.Client _client;
  final List<AdapterInterceptor> _interceptors = [];
  final Map<adapter_cancel.CancelToken, List<Completer>> _pendingRequests = {};
  
  /// 创建 HttpAdapter
  /// 
  /// [client] 可选的 http.Client 实例，如果不提供则创建默认实例
  HttpAdapter({http.Client? client}) : _client = client ?? http.Client();
  
  /// 获取内部 http.Client 实例
  http.Client get client => _client;
  
  @override
  String get name => 'HttpAdapter';
  
  @override
  String get version => '1.0.0';
  
  @override
  Future<AdapterResponse> request(AdapterRequest request) async {
    // 创建 Completer 用于取消
    final completer = Completer<AdapterResponse>();
    
    // 如果有 cancelToken，注册取消回调
    if (request.cancelToken != null) {
      _registerCancelToken(request.cancelToken!, completer);
      
      // 如果已经取消，立即抛出异常
      if (request.cancelToken!.isCancelled) {
        throw AdapterException(
          type: AdapterExceptionType.cancel,
          message: request.cancelToken!.cancelReason ?? 'Request cancelled',
        );
      }
    }
    
    try {
      // 执行请求拦截器
      var modifiedRequest = request;
      for (final interceptor in _interceptors) {
        final handler = RequestInterceptorHandler();
         interceptor.onRequest(modifiedRequest, handler);
        
        if (handler.resolvedResponse != null) {
          _unregisterCancelToken(request.cancelToken, completer);
          return handler.resolvedResponse!;
        }
        if (handler.rejectedError != null) {
          _unregisterCancelToken(request.cancelToken, completer);
          throw handler.rejectedError!;
        }
        if (handler.modifiedRequest != null) {
          modifiedRequest = handler.modifiedRequest!;
        }
      }
      
      // 构建 URI
      final uri = _buildUri(modifiedRequest);
      
      // 构建头部
      final headers = _buildHeaders(modifiedRequest);
      
      // 构建请求体
      final body = _buildBody(modifiedRequest);
      
      // 执行 HTTP 请求（使用 Future.any 支持取消）
      http.Response httpResponse;
      final requestFuture = _executeRequest(modifiedRequest.method, uri, headers, body);
      
      if (request.cancelToken != null) {
        httpResponse = await Future.any([
          requestFuture,
          completer.future.then((_) => throw AdapterException(
            type: AdapterExceptionType.cancel,
            message: request.cancelToken!.cancelReason ?? 'Request cancelled',
          )),
        ]);
      } else {
        httpResponse = await requestFuture;
      }
      
      // 转换响应
      var response = _convertFromHttpResponse(httpResponse, modifiedRequest);
      
      // 检查是否是错误响应
      if (!response.isSuccess) {
        final exception = AdapterException(
          message: 'HTTP ${response.statusCode}: ${response.statusMessage ?? ""}',
          type: AdapterExceptionType.response,
          statusCode: response.statusCode,
          response: response,
        );
        
        // 执行错误拦截器
        var modifiedException = exception;
        for (final interceptor in _interceptors) {
          final handler = ErrorInterceptorHandler();
           interceptor.onError(modifiedException, handler);
          
          if (handler.resolvedResponse != null) {
            _unregisterCancelToken(request.cancelToken, completer);
            return handler.resolvedResponse!;
          }
          if (handler.modifiedError != null) {
            modifiedException = handler.modifiedError!;
          }
        }
        
        _unregisterCancelToken(request.cancelToken, completer);
        throw modifiedException;
      }
      
      // 执行响应拦截器
      for (final interceptor in _interceptors) {
        final handler = ResponseInterceptorHandler();
         interceptor.onResponse(response, handler);
        
        if (handler.rejectedError != null) {
          _unregisterCancelToken(request.cancelToken, completer);
          throw handler.rejectedError!;
        }
        if (handler.modifiedResponse != null) {
          response = handler.modifiedResponse!;
        }
      }
      
      _unregisterCancelToken(request.cancelToken, completer);
      return response;
    } on AdapterException {
      _unregisterCancelToken(request.cancelToken, completer);
      rethrow;
    } catch (e, stackTrace) {
      _unregisterCancelToken(request.cancelToken, completer);
      var exception = _convertException(e, stackTrace);
      
      // 执行错误拦截器
      for (final interceptor in _interceptors) {
        final handler = ErrorInterceptorHandler();
         interceptor.onError(exception, handler);
        
        if (handler.resolvedResponse != null) {
          return handler.resolvedResponse!;
        }
        if (handler.modifiedError != null) {
          exception = handler.modifiedError!;
        }
      }
      
      throw exception;
    }
  }
  
  /// 执行 HTTP 请求
  Future<http.Response> _executeRequest(
    HttpMethod method,
    Uri uri,
    Map<String, String> headers,
    dynamic body,
  ) async {
    switch (method) {
      case HttpMethod.GET:
        return await _client.get(uri, headers: headers);
      case HttpMethod.POST:
        return await _client.post(uri, headers: headers, body: body);
      case HttpMethod.PUT:
        return await _client.put(uri, headers: headers, body: body);
      case HttpMethod.DELETE:
        return await _client.delete(uri, headers: headers, body: body);
      case HttpMethod.PATCH:
        return await _client.patch(uri, headers: headers, body: body);
      case HttpMethod.HEAD:
        return await _client.head(uri, headers: headers);
      case HttpMethod.OPTIONS:
        // http package doesn't have a built-in options method
        // We'll use a custom request
        final request = http.Request('OPTIONS', uri);
        request.headers.addAll(headers);
        final streamedResponse = await _client.send(request);
        return await http.Response.fromStream(streamedResponse);
      default:
        throw AdapterException(
          message: 'Unsupported HTTP method: $method',
          type: AdapterExceptionType.unknown,
        );
    }
  }
  
  /// 注册取消令牌
  void _registerCancelToken(adapter_cancel.CancelToken token, Completer completer) {
    if (!_pendingRequests.containsKey(token)) {
      _pendingRequests[token] = [];
    }
    _pendingRequests[token]!.add(completer);
    
    // 添加取消回调
    token.whenCancel((reason) {
      final completers = _pendingRequests[token];
      if (completers != null) {
        for (final c in completers) {
          if (!c.isCompleted) {
            c.completeError(AdapterException(
              type: AdapterExceptionType.cancel,
              message: reason ?? 'Request cancelled',
            ));
          }
        }
        _pendingRequests.remove(token);
      }
    });
  }
  
  /// 注销取消令牌
  void _unregisterCancelToken(adapter_cancel.CancelToken? token, Completer completer) {
    if (token != null && _pendingRequests.containsKey(token)) {
      _pendingRequests[token]!.remove(completer);
      if (_pendingRequests[token]!.isEmpty) {
        _pendingRequests.remove(token);
      }
    }
  }
  
  /// 构建 URI
  Uri _buildUri(AdapterRequest request) {
    final fullUrl = request.buildFullUrl();
    final uri = Uri.parse(fullUrl);
    
    if (request.queryParams.isEmpty) {
      return uri;
    }
    
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...request.queryParams.map((key, value) => MapEntry(key, value.toString())),
    });
  }
  
  /// 构建头部
  Map<String, String> _buildHeaders(AdapterRequest request) {
    final headers = <String, String>{};
    
    for (final entry in request.headers.entries) {
      if (entry.value is List) {
        headers[entry.key] = (entry.value as List).join(', ');
      } else {
        headers[entry.key] = entry.value.toString();
      }
    }
    
    // 如果有 contentType，添加到头部
    if (request.contentType != null && !headers.containsKey('content-type')) {
      headers['content-type'] = request.contentType!;
    }
    
    return headers;
  }
  
  /// 构建请求体
  dynamic _buildBody(AdapterRequest request) {
    // 如果有原始 body，直接使用
    if (request.rawBody != null) {
      return request.rawBody;
    }
    
    // 如果没有 body 参数，返回 null
    if (request.bodyParams.isEmpty) {
      return null;
    }
    
    // 根据 contentType 处理
    final contentType = request.contentType?.toLowerCase() ?? '';
    
    if (contentType.contains('application/json')) {
      return jsonEncode(request.bodyParams);
    } else if (contentType.contains('application/x-www-form-urlencoded')) {
      return request.bodyParams.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
    } else {
      // 默认使用 JSON
      return jsonEncode(request.bodyParams);
    }
  }
  
  /// 转换 http.Response 到 AdapterResponse
  AdapterResponse _convertFromHttpResponse(
    http.Response httpResponse,
    AdapterRequest request,
  ) {
    // 解析响应数据
    dynamic data;
    try {
      final contentType = httpResponse.headers['content-type'] ?? '';
      if (contentType.contains('application/json')) {
        data = jsonDecode(httpResponse.body);
      } else {
        data = httpResponse.body;
      }
    } catch (e) {
      data = httpResponse.body;
    }
    
    // 转换头部
    final headers = <String, List<String>>{};
    httpResponse.headers.forEach((key, value) {
      headers[key] = [value];
    });
    
    return AdapterResponse(
      statusCode: httpResponse.statusCode,
      statusMessage: httpResponse.reasonPhrase,
      data: data,
      headers: headers,
      request: request,
    );
  }
  
  /// 转换异常
  AdapterException _convertException(Object error, StackTrace stackTrace) {
    if (error is SocketException) {
      return AdapterException(
        message: 'Connection error: ${error.message}',
        type: AdapterExceptionType.connectionError,
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (error is TimeoutException) {
      return AdapterException(
        message: 'Request timeout: ${error.message ?? ""}',
        type: AdapterExceptionType.receiveTimeout,
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (error is HttpException) {
      return AdapterException(
        message: 'HTTP error: ${error.message}',
        type: AdapterExceptionType.response,
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (error.toString().contains('SocketException') || 
               error.toString().contains('Failed host lookup') ||
               error.toString().contains('Connection refused')) {
      // 处理包装的 SocketException
      return AdapterException(
        message: 'Connection error: ${error.toString()}',
        type: AdapterExceptionType.connectionError,
        originalError: error,
        stackTrace: stackTrace,
      );
    } else {
      return AdapterException(
        message: 'Unknown error: ${error.toString()}',
        type: AdapterExceptionType.unknown,
        originalError: error,
        stackTrace: stackTrace,
      );
    }
  }
  
  @override
  Future<AdapterResponse> download(
    AdapterRequest request,
    String savePath, {
    ProgressCallback? onProgress,
  }) async {
    try {
      // 构建 URI
      final uri = _buildUri(request);
      
      // 构建头部
      final headers = _buildHeaders(request);
      
      // 创建请求
      final httpRequest = http.Request('GET', uri);
      httpRequest.headers.addAll(headers);
      
      // 发送请求
      final streamedResponse = await _client.send(httpRequest);
      
      // 检查状态码
      if (streamedResponse.statusCode >= 400) {
        throw AdapterException(
          message: 'HTTP ${streamedResponse.statusCode}',
          type: AdapterExceptionType.response,
          statusCode: streamedResponse.statusCode,
        );
      }
      
      // 下载文件
      final file = File(savePath);
      final sink = file.openWrite();
      
      var received = 0;
      final total = streamedResponse.contentLength ?? 0;
      
      await for (final chunk in streamedResponse.stream) {
        sink.add(chunk);
        received += chunk.length;
        
        if (onProgress != null && total > 0) {
          onProgress(received, total);
        }
      }
      
      await sink.close();
      
      // 转换头部
      final responseHeaders = <String, List<String>>{};
      streamedResponse.headers.forEach((key, value) {
        responseHeaders[key] = [value];
      });
      
      return AdapterResponse(
        statusCode: streamedResponse.statusCode,
        statusMessage: streamedResponse.reasonPhrase,
        data: savePath,
        headers: responseHeaders,
        request: request,
      );
    } catch (e, stackTrace) {
      if (e is AdapterException) {
        rethrow;
      }
      throw _convertException(e, stackTrace);
    }
  }
  
  @override
  Future<AdapterResponse> upload(
    AdapterRequest request, {
    ProgressCallback? onProgress,
  }) async {
    try {
      // 构建 URI
      final uri = _buildUri(request);
      
      // 创建 multipart 请求
      final multipartRequest = http.MultipartRequest(
        request.method.name.toUpperCase(),
        uri,
      );
      
      // 添加头部
      final headers = _buildHeaders(request);
      multipartRequest.headers.addAll(headers);
      
      // 添加字段和文件
      for (final entry in request.bodyParams.entries) {
        if (entry.value is File) {
          final file = entry.value as File;
          multipartRequest.files.add(
            await http.MultipartFile.fromPath(entry.key, file.path),
          );
        } else if (entry.value is http.MultipartFile) {
          multipartRequest.files.add(entry.value as http.MultipartFile);
        } else {
          multipartRequest.fields[entry.key] = entry.value.toString();
        }
      }
      
      // 发送请求
      final streamedResponse = await multipartRequest.send();
      
      // 读取响应
      final responseBody = await streamedResponse.stream.bytesToString();
      
      // 解析响应数据
      dynamic data;
      try {
        final contentType = streamedResponse.headers['content-type'] ?? '';
        if (contentType.contains('application/json')) {
          data = jsonDecode(responseBody);
        } else {
          data = responseBody;
        }
      } catch (e) {
        data = responseBody;
      }
      
      // 转换头部
      final responseHeaders = <String, List<String>>{};
      streamedResponse.headers.forEach((key, value) {
        responseHeaders[key] = [value];
      });
      
      final response = AdapterResponse(
        statusCode: streamedResponse.statusCode,
        statusMessage: streamedResponse.reasonPhrase,
        data: data,
        headers: responseHeaders,
        request: request,
      );
      
      // 检查是否是错误响应
      if (!response.isSuccess) {
        throw AdapterException(
          message: 'HTTP ${response.statusCode}',
          type: AdapterExceptionType.response,
          statusCode: response.statusCode,
          response: response,
        );
      }
      
      return response;
    } catch (e, stackTrace) {
      if (e is AdapterException) {
        rethrow;
      }
      throw _convertException(e, stackTrace);
    }
  }
  
  @override
  void cancel(adapter_cancel.CancelToken token) {
    token.cancel();
  }
  
  @override
  void addInterceptor(AdapterInterceptor interceptor) {
    _interceptors.add(interceptor);
  }
  
  @override
  void removeInterceptor(AdapterInterceptor interceptor) {
    _interceptors.remove(interceptor);
  }
}
