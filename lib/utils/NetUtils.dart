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

