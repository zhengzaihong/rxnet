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
/// 当请求返回 401/403 时，自动调用 [tokenProvider] 刷新 Token 并重试原请求。
/// 支持并发请求场景下的 Token 刷新去重。
// TokenRefreshInterceptor(
//   tokenProvider: () async {
//     final resp = await RxNet.post().xxxx;
//     return resp.data['accessToken'];
//   },
//   isUnauthorized: (error, request) => error.statusCode == 401,
//   onRequestUpdated: (request, newToken) {
//     return request.copyWith(
//       headers: {...request.headers, 'Authorization': 'Bearer $newToken'},
//     );
//   },
//   onTokenRefreshed: (token) => currentToken = token,
// );
///
class TokenRefreshInterceptor extends AdapterInterceptor {
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

  /// 缓存最近的请求（按 key），用于 onError 时获取原始请求进行重试
  final Map<String, AdapterRequest> _requestCache = {};
  Completer<String>? _refreshCompleter;
  DateTime? _lastRefreshTime;

  TokenRefreshInterceptor({
    required this.tokenProvider,
    this.isUnauthorized,
    this.onRequestUpdated,
    this.onTokenRefreshed,
    this.onTokenRefreshing,
    this.onTokenRefreshFailed,
  });

  @override
  void onRequest(AdapterRequest request, RequestInterceptorHandler handler) {
    // 缓存请求，key 为 URL + Method，onError 时使用
    final key = _generateKey(request);
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
  void onError(AdapterException error, ErrorInterceptorHandler handler) {
    final shouldRefresh = isUnauthorized != null
        ? isUnauthorized!(error, error.response?.request ?? _emptyRequest)
        : error.statusCode == 401;

    if (!shouldRefresh) {
      handler.next(error);
      return;
    }

    _handleTokenRefresh(error, handler).catchError((e) {
      onTokenRefreshFailed?.call(e);
    });
  }

  Future<void> _handleTokenRefresh(
      AdapterException error, ErrorInterceptorHandler handler) async {
    try {
      final newToken = await _refreshToken();
      final originalRequest = error.response?.request ?? _emptyRequest;

      // 通过 onRequestUpdated 回调让调用方更新请求中的认证信息
      final updatedRequest = onRequestUpdated != null
          ? onRequestUpdated!(originalRequest, newToken)
          : originalRequest;

      // 清除缓存
      _requestCache.remove(_generateKey(originalRequest));

      // 解析错误，让上层知道 Token 已刷新
      handler.resolve(AdapterResponse(
        statusCode: 200,
        data: {
          '_tokenRefreshed': true,
          '_newToken': newToken,
          '_retryRequest': updatedRequest,
        },
        headers: {},
        request: originalRequest,
      ));
    } catch (e) {
      onTokenRefreshFailed?.call(e);
      handler.next(AdapterException(
        message: 'Token refresh failed: $e',
        type: AdapterExceptionType.unknown,
        originalError: e,
      ));
    }
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
