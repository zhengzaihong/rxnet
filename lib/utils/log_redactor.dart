import 'dart:convert';

/// 日志脱敏工具。
///
/// 默认对 Authorization、Cookie、Token、密码等敏感字段进行掩码，
/// 避免日志和调试面板直接暴露凭据。
class LogRedactor {
  LogRedactor._();

  /// 脱敏后的占位符
  static const String mask = '***';

  static const Set<String> _sensitiveKeys = <String>{
    'authorization',
    'proxyauthorization',
    'cookie',
    'setcookie',
    'password',
    'passwd',
    'pwd',
    'token',
    'accesstoken',
    'refreshtoken',
    'idtoken',
    'secret',
    'clientsecret',
    'apikey',
    'xapikey',
    'session',
    'sessionid',
    'signature',
    'sign',
    'credential',
    'credentials',
    'auth',
    // 常见 PII 字段
    'email',
    'mail',
    'phone',
    'mobile',
    'telephone',
    'tel',
    'idcard',
    'idnumber',
    'passport',
    'bankcard',
    'cardnumber',
    '邮箱',
    '手机号',
    '身份证',
  };

  static String _normalize(String key) =>
      key.toLowerCase().replaceAll(RegExp(r'[-_\s]'), '');

  /// 判断字段名是否为敏感字段（大小写、下划线、短横线不敏感）
  static bool isSensitiveKey(String key) {
    final normalized = _normalize(key);
    if (_sensitiveKeys.contains(normalized)) {
      return true;
    }
    return normalized.endsWith('token') ||
        normalized.endsWith('secret') ||
        normalized.endsWith('password') ||
        normalized.endsWith('apikey') ||
        normalized.endsWith('credential') ||
        normalized.endsWith('auth') ||
        normalized.endsWith('email') ||
        normalized.endsWith('phone') ||
        normalized.endsWith('phonenumber') ||
        normalized.endsWith('mobile') ||
        normalized.endsWith('mobilenumber') ||
        normalized.endsWith('idcard') ||
        normalized.endsWith('idnumber');
  }

  /// 对请求/响应头脱敏
  static Map<String, dynamic> redactHeaders(Map<String, dynamic> headers) {
    return headers.map(
      (key, value) => MapEntry(
        key,
        isSensitiveKey(key) ? mask : value,
      ),
    );
  }

  /// 递归对 Map/List 中的敏感字段脱敏
  static dynamic redactData(dynamic data, [int depth = 0]) {
    if (depth > 8) {
      return '[MaxDepth]';
    }

    if (data is Map) {
      final result = <String, dynamic>{};
      data.forEach((key, value) {
        final keyString = key.toString();
        result[keyString] =
            isSensitiveKey(keyString) ? mask : redactData(value, depth + 1);
      });
      return result;
    }

    if (data is Iterable) {
      return data.map((value) => redactData(value, depth + 1)).toList();
    }

    return data;
  }

  /// 对 `a=1&token=abc` 这类 query/form 文本做敏感参数脱敏
  static String redactKeyValueText(String text) {
    final parts = text.split('&');
    var changed = false;
    final output = parts.map((part) {
      final separator = part.indexOf('=');
      if (separator <= 0) {
        return part;
      }
      var key = part.substring(0, separator);
      try {
        key = Uri.decodeComponent(key);
      } catch (_) {
        // 保持原始 key
      }
      if (!isSensitiveKey(key)) {
        return part;
      }
      changed = true;
      return '${part.substring(0, separator + 1)}$mask';
    }).join('&');

    return changed ? output : text;
  }

  /// 对 URL 的 query 部分脱敏，保留 path 便于定位问题
  static String redactUrl(String url) {
    final fragmentIndex = url.indexOf('#');
    final fragment =
        fragmentIndex == -1 ? '' : url.substring(fragmentIndex);
    final withoutFragment =
        fragmentIndex == -1 ? url : url.substring(0, fragmentIndex);

    final queryIndex = withoutFragment.indexOf('?');
    if (queryIndex == -1) {
      return url;
    }

    final base = withoutFragment.substring(0, queryIndex);
    final query = withoutFragment.substring(queryIndex + 1);
    return '$base?${redactKeyValueText(query)}$fragment';
  }

  /// 如果字符串是 JSON，则解析后脱敏；否则按 query/form 规则脱敏
  static dynamic redactJsonString(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('{') && !trimmed.startsWith('[')) {
      return redactKeyValueText(text);
    }
    try {
      return redactData(jsonDecode(trimmed));
    } catch (_) {
      return redactKeyValueText(text);
    }
  }

  /// 生成可安全打印的 JSON/文本
  static String toSafeJson(dynamic data) {
    final safe = data is String ? redactJsonString(data) : redactData(data);
    if (safe is String) {
      return safe;
    }
    try {
      return jsonEncode(safe);
    } catch (_) {
      return safe.toString();
    }
  }
}