import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart' as dio;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:rxnet_plus/src/type/http_method.dart';
import '../../type/response_type.dart';
import '../network_adapter.dart';
import '../closable_network_adapter.dart';
import '../models/adapter_request.dart';
import '../models/adapter_response.dart';
import '../models/adapter_base_options.dart';
import '../interceptor/adapter_interceptor.dart';
import '../exceptions/adapter_exception.dart';
import '../cancel_token.dart' as adapter_cancel;
// 条件导入：Web/Wasm 使用 stub，IO 平台使用 dart:io
// Conditional import: stub for Web/Wasm, dart:io for IO platforms
import 'http_adapter_web_stub.dart'
    if (dart.library.io) 'dart:io';
// 条件导入：IO 平台用 IOClient，Web 平台用普通 http.Client
// Conditional import: IOClient on IO, plain http.Client on Web
import 'http_adapter_web.dart'
    if (dart.library.io) 'http_adapter_io.dart'
    show createDefaultHttpClient;

///
/// author: ZhengZaiHong
/// email: 1096877329@qq.com
/// date: 2026-04-23
/// describe：HttpAdapter - 基于 http 包的轻量级网络适配器 / Lightweight Network Adapter Based on http Package
/// ============================================================================
/// 类说明 / Class Description
/// ============================================================================
///
/// HttpAdapter 是 RxNet Plus 的轻量级网络适配器，基于 Dart 官方的 http 包实现。
/// 它提供了基础的 HTTP 功能，适合对包大小敏感或不需要高级功能的场景。
///
/// HttpAdapter is a lightweight network adapter for RxNet Plus, based on
/// Dart's official http package. It provides basic HTTP functionality,
/// suitable for scenarios sensitive to package size or not requiring
/// advanced features.
///
/// ============================================================================
/// 核心特性 / Core Features
/// ============================================================================
///
/// 1. **轻量级 / Lightweight**
///    - 基于 Dart 官方 http 包，无额外依赖
///    - Based on Dart's official http package, no extra dependencies
///    - 包大小更小，适合简单场景
///    - Smaller package size, suitable for simple scenarios
///
/// 2. **基础 HTTP 支持 / Basic HTTP Support**
///    - 支持所有标准 HTTP 方法
///    - Support for all standard HTTP methods
///    - 支持请求头和查询参数
///    - Support for headers and query parameters
///    - 支持 JSON 和文本响应
///    - Support for JSON and text responses
///
/// 3. **拦截器支持 / Interceptor Support**
///    - 完整的 AdapterInterceptor 支持
///    - Full AdapterInterceptor support
///    - 与 DioAdapter 相同的拦截器接口
///    - Same interceptor interface as DioAdapter
///
/// 4. **请求取消 / Request Cancellation**
///    - 支持 RxNet 的 CancelToken
///    - Support for RxNet's CancelToken
///    - 基于 Completer 的取消机制
///    - Completer-based cancellation mechanism
///
/// 5. **自定义 Client / Custom Client**
///    - 可以传入自定义的 http.Client
///    - Can pass in custom http.Client
///    - 支持证书固定等高级配置
///    - Support for advanced configurations like certificate pinning
///
/// ============================================================================
/// 适用场景 / Use Cases
/// ============================================================================
///
/// ✅ 适合使用 HttpAdapter 的场景 / Suitable for HttpAdapter:
///
/// 1. **简单的 REST API 调用 / Simple REST API Calls**
///    - 基础的 GET/POST 请求
///    - Basic GET/POST requests
///    - 不需要复杂的拦截器逻辑
///    - No need for complex interceptor logic
///
/// 2. **包大小敏感的应用 / Size-Sensitive Applications**
///    - 需要减小应用体积
///    - Need to reduce app size
///    - 不需要 Dio 的高级功能
///    - Don't need Dio's advanced features
///
/// 3. **证书固定 / Certificate Pinning**
///    - 需要自定义 SSL/TLS 验证
///    - Need custom SSL/TLS validation
///    - 可以通过自定义 IOClient 实现
///    - Can be implemented via custom IOClient
///
/// ❌ 不适合使用 HttpAdapter 的场景 / Not Suitable for HttpAdapter:
///
/// 1. **真正取消的大文件传输 / True-Cancel Large Transfers**
///    - HttpAdapter 的取消是协作式的，请求可能仍在后台继续
///    - HttpAdapter cancellation is cooperative, so the underlying request may continue in the background
///    - 需要立即中止连接时建议使用 DioAdapter
///    - Use DioAdapter when you need the transport to abort immediately
///
/// 2. **复杂的拦截器需求 / Complex Interceptor Requirements**
///    - 需要修改请求体或响应体
///    - Need to modify request/response body
///    - DioAdapter 提供更好的支持
///    - DioAdapter provides better support
///
/// 3. **高级传输控制 / Advanced Transport Control**
///    - HttpAdapter 已支持基础流式响应和上传下载进度
///    - HttpAdapter now supports basic streaming responses and upload/download progress
///    - 如需更强的传输控制、生态能力或排障体验，建议使用 DioAdapter
///    - Prefer DioAdapter for richer transport controls, ecosystem features, and diagnostics
///
/// ============================================================================
/// 使用示例 / Usage Examples
/// ============================================================================
///
/// 1. 基础使用 / Basic Usage:
/// ```dart
/// final api = RxNet.create();
/// await api.initNet(
///   baseUrl: "https://api.example.com",
///   adapter: HttpAdapter(),
/// );
///
/// final result = await api.getRequest()
///   .setPath("/users")
///   .request();
/// ```
///
/// 2. 使用自定义 Client / Using Custom Client:
/// ```dart
/// final httpClient = HttpClient();
/// httpClient.badCertificateCallback = (cert, host, port) {
///   // 生产环境必须校验证书指纹，绝不能直接 return true
///   // Never return true in production; verify a pinned fingerprint.
///   final fingerprint = sha256.convert(cert.der).toString();
///   return fingerprint == 'YOUR_CERT_SHA256_FINGERPRINT';
/// };
///
/// final client = IOClient(httpClient);
/// final adapter = HttpAdapter(client: client);
///
/// await api.initNet(
///   baseUrl: "https://api.example.com",
///   adapter: adapter,
/// );
/// ```
///
/// 3. 证书固定示例 / Certificate Pinning Example:
/// ```dart
/// IOClient createPinnedClient() {
///   final httpClient = HttpClient();
///   httpClient.badCertificateCallback = (cert, host, port) {
///     // 获取证书指纹并验证
///     // Get certificate fingerprint and validate
///     final der = cert.der;
///     final sha256 = sha256Convert(der);
///     const trustedFingerprint = "YOUR_SHA256_FINGERPRINT";
///     return sha256 == trustedFingerprint;
///   };
///   return IOClient(httpClient);
/// }
///
/// final adapter = HttpAdapter(client: createPinnedClient());
/// ```
///
/// 4. 添加拦截器 / Adding Interceptors:
/// ```dart
/// final adapter = HttpAdapter();
/// adapter.addInterceptor(RxNetLogAdapterInterceptor());
/// adapter.addInterceptor(AuthInterceptor());
///
/// await api.initNet(
///   baseUrl: "https://api.example.com",
///   adapter: adapter,
/// );
/// ```
///
/// ============================================================================
/// 与 DioAdapter 的对比 / Comparison with DioAdapter
/// ============================================================================
///
/// | 特性 / Feature              | HttpAdapter | DioAdapter |
/// |----------------------------|-------------|------------|
/// | 包大小 / Package Size       | ✅ 小 / Small | ❌ 大 / Large |
/// | 基础请求 / Basic Requests   | ✅ 支持 / Yes | ✅ 支持 / Yes |
/// | 文件上传 / File Upload      | ⚠️ 基础 / Basic | ✅ 完整 / Full |
/// | 文件下载 / File Download    | ⚠️ 基础 / Basic | ✅ 完整 / Full |
/// | 进度回调 / Progress         | ❌ 不支持 / No | ✅ 支持 / Yes |
/// | 流式响应 / Streaming        | ❌ 不支持 / No | ✅ 支持 / Yes |
/// | 拦截器 / Interceptors       | ✅ 支持 / Yes | ✅ 支持 / Yes |
/// | 证书固定 / Cert Pinning     | ✅ 支持 / Yes | ✅ 支持 / Yes |
/// | 请求取消 / Cancellation     | ✅ 支持 / Yes | ✅ 支持 / Yes |
///
/// ============================================================================
/// 性能考虑 / Performance Considerations
/// ============================================================================
///
/// 1. **内存使用 / Memory Usage**
///    - HttpAdapter 内存占用更小
///    - HttpAdapter has smaller memory footprint
///    - 适合资源受限的设备
///    - Suitable for resource-constrained devices
///
/// 2. **请求速度 / Request Speed**
///    - 简单请求性能相当
///    - Similar performance for simple requests
///    - 复杂场景 DioAdapter 可能更快
///    - DioAdapter may be faster in complex scenarios
///
/// 3. **启动时间 / Startup Time**
///    - HttpAdapter 启动更快
///    - HttpAdapter starts faster
///    - 依赖更少，初始化更快
///    - Fewer dependencies, faster initialization
///
/// ============================================================================
/// 限制和注意事项 / Limitations and Notes
/// ============================================================================
///
/// 1. **取消机制 / Cancellation Mechanism**
///    - 基于 `http` 包的能力做协作式取消
///    - Uses cooperative cancellation based on the `http` package
///    - 已发送的底层连接不一定会像 Dio 那样立即中断
///    - An in-flight socket may not abort as immediately as Dio
///
/// 2. **平台文件能力 / Local File APIs**
///    - Web 平台不能直接写入本地文件路径
///    - Web cannot write directly to a local file path
///    - 如需浏览器下载，请使用 Web 侧下载 API
///    - Use a browser download API on Web when needed
///
/// 3. **适用场景 / Best Fit**
///    - 适合轻量级请求、基础上传下载与跨平台兼容场景
///    - Best for lightweight requests, basic upload/download, and broad compatibility
///    - 对强取消语义要求很高时仍推荐 DioAdapter
///    - DioAdapter is still recommended when hard cancellation semantics matter
///
/// ============================================================================
///
/// See also / 另见:
/// - [NetworkAdapter] for the adapter interface
/// - [DioAdapter] for a full-featured alternative
/// - [MockAdapter] for testing
/// - [AdapterInterceptor] for interceptor implementation
///
/// ============================================================================

/// HttpAdapter - http package-based implementation of NetworkAdapter
///
/// HttpAdapter - 基于 http 包的 NetworkAdapter 实现
///
/// This is a lightweight adapter that uses Dart's official http package.
/// It's suitable for simple scenarios where package size matters.
///
/// 这是一个使用 Dart 官方 http 包的轻量级适配器。
/// 适合对包大小敏感的简单场景。
class HttpAdapter implements NetworkAdapter, ClosableNetworkAdapter {
  final http.Client _client;
  final List<AdapterInterceptor> _interceptors = [];
  final Map<adapter_cancel.CancelToken, List<Completer>> _pendingRequests = {};
  final Map<adapter_cancel.CancelToken, void Function(String?)>
      _cancelCallbacks = {};

  /// 底层 dart:io HttpClient 引用（仅在 IOClient 场景下非 null）
  /// 用于在 applyBaseOptions 时设置原生参数（超时、重定向等）
  final HttpClient? _nativeHttpClient;

  /// Creates an HttpAdapter.
  ///
  /// 创建 HttpAdapter。
  ///
  /// Parameters / 参数:
  /// - [client]: Optional custom http.Client instance. If not provided,
  ///             a default instance will be created.
  ///             可选的自定义 http.Client 实例。如果不提供，将创建默认实例。
  /// - [httpClient]: Optional dart:io HttpClient for native configuration.
  ///                 When provided, connectTimeout/followRedirects/maxRedirects
  ///                 from AdapterBaseOptions will be applied directly.
  ///                 可选的 dart:io HttpClient，用于原生参数配置。
  ///
  /// Example / 示例:
  /// ```dart
  /// // Using default client / 使用默认 client
  /// final adapter = HttpAdapter();
  ///
  /// // Using custom client with native config / 使用自定义 client
  /// final httpClient = HttpClient()
  ///   ..connectionTimeout = Duration(seconds: 10);
  /// final adapter = HttpAdapter(httpClient: httpClient);
  /// ```
  HttpAdapter({http.Client? client, HttpClient? httpClient})
      : _client = client ?? createDefaultHttpClient(httpClient),
        _nativeHttpClient = httpClient;

  /// Gets the underlying http.Client instance.
  ///
  /// 获取底层 http.Client 实例。
  ///
  /// This allows direct access to the client for advanced configuration.
  /// 这允许直接访问 client 进行高级配置。
  http.Client get client => _client;

  @override
  String get name => 'HttpAdapter';

  @override
  String get version => '1.0.0';

  @override
  void setBaseUrl(String url) {
    // HttpAdapter 的 baseUrl 通过 RxNet._baseUrl 管理，
    // 无需在 adapter 层面存储。此处为空实现。
  }


  /// 全局默认配置（适配器无关）
  AdapterBaseOptions? _baseOptions;

  @override
  void applyBaseOptions(AdapterBaseOptions options) {
    _baseOptions = options;
    // 如果底层 client 是 IOClient，配置 dart:io HttpClient 的原生参数
    _applyToNativeHttpClient(options);
  }

  /// 将 AdapterBaseOptions 应用到底层 dart:io HttpClient（仅 IOClient 有效）
  void _applyToNativeHttpClient(AdapterBaseOptions options) {
    if (kIsWeb) return;
    final nativeClient = _nativeHttpClient;
    if (nativeClient == null) return;

    try {
      if (options.connectTimeout != null) {
        nativeClient.connectionTimeout = options.connectTimeout;
      }
      nativeClient.idleTimeout =
          options.receiveTimeout ?? AdapterBaseOptions.defaultReceiveTimeout;

    } catch (_) {
      // 平台不支持，静默忽略
    }
  }

  /// 获取底层 dart:io HttpClient 实例
  HttpClient? getHttpClient() => _nativeHttpClient;

  @override
  Future<AdapterResponse> request(AdapterRequest request) {
    return _executeWithInterceptors(
      request,
      (currentRequest, completer, cancelToken) => _performRequest(
        currentRequest,
        completer: completer,
        cancelToken: cancelToken,
      ),
    );
  }

  /// 统一的拦截器执行/重试包装，供 request/download/upload 复用
  Future<AdapterResponse> _executeWithInterceptors(
    AdapterRequest request,
    Future<AdapterResponse> Function(
      AdapterRequest request,
      Completer<void> completer,
      adapter_cancel.CancelToken? cancelToken,
    ) operation,
  ) async {
    var currentRequest = request;

    // 请求拦截器（支持同步/异步实现）
    for (final interceptor in _interceptors) {
      final handler = RequestInterceptorHandler();
      await interceptor.onRequest(currentRequest, handler);

      if (handler.resolvedResponse != null) {
        return handler.resolvedResponse!;
      }
      if (handler.rejectedError != null) {
        throw handler.rejectedError!;
      }
      if (handler.modifiedRequest != null) {
        currentRequest = handler.modifiedRequest!;
      }
    }

    var retryCount = 0;

    while (true) {
      final completer = Completer<void>();
      adapter_cancel.CancelToken? activeCancelToken;

      try {
        activeCancelToken = currentRequest.cancelToken;
        if (activeCancelToken != null) {
          _registerCancelToken(activeCancelToken, completer);
          if (activeCancelToken.isCancelled) {
            throw AdapterException(
              type: AdapterExceptionType.cancel,
              message: activeCancelToken.cancelReason ?? 'Request cancelled',
            );
          }
        }

        var response = await operation(
          currentRequest,
          completer,
          activeCancelToken,
        );

        // 响应拦截器（支持同步/异步实现）
        for (final interceptor in _interceptors) {
          final handler = ResponseInterceptorHandler();
          await interceptor.onResponse(response, handler);

          if (handler.rejectedError != null) {
            throw handler.rejectedError!;
          }
          if (handler.modifiedResponse != null) {
            response = handler.modifiedResponse!;
          }
        }

        return response;
      } on AdapterException catch (e) {
        final outcome = await _executeErrorInterceptors(e);
        if (outcome.response != null) {
          return outcome.response!;
        }
        if (outcome.retryRequest != null &&
            retryCount < kMaxAdapterInterceptorRetries) {
          retryCount++;
          currentRequest = outcome.retryRequest!;
          continue;
        }
        throw outcome.error ?? e;
      } catch (e, stackTrace) {
        final exception = _convertException(e, stackTrace);
        final outcome = await _executeErrorInterceptors(exception);
        if (outcome.response != null) {
          return outcome.response!;
        }
        if (outcome.retryRequest != null &&
            retryCount < kMaxAdapterInterceptorRetries) {
          retryCount++;
          currentRequest = outcome.retryRequest!;
          continue;
        }
        throw outcome.error ?? exception;
      } finally {
        _unregisterCancelToken(activeCancelToken, completer);
      }
    }
  }

  /// 执行底层请求（不包含拦截器）
  Future<AdapterResponse> _performRequest(
    AdapterRequest request, {
    required Completer<void> completer,
    required adapter_cancel.CancelToken? cancelToken,
  }) async {
    final effectiveRequest = _baseOptions?.applyToRequest(request) ?? request;
    final baseRequest = await _buildBaseRequest(effectiveRequest);

    // --- 超时策略 ---
    // connectTimeout 包裹 send() 阶段（建连 + 获取响应头）
    // receiveTimeout 包裹 Response.fromStream() 阶段（读取响应体）
    // sendTimeout 额外约束整个发送阶段
    var sendFuture = _applySendTimeout(
      _client.send(baseRequest),
      effectiveRequest,
    );

    final streamedResponse = cancelToken != null
        ? await Future.any<http.StreamedResponse>([
            sendFuture,
            completer.future.then((_) => throw AdapterException(
                  type: AdapterExceptionType.cancel,
                  message: cancelToken.cancelReason ?? 'Request cancelled',
                )),
          ])
        : await sendFuture;

    // --- receiveDataWhenStatusError 控制 ---
    // 当状态码表示错误且 receiveDataWhenStatusError 为 false 时，
    // 不读取响应体以节省带宽
    final isErrorResponse = streamedResponse.statusCode >= 400;
    final shouldReadBody = !isErrorResponse ||
        (_baseOptions?.receiveDataWhenStatusError ?? true);

    var response = effectiveRequest.responseType == ResponseType.stream
        ? _convertFromHttpStreamedResponse(streamedResponse, effectiveRequest)
        : _convertFromHttpResponse(
            shouldReadBody
                ? await _readResponseWithTimeout(
                    streamedResponse,
                    effectiveRequest,
                  )
                : http.Response('', streamedResponse.statusCode,
                    headers: streamedResponse.headers),
            effectiveRequest,
          );

    if (!response.isSuccess) {
      throw AdapterException(
        message:
            'HTTP ${response.statusCode}: ${response.statusMessage ?? ""}',
        type: AdapterExceptionType.response,
        statusCode: response.statusCode,
        response: response,
      );
    }

    return response;
  }

  /// 执行错误拦截器
  Future<_ErrorHandlingResult> _executeErrorInterceptors(
    AdapterException error,
  ) async {
    var currentError = error;

    for (final interceptor in _interceptors) {
      final handler = ErrorInterceptorHandler();
      await interceptor.onError(currentError, handler);

      if (handler.resolvedResponse != null) {
        return _ErrorHandlingResult(response: handler.resolvedResponse);
      }
      if (handler.retryRequest != null) {
        return _ErrorHandlingResult(retryRequest: handler.retryRequest);
      }
      if (handler.modifiedError != null) {
        currentError = handler.modifiedError!;
      }
    }

    return _ErrorHandlingResult(error: currentError);
  }

  /// 应用 connectTimeout / sendTimeout
  Future<http.StreamedResponse> _applySendTimeout(
    Future<http.StreamedResponse> future,
    AdapterRequest request,
  ) {
    final connectTimeout = request.connectTimeout ??
        _baseOptions?.connectTimeout ??
        AdapterBaseOptions.defaultConnectTimeout;

    var result = future;
    if (connectTimeout.inMilliseconds > 0) {
      result = result.timeout(
        connectTimeout,
        onTimeout: () => throw AdapterException(
          type: AdapterExceptionType.connectTimeout,
          message: 'Connect timeout after ${connectTimeout.inSeconds}s',
        ),
      );
    }

    final sendTimeout = request.sendTimeout ??
        _baseOptions?.sendTimeout ??
        AdapterBaseOptions.defaultSendTimeout;
    if (sendTimeout.inMilliseconds > 0) {
      result = result.timeout(
        sendTimeout,
        onTimeout: () => throw AdapterException(
          type: AdapterExceptionType.sendTimeout,
          message: 'Send timeout after ${sendTimeout.inSeconds}s',
        ),
      );
    }

    return result;
  }

  String _convertHttpMethod(HttpMethod method) {
    return method.name.toUpperCase();
  }

  Future<http.BaseRequest> _buildBaseRequest(
    AdapterRequest request, {
    ProgressCallback? onProgress,
  }) async {
    final method = _convertHttpMethod(request.method);
    final uri = _buildUri(request);
    final headers = _buildHeaders(request);

    if (_shouldUseMultipartUpload(request)) {
      headers.removeWhere(
        (key, _) => key.toLowerCase() == HttpHeaders.contentTypeHeader,
      );

      final multipartRequest = http.MultipartRequest(method, uri);
      multipartRequest.headers.addAll(headers);
      _applyRedirectOptions(multipartRequest);
      await _applyMultipartBody(multipartRequest, request);

      if (onProgress == null) {
        return multipartRequest;
      }

      final streamedRequest = http.StreamedRequest(method, uri);
      streamedRequest.headers.addAll(multipartRequest.headers);
      streamedRequest.contentLength = multipartRequest.contentLength;
      _applyRedirectOptions(streamedRequest);
      _applyRequestBody(
        streamedRequest,
        multipartRequest.finalize(),
        request: request,
        onProgress: onProgress,
      );
      return streamedRequest;
    }

    final body = _buildBody(request);
    final bodyStream = _extractRequestBodyStream(body);
    if (bodyStream != null) {
      final streamedRequest = http.StreamedRequest(method, uri);
      streamedRequest.headers.addAll(headers);
      _applyRedirectOptions(streamedRequest);
      _applyContentLength(streamedRequest, request, body);
      _applyRequestBody(
        streamedRequest,
        bodyStream,
        request: request,
        onProgress: onProgress,
      );
      return streamedRequest;
    }

    final httpRequest = http.Request(method, uri);
    httpRequest.headers.addAll(headers);
    _applyRedirectOptions(httpRequest);
    _applyRequestBody(
      httpRequest,
      body,
      request: request,
      onProgress: onProgress,
    );
    return httpRequest;
  }

  /// 应用全局重定向配置（http 包通过 BaseRequest 控制）
  void _applyRedirectOptions(http.BaseRequest request) {
    request.followRedirects = _baseOptions?.followRedirects ?? true;
    request.maxRedirects = _baseOptions?.maxRedirects ?? 5;
  }

  Stream<List<int>>? _extractRequestBodyStream(dynamic body) {
    if (body is Stream<List<int>>) {
      return body;
    }
    if (body is Stream<Uint8List>) {
      return body;
    }
    if (body is Uint8List) {
      return Stream<List<int>>.value(body);
    }
    if (body is List<int>) {
      return Stream<List<int>>.value(body);
    }
    return null;
  }

  Uint8List _collectRequestBodyBytes(dynamic body) {
    if (body == null) {
      return Uint8List(0);
    }
    if (body is Uint8List) {
      return body;
    }
    if (body is List<int>) {
      return Uint8List.fromList(body);
    }
    if (body is String) {
      return Uint8List.fromList(utf8.encode(body));
    }
    if (body is Map) {
      return Uint8List.fromList(utf8.encode(jsonEncode(body)));
    }
    return Uint8List.fromList(utf8.encode(body.toString()));
  }

  void _applyContentLength(
    http.StreamedRequest streamedRequest,
    AdapterRequest request,
    dynamic body,
  ) {
    final headerLength = request.headers.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == HttpHeaders.contentLengthHeader,
          orElse: () => MapEntry<String, String>('', ''),
        )
        .value
        .toString();
    final parsedLength = int.tryParse(headerLength);
    if (parsedLength != null && parsedLength >= 0) {
      streamedRequest.contentLength = parsedLength;
      return;
    }

    if (body is Uint8List || body is List<int>) {
      streamedRequest.contentLength = (body as List<int>).length;
      return;
    }
    if (body is String) {
      streamedRequest.contentLength = utf8.encode(body).length;
    }
  }

  void _applyRequestBody(
    http.BaseRequest baseRequest,
    dynamic body, {
    required AdapterRequest request,
    ProgressCallback? onProgress,
  }) {
    if (body == null) {
      return;
    }

    if (baseRequest is http.Request) {
      if (body is String) {
        baseRequest.body = body;
        final total = utf8.encode(body).length;
        onProgress?.call(total, total);
        return;
      }
      if (body is Uint8List) {
        baseRequest.bodyBytes = body;
        onProgress?.call(body.length, body.length);
        return;
      }
      if (body is List<int>) {
        baseRequest.bodyBytes = body;
        onProgress?.call(body.length, body.length);
        return;
      }
      if (body is Map) {
        baseRequest.body = jsonEncode(body);
        final total = baseRequest.bodyBytes.length;
        onProgress?.call(total, total);
        return;
      }

      final bodyBytes = _collectRequestBodyBytes(body);
      baseRequest.bodyBytes = bodyBytes;
      onProgress?.call(bodyBytes.length, bodyBytes.length);
      return;
    }

    if (baseRequest is http.StreamedRequest) {
      final stream = _extractRequestBodyStream(body) ??
          Stream<List<int>>.value(_collectRequestBodyBytes(body));
      final total = baseRequest.contentLength;

      unawaited(() async {
        var sent = 0;
        try {
          await for (final chunk in stream) {
            if (request.cancelToken?.isCancelled == true) {
              throw AdapterException.cancel(
                message: request.cancelToken!.cancelReason,
              );
            }
            sent += chunk.length;
            onProgress?.call(
              sent,
              total != null && total > 0 ? total : sent,
            );
            baseRequest.sink.add(chunk);
          }
          await baseRequest.sink.close();
        } catch (error, stackTrace) {
          baseRequest.sink.addError(error, stackTrace);
          await baseRequest.sink.close();
        }
      }());
    }
  }

  bool _shouldUseMultipartUpload(AdapterRequest request) {
    if (request.rawBody != null) {
      return false;
    }
    if (request.bodyParams.isEmpty) {
      return false;
    }

    final isMultipartContentType =
        request.contentType?.toLowerCase().contains('multipart') == true;
    if (isMultipartContentType) {
      return true;
    }

    return request.bodyParams.values.any(_isMultipartValue);
  }

  bool _isMultipartValue(dynamic value) {
    return value is File ||
        value is http.MultipartFile ||
        value is dio.MultipartFile;
  }

  Future<void> _applyMultipartBody(
    http.MultipartRequest multipartRequest,
    AdapterRequest request,
  ) async {
    for (final entry in request.bodyParams.entries) {
      if (_isMultipartValue(entry.value)) {
        multipartRequest.files.add(
          await _toMultipartFile(entry.key, entry.value),
        );
      } else {
        multipartRequest.fields[entry.key] = entry.value?.toString() ?? '';
      }
    }
  }

  Future<http.MultipartFile> _toMultipartFile(
    String field,
    dynamic value,
  ) async {
    if (value is http.MultipartFile) {
      return value;
    }
    if (value is dio.MultipartFile) {
      return http.MultipartFile(
        field,
        value.finalize(),
        value.length,
        filename: value.filename,
        contentType: value.contentType,
      );
    }
    if (!kIsWeb && value is File) {
      return http.MultipartFile.fromPath(field, value.path);
    }

    throw AdapterException(
      message: 'Unsupported multipart value for field: $field',
      type: AdapterExceptionType.unknown,
    );
  }

  /// 注册取消令牌
  void _registerCancelToken(
      adapter_cancel.CancelToken token, Completer completer) {
    final pending = _pendingRequests.putIfAbsent(token, () => []);
    pending.add(completer);

    // 每个 token 只注册一个回调，避免同一 token 多次请求时回调堆积
    if (_cancelCallbacks.containsKey(token)) {
      return;
    }

    void callback(String? reason) {
      final completers = _pendingRequests.remove(token);
      if (completers != null) {
        for (final c in completers) {
          if (!c.isCompleted) {
            c.completeError(AdapterException(
              type: AdapterExceptionType.cancel,
              message: reason ?? 'Request cancelled',
            ));
          }
        }
      }
      // token 取消时会自行清空回调列表，这里只清理映射
      _cancelCallbacks.remove(token);
    }

    _cancelCallbacks[token] = callback;
    token.whenCancel(callback);
  }

  /// 注销取消令牌
  void _unregisterCancelToken(
      adapter_cancel.CancelToken? token, Completer completer) {
    if (token == null) return;

    final pending = _pendingRequests[token];
    if (pending == null) return;

    pending.remove(completer);
    if (pending.isNotEmpty) return;

    _pendingRequests.remove(token);
    final callback = _cancelCallbacks.remove(token);
    if (callback != null) {
      token.removeCallback(callback);
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
      ...request.queryParams
          .map((key, value) => MapEntry(key, value.toString())),
    });
  }

  /// 构建头部
  Map<String, String> _buildHeaders(AdapterRequest request) {
    final headers = <String, String>{};

    // 1. 先合并全局默认 header（优先级最低）
    final globalHeaders = _baseOptions?.headers;
    if (globalHeaders != null) {
      for (final entry in globalHeaders.entries) {
        if (entry.value is List) {
          headers[entry.key] = (entry.value as List).join(', ');
        } else {
          headers[entry.key] = entry.value.toString();
        }
      }
    }

    // 2. 再合并请求级 header（覆盖全局）
    for (final entry in request.headers.entries) {
      if (entry.value is List) {
        headers[entry.key] = (entry.value as List).join(', ');
      } else {
        headers[entry.key] = entry.value.toString();
      }
    }

    final hasContentTypeHeader = headers.keys.any(
      (key) => key.toLowerCase() == HttpHeaders.contentTypeHeader,
    );

    // 如果有 contentType，添加到头部（请求级 > 全局默认）
    final contentType = request.contentType ?? _baseOptions?.contentType ;
    if (contentType != null && !hasContentTypeHeader) {
      headers['content-type'] = contentType;
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
          .map((e) =>
              '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');
    } else {
      // 默认使用 JSON
      return jsonEncode(request.bodyParams);
    }
  }

  /// 读取响应体，应用 receiveTimeout
  Future<http.Response> _readResponseWithTimeout(
    http.StreamedResponse streamedResponse,
    AdapterRequest request,
  ) async {
    var responseFuture = http.Response.fromStream(streamedResponse);
    final receiveTimeout = request.receiveTimeout ??
        _baseOptions?.receiveTimeout ??
        AdapterBaseOptions.defaultReceiveTimeout;
    if (receiveTimeout.inMilliseconds > 0) {
      responseFuture = responseFuture.timeout(
        receiveTimeout,
        onTimeout: () => throw AdapterException(
          type: AdapterExceptionType.receiveTimeout,
          message: 'Receive timeout after ${receiveTimeout.inSeconds}s',
        ),
      );
    }
    return responseFuture;
  }

  /// 转换 http.Response 到 AdapterResponse
  AdapterResponse _convertFromHttpResponse(
    http.Response httpResponse,
    AdapterRequest request,
  ) {
    dynamic data;
    switch (request.responseType) {
      case ResponseType.bytes:
        data = httpResponse.bodyBytes;
        break;
      case ResponseType.plain:
        data = httpResponse.body;
        break;
      case ResponseType.stream:
        data = httpResponse.bodyBytes;
        break;
      case ResponseType.json:
        try {
          data = jsonDecode(utf8.decode(httpResponse.bodyBytes));
        } catch (e) {
          data = httpResponse.body;
        }
        break;
    }

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
      successOverride: _baseOptions?.validateStatus?.call(httpResponse.statusCode),
    );
  }

  AdapterResponse _convertFromHttpStreamedResponse(
    http.StreamedResponse streamedResponse,
    AdapterRequest request,
  ) {
    final headers = <String, List<String>>{};
    streamedResponse.headers.forEach((key, value) {
      headers[key] = [value];
    });

    return AdapterResponse(
      statusCode: streamedResponse.statusCode,
      statusMessage: streamedResponse.reasonPhrase,
      data: _bindCancelToken(streamedResponse.stream, request.cancelToken),
      headers: headers,
      request: request,
      isRedirect: streamedResponse.isRedirect,
      redirectUrl: streamedResponse.request?.url.toString(),
      successOverride: _baseOptions?.validateStatus
          ?.call(streamedResponse.statusCode),
    );
  }

  Stream<List<int>> _bindCancelToken(
    Stream<List<int>> source,
    adapter_cancel.CancelToken? token,
  ) async* {
    await for (final chunk in source) {
      if (token?.isCancelled == true) {
        throw AdapterException.cancel(
          message: token!.cancelReason,
        );
      }
      yield chunk;
    }
  }

  /// 转换异常
  AdapterException _convertException(Object error, StackTrace stackTrace) {
    // 使用字符串检查而不是类型检查，以支持 Web 平台
    // Use string checking instead of type checking to support Web platform
    final errorString = error.toString();
    final formattedError = _formatWebConnectionError(errorString);

    if (errorString.contains('SocketException') ||
        errorString.contains('Failed host lookup') ||
        errorString.contains('Connection refused') ||
        errorString.contains('Connection error') ||
        errorString.contains('XMLHttpRequest') ||
        errorString.contains('ClientException: XMLHttpRequest')) {
      return AdapterException(
        message: 'Connection error: $formattedError',
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
    } else if (errorString.contains('HttpException') ||
        errorString.contains('HTTP error')) {
      return AdapterException(
        message: 'HTTP error: $errorString',
        type: AdapterExceptionType.response,
        originalError: error,
        stackTrace: stackTrace,
      );
    } else if (errorString.contains('SocketException') ||
        errorString.contains('Failed host lookup') ||
        errorString.contains('Connection refused')) {
      // 处理包装的 SocketException
      return AdapterException(
        message: 'Connection error: $formattedError',
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

  String _formatWebConnectionError(String errorString) {
    if (!kIsWeb) {
      return errorString;
    }

    final normalized = errorString.toLowerCase();
    final looksLikeBrowserError = normalized.contains('xmlhttprequest') ||
        normalized.contains('failed to fetch') ||
        normalized.contains('networkerror');

    if (!looksLikeBrowserError) {
      return errorString;
    }

    return '$errorString On Web this usually means the browser blocked the request because of CORS, mixed content (an HTTP request from an HTTPS page), or a TLS/HTTPS problem on the target URL.';
  }

  @override
  Future<AdapterResponse> download(
    AdapterRequest request,
    String savePath, {
    ProgressCallback? onProgress,
  }) {
    return _executeWithInterceptors(
      request,
      (currentRequest, completer, cancelToken) => _performDownload(
        currentRequest,
        savePath,
        completer: completer,
        cancelToken: cancelToken,
        onProgress: onProgress,
      ),
    );
  }

  Future<AdapterResponse> _performDownload(
    AdapterRequest request,
    String savePath, {
    required Completer<void> completer,
    required adapter_cancel.CancelToken? cancelToken,
    ProgressCallback? onProgress,
  }) async {
    final effectiveRequest = _baseOptions?.applyToRequest(request) ?? request;
    final baseRequest = await _buildBaseRequest(effectiveRequest);

    var sendFuture = _applySendTimeout(
      _client.send(baseRequest),
      effectiveRequest,
    );

    final streamedResponse = cancelToken != null
        ? await Future.any<http.StreamedResponse>([
            sendFuture,
            completer.future.then((_) => throw AdapterException.cancel(
                  message: cancelToken.cancelReason,
                )),
          ])
        : await sendFuture;

    final response = _convertFromHttpStreamedResponse(
      streamedResponse,
      effectiveRequest,
    );
    if (!response.isSuccess) {
      throw AdapterException(
        message: 'HTTP ${streamedResponse.statusCode}',
        type: AdapterExceptionType.response,
        statusCode: streamedResponse.statusCode,
        response: response,
      );
    }

    if (kIsWeb) {
      throw AdapterException(
        message:
            'File download is not supported on Web platform. Use browser download API instead.',
        type: AdapterExceptionType.unknown,
      );
    }

    final file = File(savePath);
    if (!file.parent.existsSync()) {
      file.parent.createSync(recursive: true);
    }
    final sink = file.openWrite();

    try {
      var received = 0;
      final total = streamedResponse.contentLength ?? -1;

      await for (final chunk in _bindCancelToken(
        streamedResponse.stream,
        cancelToken,
      )) {
        sink.add(chunk);
        received += chunk.length;
        onProgress?.call(received, total > 0 ? total : received);
      }
    } finally {
      await sink.flush();
      await sink.close();
    }

    return AdapterResponse(
      statusCode: streamedResponse.statusCode,
      statusMessage: streamedResponse.reasonPhrase,
      data: savePath,
      headers: response.headers,
      request: effectiveRequest,
      successOverride: response.successOverride,
    );
  }

  @override
  Future<AdapterResponse> upload(
    AdapterRequest request, {
    ProgressCallback? onProgress,
  }) {
    return _executeWithInterceptors(
      request,
      (currentRequest, completer, cancelToken) => _performUpload(
        currentRequest,
        completer: completer,
        cancelToken: cancelToken,
        onProgress: onProgress,
      ),
    );
  }

  Future<AdapterResponse> _performUpload(
    AdapterRequest request, {
    required Completer<void> completer,
    required adapter_cancel.CancelToken? cancelToken,
    ProgressCallback? onProgress,
  }) async {
    final effectiveRequest = _baseOptions?.applyToRequest(request) ?? request;
    final baseRequest = await _buildBaseRequest(
      effectiveRequest,
      onProgress: onProgress,
    );

    var sendFuture = _applySendTimeout(
      _client.send(baseRequest),
      effectiveRequest,
    );

    final streamedResponse = cancelToken != null
        ? await Future.any<http.StreamedResponse>([
            sendFuture,
            completer.future.then((_) => throw AdapterException.cancel(
                  message: cancelToken.cancelReason,
                )),
          ])
        : await sendFuture;

    if (effectiveRequest.responseType == ResponseType.stream) {
      final response = _convertFromHttpStreamedResponse(
        streamedResponse,
        effectiveRequest,
      );
      if (!response.isSuccess) {
        throw AdapterException(
          message: 'HTTP ${response.statusCode}',
          type: AdapterExceptionType.response,
          statusCode: response.statusCode,
          response: response,
        );
      }
      return response;
    }

    final response = _convertFromHttpResponse(
      await _readResponseWithTimeout(streamedResponse, effectiveRequest),
      effectiveRequest,
    );

    if (!response.isSuccess) {
      throw AdapterException(
        message: 'HTTP ${response.statusCode}',
        type: AdapterExceptionType.response,
        statusCode: response.statusCode,
        response: response,
      );
    }

    return response;
  }

  @override
  void cancel(adapter_cancel.CancelToken token) {
    token.cancel();
  }

  @override
  Future<void> close() async {
    _interceptors.clear();
    _pendingRequests.clear();
    _cancelCallbacks.clear();
    _client.close();
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
/// 错误拦截器处理结果
class _ErrorHandlingResult {
  final AdapterException? error;
  final AdapterResponse? response;
  final AdapterRequest? retryRequest;

  const _ErrorHandlingResult({
    this.error,
    this.response,
    this.retryRequest,
  });
}
