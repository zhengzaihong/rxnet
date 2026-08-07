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
    //在替换后规范化斜杠，避免将http://转换为http:/
    int schemeEndIndex = resultUrl.indexOf("://");
    String scheme = "";
    String rest = resultUrl;

    if (schemeEndIndex != -1) {
      scheme = resultUrl.substring(0, schemeEndIndex + 3);
      rest = resultUrl.substring(schemeEndIndex + 3);
    }
     //替换掉路径部分的所有多 //or///等等 到 /
    rest = rest.replaceAll(RegExp(r'/+'), '/');
    return scheme + rest;
  }

  /// 生成缓存键
  ///
  /// 使用 SHA-256 哈希生成固定长度的缓存键，避免键过长和碰撞风险。
  /// 格式：前16字符哈希值，保证唯一性的同时节省存储空间。
  static String getCacheKeyFromPath(String? path, Map<String, dynamic> params, List<String> ignoreKeys) {
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

    // 如果键长度小于 64，直接使用原始键（短键不需要哈希）
    if (rawKey.length <= 64) {
      return rawKey;
    }

    // 长键使用 SHA-256 哈希，取前 32 字符作为缓存键
    final bytes = utf8.encode(rawKey);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 32);
  }
}

