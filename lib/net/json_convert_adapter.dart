import 'package:rxnet/net/fun/fun_apply.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2022/8/8
/// create_time: 11:01
/// describe: json 转数据模型的 适配器
///
class JsonConvertAdapter<T>{

  JsonTransformation<T> jsonTransformation;

  JsonConvertAdapter(this.jsonTransformation);

}