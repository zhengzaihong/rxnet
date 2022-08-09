

typedef JsonTransformation<T> = T? Function(Map<String,dynamic> data);

///http请求成功回调
typedef HttpSuccessCallback<Dynamic,SourcesType> = void Function(dynamic data,SourcesType model);

///失败回调
typedef HttpFailureCallback = void Function(dynamic data);


typedef ParamCallBack = void Function(Map<String, dynamic> params);