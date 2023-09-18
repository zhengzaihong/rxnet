import 'package:dio/dio.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';

import 'DatabaseUtil.dart';
import 'MD5Util.dart';
import 'TextUtil.dart';

class NetUtils {

  ///restful处理
  static String restfulUrl(String url, Map<String, dynamic> params) {
    StringBuffer buffer = StringBuffer(url);
    params.forEach((key, value) {
      buffer.write("/");
      buffer.write(key);
      buffer.write("/");
      buffer.write(value);
    });

    return buffer.toString().replaceAll("//", "/");
  }

  static String getCacheKeyFromPath(String path, Map<String, dynamic> params) {
    String cacheKey = "";
    if (!(TextUtil.isEmpty(path))) {
      cacheKey = cacheKey + MD5Util.generateMd5(path);
    } else {
      throw Exception("请求地址不能为空！");
    }
    if (params.isNotEmpty) {
      String paramsStr = "";
      params.forEach((key, value) {
        paramsStr = "$paramsStr$key$value";
      });
      cacheKey = cacheKey + MD5Util.generateMd5(paramsStr);
    }
    return cacheKey;
  }
}
