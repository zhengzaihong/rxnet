import 'package:dio/dio.dart';

import 'DatabaseUtil.dart';
import 'MD5Util.dart';
import 'TextUtil.dart';

class NetUtils {
  /*
   * 获取get网络请求
   */
  static Future<Response<T>> getNet<T>(
      String path, Map<String, String> params) async {
    Dio dio = new Dio();
    print("地址："+path);
    print("参数："+fromMap2ParamsString(params));
    return await dio.get<T>(path + fromMap2ParamsString(params));
  }


  /*
   * 获取post网络请求
   */
  static Future<Response<T>> postNet<T>(
      String path, Map<String, String> params) async {
    Dio dio = new Dio();
    print("地址："+path);
    print("参数："+fromMap2ParamsString(params));
    return await dio.post<T>(path,queryParameters:params);
  }

  /*
   * 获取get缓存请求
   */
  static Future<List<Map<String,dynamic>>> getCache(String path, Map<String, String> params) async {
    return DatabaseUtil.queryHttp(
        DatabaseUtil.database, getCacheKeyFromPath(path, params));
  }

  /*
   * 拼接get参数
   */
  static String fromMap2ParamsString(Map<String, String> params) {
    if (params == null || params.length <= 0) {
      return "";
    }
    String paramsStr = "?";
    params.forEach((key, value) {
      paramsStr = paramsStr + key + "=" + value + "&";
    });
    return paramsStr;
  }

  /*
   * 生成Dio对象，确定是否需要缓存
   */
  static Dio createDio(String path, Map<String, String> params,
      Function(Object, bool) stringCallback, bool useCache) {
    Dio dio = new Dio();

    //需要缓存时，生成cacheKey
    if (useCache) {
      dio.interceptors.add(createInterceptor(
          getCacheKeyFromPath(path, params), dio, stringCallback));
    }
    return dio;
  }

  /*
   * 生成缓存拦截器
   */
  static InterceptorsWrapper createInterceptor(
      String cacheKey, Dio dio, Function(Object, bool) stringCallback) {
    InterceptorsWrapper interceptor =
        InterceptorsWrapper(onRequest: (RequestOptions options) async {
      DatabaseUtil.queryHttp(DatabaseUtil.database, cacheKey).then((cacheList) {
        if (cacheList.length > 0 &&
            !TextUtil.isEmpty(cacheList[0].toString())) {
          //返回数据库内容
          stringCallback(cacheList[0]["value"].toString(), true);
        }
      });
      return options;
    }, onResponse: (Response response) {
      return response;
    }, onError: (DioError e) {
      return e;
    });
    return interceptor;
  }

  static String getCacheKeyFromPath(String path, Map<String, String> params) {
    String cacheKey = "";
    if (!(TextUtil.isEmpty(path))) {
      cacheKey = cacheKey + MD5Util.generateMd5(path);
    } else {
      throw new Exception("请求地址不能为空！");
    }
    if (params != null && params.length > 0) {
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
      if (list != null && list.length > 0) {
        //更新数据库数据
        DatabaseUtil.updateHttp(DatabaseUtil.database, cacheKey, value);
      } else {
        //插入数据库数据
        DatabaseUtil.insertHttp(DatabaseUtil.database, cacheKey, value);
      }
    });
  }
}
