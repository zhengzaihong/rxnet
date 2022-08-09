import 'package:dio/dio.dart';

import 'DatabaseUtil.dart';
import 'MD5Util.dart';
import 'TextUtil.dart';

class NetUtils {


  ///获取get缓存请求
  static Future<List<Map<String,dynamic>>> getCache(String path, Map<String, dynamic> params) async {
    return DatabaseUtil.queryHttp(
        DatabaseUtil.database, getCacheKeyFromPath(path, params));
  }

  /// 拼接get参数
  static String fromMap2ParamsString(Map<String, dynamic> params) {
    if (params.isEmpty) {
      return "";
    }
    String paramsStr = "?";
    params.forEach((key, value) {
      paramsStr = "${"$key=$value"}&";
    });
    return paramsStr;
  }


  ///restful处理
  static String restfulUrl(String url, Map<String, dynamic> params) {
    // restful 请求处理
    // /gysw/search/hist/:user_id        user_id=27
    // 最终生成 url 为
    // /gysw/search/hist/27
    params.forEach((key, value) {
      if (url.contains(key)) {
        url = url.replaceAll(':$key', value.toString());
      }
    });
    return url;
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
        paramsStr = paramsStr + key + value;
      });
      cacheKey = cacheKey + MD5Util.generateMd5(paramsStr);
    }
    return cacheKey;
  }

  static void saveCache(String cacheKey, String value) {
    DatabaseUtil.queryHttp(DatabaseUtil.database, cacheKey).then((list) {
      if (list.isNotEmpty) {
        //更新数据库数据
        DatabaseUtil.updateHttp(DatabaseUtil.database, cacheKey, value);
      } else {
        //插入数据库数据
        DatabaseUtil.insertHttp(DatabaseUtil.database, cacheKey, value);
      }
    });
  }
}

