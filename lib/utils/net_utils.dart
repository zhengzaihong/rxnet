
import 'package:rxnet_plus/utils/text_util.dart';

import 'md5_util.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2025-08-12
/// create_time: 15:59
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
    // Normalize slashes after replacements
    // First, handle the scheme part if present to avoid mangling http:// to http:/
    int schemeEndIndex = resultUrl.indexOf("://");
    String scheme = "";
    String rest = resultUrl;

    if (schemeEndIndex != -1) {
      scheme = resultUrl.substring(0, schemeEndIndex + 3);
      rest = resultUrl.substring(schemeEndIndex + 3);
    }
    
    rest = rest.replaceAll(RegExp(r'/+'), '/');
    return scheme + rest;
  }

  //处理url，去掉多余的斜杠 (This specific normalizeUrl might be redundant if restfulUrl handles it)
  // static String normalizeUrl(String url) {
  //   // 只处理路径部分，保留协议和域名
  //   Uri uri = Uri.parse(url);
  //   String cleanedPath = uri.path.replaceAll(RegExp(r'/+'), '/');
  //   return '${uri.scheme}://${uri.host}$cleanedPath';
  // }

  static String getCacheKeyFromPath(String? path, Map<String, dynamic> params,List<String> ignoreKeys) {
    String cacheKey = "";
    if (!(TextUtil.isEmpty(path))) {
      cacheKey = cacheKey + MD5Util.generateMd5(path!);
    } else {
      throw Exception("请求地址不能为空！");
    }
    if (params.isNotEmpty) {
      final tempParams = Map<String,dynamic>.from(params);
      tempParams.removeWhere((key, value) => ignoreKeys.contains(key));
      String paramsStr = "";
      // Sort keys for consistent cache key generation
      List<String> sortedKeys = tempParams.keys.toList()..sort();
      for (var key in sortedKeys) {
        paramsStr = "$paramsStr$key${tempParams[key]}";
      }
      // tempParams.forEach((key, value) {
      //   paramsStr = "$paramsStr$key$value";
      // });
      if (paramsStr.isNotEmpty) {
         cacheKey = cacheKey + MD5Util.generateMd5(paramsStr);
      }
    }
    return cacheKey;
  }
}
