import 'package:rxnet_example/json/base/json_convert_content.dart';


///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2021/6/9
/// create_time: 15:57
/// describe: 封装请求返回格式统一基类bean
/// 此字段需结合后端修改
///
class BaseBean<T> {

  T? data;
  int? status;
  String? message;

   BaseBean.fromJson(Map<String, dynamic> json) {
     data= JsonConvert.fromJsonAsT(json['data']);
     status = json['status'];
     message = json['message'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = <String, dynamic>{};
    map['data'] = data;
    map['status'] = status;
    map['message'] = message;
    return map;
  }
}
