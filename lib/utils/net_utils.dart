
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

  // restful处理
  static String restfulUrl(String url, Map<String, dynamic> params) {
    StringBuffer buffer = StringBuffer(url);
    params.forEach((key, value) {
      buffer.write("/");
      buffer.write(key);
      buffer.write("/");
      buffer.write(value);
    });
    return buffer.toString().replaceAll(RegExp(r'/+'), '/');
    // return normalizeUrl(buffer.toString());
  }

  //处理url，去掉多余的斜杠
  static String normalizeUrl(String url) {
    // 只处理路径部分，保留协议和域名
    Uri uri = Uri.parse(url);
    String cleanedPath = uri.path.replaceAll(RegExp(r'/+'), '/');
    return '${uri.scheme}://${uri.host}$cleanedPath';
  }

  static String getCacheKeyFromPath(String? path, Map<String, dynamic> params,List<String> ignoreKeys) {
    String cacheKey = "";
    if (!(TextUtil.isEmpty(path))) {
      cacheKey = cacheKey + MD5Util.generateMd5(path!);
    } else {
      throw Exception("请求地址不能为空！");
    }
    if (params.isNotEmpty) {
      final tempParams = Map.from(params);
      tempParams.removeWhere((key, value) => ignoreKeys.contains(key));
      String paramsStr = "";
      tempParams.forEach((key, value) {
        paramsStr = "$paramsStr$key$value";
      });
      cacheKey = cacheKey + MD5Util.generateMd5(paramsStr);
    }
    return cacheKey;
  }
}
