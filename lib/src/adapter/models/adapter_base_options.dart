import 'package:dio/dio.dart' show BaseOptions;

import '../../type/response_type.dart';
import 'adapter_request.dart';

///
/// adapter: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2026-08-05
/// describe: 适配器无关的全局请求默认配置
///
/// AdapterBaseOptions 是 RxNet 的平台无关全局配置类，用于替代 Dio 的 BaseOptions，
/// 确保切换适配器（DioAdapter / HttpAdapter / 自定义适配器）时，全局默认参数依然生效。
///
/// 每个适配器在接收到请求前，会将 AdapterBaseOptions 的字段映射为自身库的等效参数。
/// 例如：
/// - DioAdapter → Dio.BaseOptions
/// - HttpAdapter → http.Client 配置 + 请求级覆盖
///
/// ## 使用示例
///
/// ```dart
/// final config = RxNetConfig(
///   baseUrl: "https://api.example.com",
///   baseOptions: AdapterBaseOptions(
///     connectTimeout: Duration(seconds: 10),
///     receiveTimeout: Duration(seconds: 30),
///     sendTimeout: Duration(seconds: 30),
///     headers: {'X-App-Version': '2.0.0'},
///     contentType: 'application/json',
///     followRedirects: true,
///     maxRedirects: 5,
///   ),
/// );
///
/// await RxNet.init(config: config);
/// ```
///
/// ### 与 Dio BaseOptions 的映射关系
///
/// | AdapterBaseOptions      | Dio BaseOptions             | HttpAdapter 等效行为                  |
/// |-------------------------|-----------------------------|---------------------------------------|
/// | `connectTimeout`        | `connectTimeout`            | http.Client 无直接支持，通过超时拦截器实现 |
/// | `receiveTimeout`        | `receiveTimeout`            | 同上                                  |
/// | `sendTimeout`           | `sendTimeout`               | 同上                                  |
/// | `headers`               | `headers`                   | 合并到每个请求的 headers               |
/// | `contentType`           | `contentType`               | 设置默认 Content-Type                  |
/// | `responseType`          | `responseType`              | 解析响应体时的默认行为                  |
/// | `followRedirects`       | `followRedirects`           | http.Client 无直接支持，忽略           |
/// | `maxRedirects`          | `maxRedirects`              | 同上                                  |
/// | `validateStatus`        | `validateStatus`            | 所有适配器统一在 AdapterResponse 处理  |
/// | `receiveDataWhenStatusError` | 对应字段             | 通过 extra 传递                       |
///
class AdapterBaseOptions {
  /// 连接超时时间
  ///
  /// 如果在此时间内无法建立连接，将抛出 [AdapterExceptionType.connectTimeout] 错误。
  /// DioAdapter 直接映射到 `BaseOptions.connectTimeout`。
  /// HttpAdapter 通过超时拦截器或自定义 Client 实现。
  final Duration? connectTimeout;

  /// 接收超时时间
  ///
  /// 连接建立后，如果在此时间内未收到数据，将抛出 [AdapterExceptionType.receiveTimeout] 错误。
  final Duration? receiveTimeout;

  /// 发送超时时间
  ///
  /// 如果数据无法在此时间内发送完毕，将抛出 [AdapterExceptionType.sendTimeout] 错误。
  final Duration? sendTimeout;

  /// 默认请求头
  ///
  /// 这些 header 会合并到每个请求中（单个请求的 header 优先级更高）。
  /// 适用于设置全局认证 token、App 版本号等场景。
  final Map<String, dynamic> headers;

  /// 默认 Content-Type
  ///
  /// 常见值：
  /// - `'application/json'`（默认推荐）
  /// - `'application/x-www-form-urlencoded'`
  /// - `'multipart/form-data'`
  /// - `'text/plain'`
  final String? contentType;

  /// 默认响应类型
  ///
  /// 决定如何解析响应体。默认为 [ResponseType.json]。
  final ResponseType responseType;

  /// 是否跟随重定向
  ///
  /// 默认为 `true`。DioAdapter 直接映射，HttpAdapter 通过自定义 Client 实现。
  final bool followRedirects;

  /// 最大重定向次数
  ///
  /// 默认为 `5`。仅在 `followRedirects` 为 `true` 时有效。
  final int maxRedirects;

  /// 状态码验证回调
  ///
  /// 返回 `true` 表示该状态码被视为成功。默认行为是 2xx 视为成功。
  /// 所有适配器统一使用此回调判断状态码。
  ///
  /// 示例：允许 404 通过而不抛出异常：
  /// ```dart
  /// validateStatus: (statusCode) => statusCode < 500,
  /// ```
  final bool Function(int statusCode)? validateStatus;

  final bool persistentConnection;

  /// 非 2xx 状态码时是否仍然接收响应数据
  ///
  /// 默认为 `true`。设置为 `false` 时，错误响应的 body 将被丢弃。
  final bool receiveDataWhenStatusError;

  /// 额外的适配器特定配置
  ///
  /// 可用于传递各适配器特有的参数。适配器会尝试解析自己认识的 key，
  /// 未知的 key 将被忽略。
  ///
  /// 示例（DioAdapter 专用）：
  /// ```dart
  /// extra: {
  ///   'requestEncoder': myEncoder,
  ///   'responseDecoder': myDecoder,
  ///   'listFormat': ListFormat.multiCompatible,
  /// }
  /// ```
  final Map<String, dynamic> extra;

  const AdapterBaseOptions({
    this.connectTimeout,
    this.receiveTimeout,
    this.sendTimeout,
    this.headers = const {},
    this.contentType,
    this.responseType = ResponseType.json,
    this.followRedirects = true,
    this.maxRedirects = 5,
    this.validateStatus,
    this.receiveDataWhenStatusError = true,
    this.extra = const {},
    this.persistentConnection = true
  });

  /// 创建一个空的默认配置
  factory AdapterBaseOptions.empty() => const AdapterBaseOptions();

  /// 从 Dio 的 BaseOptions 创建适配器无关配置（向后兼容）
  ///
  /// 将 Dio 特定的 `BaseOptions` 提取为通用字段。
  /// Dio 独有的参数（如 `validateStatus`、`listFormat`）将被保留到 `extra` 中。
  factory AdapterBaseOptions.fromDioBaseOptions(BaseOptions dioBaseOptions) {
    return AdapterBaseOptions(
      connectTimeout: dioBaseOptions.connectTimeout,
      receiveTimeout: dioBaseOptions.receiveTimeout,
      sendTimeout: dioBaseOptions.sendTimeout,
      headers: Map<String, dynamic>.from(dioBaseOptions.headers),
      contentType: dioBaseOptions.contentType,
      responseType: _convertDioResponseType(dioBaseOptions.responseType),
      followRedirects: dioBaseOptions.followRedirects,
      maxRedirects: dioBaseOptions.maxRedirects,
      receiveDataWhenStatusError: dioBaseOptions.receiveDataWhenStatusError,
      persistentConnection: dioBaseOptions.persistentConnection,
      extra: {},
    );
  }

  static ResponseType _convertDioResponseType(dynamic dioResponseType) {
    final name = dioResponseType.toString().split('.').last;
    switch (name) {
      case 'plain':
        return ResponseType.plain;
      case 'bytes':
        return ResponseType.bytes;
      case 'stream':
        return ResponseType.stream;
      case 'json':
      default:
        return ResponseType.json;
    }
  }

  /// 复制并修改
  AdapterBaseOptions copyWith({
    Duration? connectTimeout,
    bool clearConnectTimeout = false,
    Duration? receiveTimeout,
    bool clearReceiveTimeout = false,
    Duration? sendTimeout,
    bool clearSendTimeout = false,
    Map<String, dynamic>? headers,
    String? contentType,
    bool clearContentType = false,
    ResponseType? responseType,
    bool? followRedirects,
    int? maxRedirects,
    bool Function(int statusCode)? validateStatus,
    bool clearValidateStatus = false,
    bool? receiveDataWhenStatusError,
    Map<String, dynamic>? extra,
  }) {
    return AdapterBaseOptions(
      connectTimeout: clearConnectTimeout ? null : (connectTimeout ?? this.connectTimeout),
      receiveTimeout: clearReceiveTimeout ? null : (receiveTimeout ?? this.receiveTimeout),
      sendTimeout: clearSendTimeout ? null : (sendTimeout ?? this.sendTimeout),
      headers: headers ?? this.headers,
      contentType: clearContentType ? null : (contentType ?? this.contentType),
      responseType: responseType ?? this.responseType,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
      validateStatus: clearValidateStatus ? null : (validateStatus ?? this.validateStatus),
      receiveDataWhenStatusError: receiveDataWhenStatusError ?? this.receiveDataWhenStatusError,
      extra: extra ?? this.extra,
    );
  }

  /// 合并两个配置，[other] 的非 null 字段覆盖当前配置
  AdapterBaseOptions merge(AdapterBaseOptions? other) {
    if (other == null) return this;
    return copyWith(
      connectTimeout: other.connectTimeout,
      clearConnectTimeout: other.connectTimeout == null && connectTimeout != null,
      receiveTimeout: other.receiveTimeout,
      clearReceiveTimeout: other.receiveTimeout == null && receiveTimeout != null,
      sendTimeout: other.sendTimeout,
      clearSendTimeout: other.sendTimeout == null && sendTimeout != null,
      headers: {...headers, ...other.headers},
      contentType: other.contentType,
      clearContentType: other.contentType == null && contentType != null,
      responseType: other.responseType,
      followRedirects: other.followRedirects,
      maxRedirects: other.maxRedirects,
      validateStatus: other.validateStatus,
      clearValidateStatus: other.validateStatus == null && validateStatus != null,
      receiveDataWhenStatusError: other.receiveDataWhenStatusError,
      extra: {...extra, ...other.extra},
    );
  }

  /// 将此配置应用到 AdapterRequest 上（填充默认值）
  ///
  /// 请求级参数优先级高于全局默认值，因此只有请求中未设置的字段才会被填充。
  AdapterRequest applyToRequest(AdapterRequest request) {
    return request.copyWith(
      connectTimeout: request.connectTimeout ?? connectTimeout,
      receiveTimeout: request.receiveTimeout ?? receiveTimeout,
      sendTimeout: request.sendTimeout ?? sendTimeout,
      headers: _mergeHeaders(headers, request.headers),
      contentType: request.contentType ?? contentType,
      responseType: request.responseType != ResponseType.json
          ? request.responseType
          : responseType,
    );
  }

  /// 合并 header（全局 + 请求级）
  static Map<String, dynamic> _mergeHeaders(
    Map<String, dynamic> base,
    Map<String, dynamic> request,
  ) {
    if (base.isEmpty) return request;
    if (request.isEmpty) return base;
    return {...base, ...request};
  }

  @override
  String toString() {
    return 'AdapterBaseOptions('
        'connectTimeout: $connectTimeout, '
        'receiveTimeout: $receiveTimeout, '
        'sendTimeout: $sendTimeout, '
        'contentType: $contentType, '
        'responseType: $responseType, '
        'followRedirects: $followRedirects, '
        'maxRedirects: $maxRedirects, '
        'headers: $headers'
        ')';
  }
}
