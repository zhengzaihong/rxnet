class BaseInfo<T> {

  T? data;
  int? status;
  String? message;

  BaseInfo({this.data, this.status, this.message});


  //不使用插件也好处理 如下：
  factory BaseInfo.fromJson(
      Map<String, dynamic> json,
      T Function(Map<String, dynamic>) fromJsonT) {
    return BaseInfo(
      data: json['data'] != null ? fromJsonT(json['data']) : null,
      status: json['status'] as int,
      message: json['message'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> map = <String, dynamic>{};
    map['data'] = data;
    map['status'] = status;
    map['message'] = message;
    return map;
  }
}
