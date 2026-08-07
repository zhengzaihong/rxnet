import '../type/sources_type.dart';

///json转实体回调
typedef JsonTransformation<E> = E Function(Map<String, dynamic> data);

///http请求成功回调
typedef Success<T> = void Function(T data, SourcesType model);

///失败回调
typedef Failure<T> = void Function(dynamic data);

/// 成功或失败都会执行的方法
typedef Completed<T> = void Function();

/// 缓存失效超时回调
typedef CacheInvalidationCallback<T> = void Function();

typedef ParamCallback = void Function(Map<String, dynamic> params);

///检查网络的方法 是否有网络
typedef CheckNetWork = Future<bool> Function();
