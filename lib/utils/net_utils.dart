import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:rxnet_plus/utils/text_util.dart';

///
/// author: ZhengZaiHong
/// email:1096877329@qq.com
/// date: 2025-08-12
/// time: 15:59
/// describe: restful Url处理
///
class NetUtils {
  NetUtils._();

  // restful处理 - Retrofit style
  static String restfulUrl(String url, Map<String, dynamic> params) {
    String resultUrl = url;
    List<String> keysToRemove = [];

    params.forEach((key, value) {
      String placeholder = "{$key}";
      if (resultUrl.contains(placeholder)) {
        resultUrl = resultUrl.replaceAll(placeholder, Uri.encodeComponent(value.toString()));
        keysToRemove.add(key);
      }
    });

    // 从 params Map 中移除已用于路径替换的键
    for (String key in keysToRemove) {
      params.remove(key);
    }
    //在替换后规范化 path 斜杠，避免将 http:// 转换为 http:/
    //只处理 path，保留 query / fragment 中的 //。
    int schemeEndIndex = resultUrl.indexOf("://");
    String scheme = "";
    String rest = resultUrl;

    if (schemeEndIndex != -1) {
      scheme = resultUrl.substring(0, schemeEndIndex + 3);
      rest = resultUrl.substring(schemeEndIndex + 3);
    }

    final fragmentIndex = rest.indexOf('#');
    final fragment =
        fragmentIndex == -1 ? '' : rest.substring(fragmentIndex);
    final withoutFragment =
        fragmentIndex == -1 ? rest : rest.substring(0, fragmentIndex);

    final queryIndex = withoutFragment.indexOf('?');
    final query =
        queryIndex == -1 ? '' : withoutFragment.substring(queryIndex);
    final path =
        queryIndex == -1 ? withoutFragment : withoutFragment.substring(0, queryIndex);

    final normalizedPath = path.replaceAll(RegExp(r'/+'), '/');
    return scheme + normalizedPath + query + fragment;
  }

  /// 生成缓存键
  ///
  /// 默认统一使用 SHA-256 哈希生成固定长度缓存键（取前 32 个十六进制字符，
/// 128 bit），避免 token / PII 等参数以明文形式写入本地数据库。
  ///
  /// [hashKey] 仅用于测试或特殊调试场景；生产环境应保持默认 true。
  static String getCacheKeyFromPath(
    String? path,
    Map<String, dynamic> params,
    List<String> ignoreKeys, {
    bool hashKey = true,
  }) {
    if (TextUtil.isEmpty(path)) {
      throw Exception("请求地址不能为空！");
    }

    final buffer = StringBuffer(path!);

    if (params.isNotEmpty) {
      final tempParams = Map<String, dynamic>.from(params);
      tempParams.removeWhere((key, value) => ignoreKeys.contains(key));

      if (tempParams.isNotEmpty) {
        buffer.write('?');
        final sortedKeys = tempParams.keys.toList()..sort();
        for (var i = 0; i < sortedKeys.length; i++) {
          if (i > 0) buffer.write('&');
          final key = sortedKeys[i];
          buffer.write(key);
          buffer.write('=');
          buffer.write(tempParams[key]);
        }
      }
    }

    final rawKey = buffer.toString();

    if (!hashKey) {
      return rawKey;
    }

    final bytes = utf8.encode(rawKey);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32);
  }
}

