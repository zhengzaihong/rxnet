

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
  int? code;
  String? msg;

  BaseBean({this.data, this.code, this.msg});

  //借助 FlutterJsonBeanFactory 动态解析,或其他自动生成的工具
  // BaseBean.fromJson(Map<String, dynamic> json) {
  //   data = JsonConvert.fromJsonAsT(json["data"]);
  //   code = json['code'];
  //   msg = json['msg'];
  // }

  //不使用插件也好处理 如下：
  factory BaseBean.fromJson(
      Map<String, dynamic> json,
      T Function(Map<String, dynamic>) fromJsonT) {
    return BaseBean(
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      code: json['code'],
      msg: json['msg'],
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = <String, dynamic>{};
    map['data'] = data;
    map['code'] = code;
    map['msg'] = msg;
    return map;
  }
}
