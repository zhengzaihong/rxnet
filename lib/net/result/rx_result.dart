import 'package:flutter_rxnet_forzzh/net/type/sources_type.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2023/9/14
/// create_time: 16:21
/// describe: await 响应结果包装类
///
class RxResult<T> {
  T? value;
  SourcesType model;

  RxResult({this.value, this.model = SourcesType.net});
}
