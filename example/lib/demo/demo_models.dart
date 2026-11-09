import 'dart:convert';

import 'package:rxnet_plus/rxnet_lib.dart';

/// 示例页面统一的结果模型
class DemoResult {
  final bool success;
  final String body;
  final int? statusCode;
  final String? statusMessage;
  final Map<String, List<String>> headers;
  final SourcesType source;
  final Duration elapsed;
  final Object? error;

  const DemoResult({
    required this.success,
    required this.body,
    this.statusCode,
    this.statusMessage,
    this.headers = const {},
    this.source = SourcesType.net,
    required this.elapsed,
    this.error,
  });

  factory DemoResult.from({
    required RxResult<dynamic> result,
    required AdapterResponse? response,
    required Duration elapsed,
  }) {
    final payload = result.isSuccess ? result.value : result.error;
    return DemoResult(
      success: result.isSuccess,
      body: prettyJson(payload),
      statusCode: response?.statusCode,
      statusMessage: response?.statusMessage,
      headers: response?.headers ?? const {},
      source: result.model,
      elapsed: elapsed,
      error: result.error,
    );
  }

  factory DemoResult.failure(Object error, {Duration? elapsed}) {
    return DemoResult(
      success: false,
      body: error.toString(),
      elapsed: elapsed ?? Duration.zero,
      error: error,
    );
  }
}

/// 格式化 JSON/响应数据，限制最大展示长度
String prettyJson(dynamic value, {int maxLength = 24000}) {
  if (value == null) return 'null';

  dynamic normalized = value;
  if (value is String) {
    final text = value.trim();
    if ((text.startsWith('{') && text.endsWith('}')) ||
        (text.startsWith('[') && text.endsWith(']'))) {
      try {
        normalized = jsonDecode(text);
      } catch (_) {
        normalized = value;
      }
    }
  }

  String result;
  try {
    result = const JsonEncoder.withIndent('  ').convert(normalized);
  } catch (_) {
    result = normalized.toString();
  }

  if (result.length > maxLength) {
    return '${result.substring(0, maxLength)}\n\n... (已截断)';
  }
  return result;
}

/// 各方法默认请求路径
String samplePathFor(HttpMethod method) {
  return switch (method) {
    HttpMethod.GET || HttpMethod.POST => '/posts',
    HttpMethod.PUT ||
    HttpMethod.PATCH ||
    HttpMethod.DELETE ||
    HttpMethod.HEAD ||
    HttpMethod.OPTIONS =>
      '/posts/1',
  };
}

/// 各方法默认 body（仅 POST/PUT/PATCH）
Map<String, dynamic>? sampleBodyFor(HttpMethod method) {
  return switch (method) {
    HttpMethod.POST ||
    HttpMethod.PUT ||
    HttpMethod.PATCH =>
      const {
        'title': 'RxNet Playground',
        'body': 'Created from the RxNet example app',
        'userId': 1,
      },
    _ => null,
  };
}

/// GET 默认查询参数
Map<String, dynamic> sampleQueryFor(HttpMethod method) {
  return method == HttpMethod.GET ? const {'userId': 1} : const {};
}

BuildRequest<dynamic> _requestFor(HttpMethod method) {
  return switch (method) {
    HttpMethod.GET => RxNet.get(),
    HttpMethod.POST => RxNet.post(),
    HttpMethod.PUT => RxNet.put(),
    HttpMethod.PATCH => RxNet.patch(),
    HttpMethod.DELETE => RxNet.delete(),
    HttpMethod.HEAD => RxNet.head(),
    HttpMethod.OPTIONS => RxNet.options(),
  };
}

/// 执行一个标准方法示例
Future<DemoResult> runSampleRequest(
  HttpMethod method, {
  String? path,
  Map<String, dynamic>? query,
  Map<String, dynamic>? body,
  Map<String, String>? headers,
  CacheMode cacheMode = CacheMode.ONLY_REQUEST,
}) async {
  final stopwatch = Stopwatch()..start();
  AdapterResponse? captured;

  try {
    final request = _requestFor(method);
    request.setPath(path ?? samplePathFor(method));

    final effectiveQuery = query ?? sampleQueryFor(method);
    if (effectiveQuery.isNotEmpty) {
      request.setQueryParams(effectiveQuery);
    }

    headers?.forEach(request.setHeader);

    final effectiveBody = body ?? sampleBodyFor(method);
    if (effectiveBody != null) {
      request.setBodyParams(effectiveBody).asJson();
    }

    request
        .setCacheMode(cacheMode)
        .setConnectTimeout(const Duration(seconds: 10))
        .setReceiveTimeout(const Duration(seconds: 20))
        .setResponseCallBack((response) => captured = response);

    final result = await request.request();
    stopwatch.stop();
    return DemoResult.from(
      result: result,
      response: captured,
      elapsed: stopwatch.elapsed,
    );
  } catch (error) {
    stopwatch.stop();
    return DemoResult.failure(error, elapsed: stopwatch.elapsed);
  }
}

/// 缓存优先示例：第一次网络，第二次通常命中缓存
Future<DemoResult> runCacheSample() async {
  final stopwatch = Stopwatch()..start();
  AdapterResponse? captured;

  try {
    final result = await RxNet.get()
        .setPath('/posts/1')
        .setCacheMode(CacheMode.CACHE_EMPTY_OR_EXPIRED_THEN_REQUEST)
        .setConnectTimeout(const Duration(seconds: 10))
        .setResponseCallBack((response) => captured = response)
        .request();
    stopwatch.stop();
    return DemoResult.from(
      result: result,
      response: captured,
      elapsed: stopwatch.elapsed,
    );
  } catch (error) {
    stopwatch.stop();
    return DemoResult.failure(error, elapsed: stopwatch.elapsed);
  }
}

/// 并发请求示例
Future<DemoResult> runConcurrentSample() async {
  final stopwatch = Stopwatch()..start();

  try {
    final results = await Future.wait([
      RxNet.get().setPath('/posts/1').request(),
      RxNet.get().setPath('/posts/2').request(),
      RxNet.get().setPath('/posts/3').request(),
    ]);
    stopwatch.stop();

    final payload = <String, dynamic>{
      for (var i = 0; i < results.length; i++)
        'request${i + 1}': results[i].isSuccess
            ? results[i].value
            : results[i].error.toString(),
    };

    return DemoResult(
      success: results.every((result) => result.isSuccess),
      body: prettyJson(payload),
      headers: const {},
      source: SourcesType.net,
      elapsed: stopwatch.elapsed,
    );
  } catch (error) {
    stopwatch.stop();
    return DemoResult.failure(error, elapsed: stopwatch.elapsed);
  }
}

/// Multipart（内存字节）示例，Web/IO 均可用
Future<DemoResult> runMultipartSample() async {
  final stopwatch = Stopwatch()..start();
  AdapterResponse? captured;

  try {
    final file = MultipartFile.fromBytes(
      utf8.encode('Hello RxNet from bytes'),
      filename: 'demo.txt',
    );

    final request = RxNet.post()
        .setPath('/posts')
        .setBodyParams(const {
          'title': 'Multipart from RxNet',
          'body': 'A file was uploaded from memory bytes',
          'userId': 1,
        })
        .setBodyParam('file', file)
        .asFormData()
        .setConnectTimeout(const Duration(seconds: 10))
        .setResponseCallBack((response) => captured = response);

    final result = await request.request();
    stopwatch.stop();
    return DemoResult.from(
      result: result,
      response: captured,
      elapsed: stopwatch.elapsed,
    );
  } catch (error) {
    stopwatch.stop();
    return DemoResult.failure(error, elapsed: stopwatch.elapsed);
  }
}