import 'dart:async';
import '../../type/http_method.dart';
import '../interceptor/adapter_interceptor.dart';
import '../models/adapter_request.dart';
import '../models/adapter_response.dart';
import '../exceptions/adapter_exception.dart';

/// author:郑再红
/// email:1096877329@qq.com
/// date:2026-08-07 9:44
/// describe: Token 自动刷新拦截器
/// 当请求返回 401/403 时，自动调用 [tokenProvider] 刷新 Token，
/// 并通过 [ErrorInterceptorHandler.retry] 使用新请求真正重试原请求。
/// 支持并发请求场景下的 Token 刷新去重。
///
/// 注意：重试由适配器执行，上层请求（如 `RxNet.get().request()`）最终
/// 拿到的是重试后的响应，而不是 401 错误。
class TokenRefreshInterceptor extends AdapterInterceptor {
  /// 重试请求标记，避免重试后再次 401 时无限刷新
  static const String retryFlagKey = '_rxnetTokenRetried';

  /// Token 刷新回调，返回新的 access token
  final Future<String> Function() tokenProvider;

  /// 判断是否为需要刷新 Token 的错误（默认判断 401）
  final bool Function(AdapterException error, AdapterRequest request)?
      isUnauthorized;

  /// 刷新 Token 后，更新请求中认证信息的回调
  /// [request] 原始请求，[newToken] 新 Token，返回更新后的请求
  final AdapterRequest Function(AdapterRequest request, String newToken)?
      onRequestUpdated;

  /// Token 刷新成功后的回调（可选）
  final void Function(String newToken)? onTokenRefreshed;

  /// Token 刷新前的回调（可选）
  final void Function()? onTokenRefreshing;

  /// Token 刷新失败后的回调（可选）
  final void Function(Object error)? onTokenRefreshFailed;

  /// 缓存最近的请求（按 key），用于错误对象没有携带请求时兜底
  final Map<String, AdapterRequest> _requestCache = {};

  /// 缓存上限，避免长期运行累积
  final int maxCacheEntries;

  Completer<String>? _refreshCompleter;
  DateTime? _lastRefreshTime;

  TokenRefreshInterceptor({
    required this.tokenProvider,
    this.isUnauthorized,
    this.onRequestUpdated,
    this.onTokenRefreshed,
    this.onTokenRefreshing,
    this.onTokenRefreshFailed,
    this.maxCacheEntries = 200,
  });

  @override
  void onRequest(AdapterRequest request, RequestInterceptorHandler handler) {
    // 缓存请求，key 为 URL + Method，onError 时使用
    final key = _generateKey(request);
    if (!_requestCache.containsKey(key) &&
        _requestCache.length >= maxCacheEntries) {
      _requestCache.remove(_requestCache.keys.first);
    }
    _requestCache[key] = request;
    handler.next(request);
  }

  @override
  void onResponse(
      AdapterResponse response, ResponseInterceptorHandler handler) {
    // 响应成功，清除缓存
    _requestCache.remove(_generateKey(response.request));
    handler.next(response);
  }

  @override
  Future<void> onError(
      AdapterException error, ErrorInterceptorHandler handler) async {
    final originalRequest = _resolveRequest(error);

    // 重试后仍然失败时不再刷新，避免死循环
    if (originalRequest?.extra[retryFlagKey] == true) {
      handler.next(error);
      return;
    }

    final shouldRefresh = isUnauthorized != null
        ? isUnauthorized!(error, originalRequest ?? _emptyRequest)
        : error.statusCode == 401;

    if (!shouldRefresh || originalRequest == null) {
      handler.next(error);
      return;
    }

    await _handleTokenRefresh(originalRequest, handler);
  }

  Future<void> _handleTokenRefresh(
    AdapterRequest originalRequest,
    ErrorInterceptorHandler handler,
  ) async {
    try {
      final newToken = await _refreshToken();

      // 通过 onRequestUpdated 回调让调用方更新请求中的认证信息
      final updatedRequest = onRequestUpdated != null
          ? onRequestUpdated!(originalRequest, newToken)
          : originalRequest;

      // 标记为重试请求，避免再次 401 时重复刷新
      final retryRequest = updatedRequest.copyWith(
        extra: {
          ...updatedRequest.extra,
          retryFlagKey: true,
        },
      );

      // 清除缓存
      _requestCache.remove(_generateKey(originalRequest));

      // 让适配器使用新请求真正重试
      handler.retry(retryRequest);
    } catch (e) {
      onTokenRefreshFailed?.call(e);
      handler.next(AdapterException(
        message: 'Token refresh failed: $e',
        type: AdapterExceptionType.unknown,
        originalError: e,
      ));
    }
  }

  /// 查找触发错误的原始请求
  AdapterRequest? _resolveRequest(AdapterException error) {
    final request = error.response?.request;
    if (request != null) {
      return request;
    }
    // 网络错误等场景可能没有 response，如果只有一个待处理请求则使用它
    if (_requestCache.length == 1) {
      return _requestCache.values.first;
    }
    return null;
  }

  Future<String> _refreshToken() async {
    if (_refreshCompleter != null && !_refreshCompleter!.isCompleted) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<String>();

    try {
      onTokenRefreshing?.call();
      final newToken = await tokenProvider();
      _lastRefreshTime = DateTime.now();
      onTokenRefreshed?.call(newToken);

      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.complete(newToken);
      }
      return newToken;
    } catch (e) {
      if (!_refreshCompleter!.isCompleted) {
        _refreshCompleter!.completeError(e);
        // 确保 Completer 的错误被消费，避免 Dart 将其报告为未处理错误
        _refreshCompleter!.future.ignore();
      }
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  String _generateKey(AdapterRequest request) {
    return '${request.method.name}|${request.baseUrl}|${request.path}';
  }

  DateTime? get lastRefreshTime => _lastRefreshTime;

  /// 清除所有缓存的请求
  void clearCache() {
    _requestCache.clear();
  }
}

/// 空请求占位符，用于无请求信息时的 fallback
final _emptyRequest = AdapterRequest(
  baseUrl: '',
  path: '',
  method: HttpMethod.GET,
);
