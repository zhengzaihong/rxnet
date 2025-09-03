import 'package:rxnet_plus/net/type/sources_type.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2023/9/14
/// create_time: 16:21
/// describe:  响应结果包装类
///
class RxResult<T> {
  T? value;
  final Object? error;
  SourcesType model;

  RxResult._({this.value, this.error, this.model = SourcesType.net});

  factory RxResult({T? value, SourcesType model = SourcesType.net}) {
    return RxResult._(value: value, model: model);
  }

  factory RxResult.error(Object error) {
    return RxResult._(error: error);
  }

  bool get isSuccess => error == null;
}
