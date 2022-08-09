import 'dart:collection';
import 'dart:core';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:rxnet/net/cache_mode.dart';
import 'package:rxnet/net/fun/fun_apply.dart';
import 'package:rxnet/net/json_convert_adapter.dart';
import 'package:rxnet/net/type/http_type.dart';
import 'package:rxnet/net/type/sources_type.dart';
import 'package:rxnet/utils/DatabaseUtil.dart';
import 'package:rxnet/utils/HttpError.dart';
import 'package:rxnet/utils/LogUtil.dart';
import 'package:rxnet/utils/NetUtils.dart';
import 'package:rxnet/utils/TextUtil.dart';


///同一个CancelToken可以用于多个请求，当一个CancelToken取消时，所有使用该CancelToken的请求都会被取消，一个页面对应一个CancelToken。
final Map<String, CancelToken> _cancelTokens = <String, CancelToken>{};

class RxNet {

  Dio? _client;

  static final RxNet _instance = RxNet._internal();

  factory RxNet() => _instance;

  Dio? get client => _client;

  /// 创建 dio 实例对象
  RxNet._internal() {
    var options = BaseOptions(
        // connectTimeout: connectTimeout,
        // receiveTimeout: receiveTimeout,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json);

    _client ??= Dio(options);
  }

  ///初始化公共属性
  /// [baseUrl] 地址前缀
  /// [interceptors] 基础拦截器
  RxNet init({
    required String baseUrl,
    String dbName = "dataMapper",
    List<Interceptor>? interceptors,
    BaseOptions? options,
  }) {
    /// 全局属性：请求前缀、连接超时时间、响应超时时间

    if (options != null) {
      _client?.options = options;
    }

    _client?.options.baseUrl = baseUrl;

    if (interceptors != null) {
      _client?.interceptors.addAll(interceptors);
    }

    try {
      if (Platform.isAndroid || Platform.isIOS) {
        DatabaseUtil.initDatabase(dbName);
      }
    } catch (e) {
      LogUtil.v("环境：web");
    }

    return this;
  }

  static BuildRequest get() {
    return BuildRequest(
      HttpType.get,
      RxNet(),
    );
  }
  static BuildRequest post() {
    return BuildRequest(
      HttpType.post,
      RxNet(),
    );
  }

  static BuildRequest delete() {
    return BuildRequest(
      HttpType.delete,
      RxNet(),
    );
  }

  static BuildRequest put() {
    return BuildRequest(
      HttpType.put,
      RxNet(),
    );
  }

  static BuildRequest patch() {
    return BuildRequest(
      HttpType.patch,
      RxNet(),
    );
  }

  ///取消网络请求
  void cancel(String tag) {
    if (_cancelTokens.containsKey(tag)) {
      if (!_cancelTokens[tag]!.isCancelled) {
        _cancelTokens[tag]?.cancel();
      }
      _cancelTokens.remove(tag);
    }
  }
}



class BuildRequest {

  final HttpType httpType;

  late String? _baseUrl;

  final RxNet _rxNet;

  String? _cancleTag;

  String? _path;

  CacheMode _cacheMode = CacheMode.noCache;

  Map<String, dynamic> _params = HashMap();

  Map<String, dynamic> _headers = HashMap();

  Map<String, dynamic> _bodyData = HashMap();

  bool _useJsonAdapter = true;

  JsonConvertAdapter? _jsonConvertAdapter;

  Options? _options;

  bool _enableRestfulUrl = false;

  BuildRequest(this.httpType, this._rxNet) {
    _baseUrl = _rxNet.client?.options?.baseUrl;
  }

  BuildRequest setUseJsonAdapter(bool use) {
    _useJsonAdapter = use;
    return this;
  }

  BuildRequest setJsonConvertAdapter(JsonConvertAdapter adapter) {
    _jsonConvertAdapter = adapter;
    return this;
  }

  JsonConvertAdapter? getJsonConvertAdapter() {
    return _jsonConvertAdapter;
  }

  BuildRequest setEnableRestfulUrl(bool restful) {
    _enableRestfulUrl = restful;
    return this;
  }

  bool getEnableRestfulUrl() {
    return _enableRestfulUrl;
  }

  BuildRequest setPath(String path) {
    if (TextUtil.isEmpty(path)) {
      throw Exception("请求路径不能为空 path:$_path");
    }
    _path = path;
    return this;
  }

  BuildRequest setBodyData(Map<String, dynamic> param) {
    _bodyData = param;
    return this;
  }

  BuildRequest setParam(String key, dynamic value) {
    _params[key] = value;
    return this;
  }

  BuildRequest setNewParams(Map<String, dynamic> param) {
    _params = param;
    return this;
  }

  BuildRequest addParams(Map<String, dynamic> param) {
    _params.addAll(param);
    return this;
  }

  BuildRequest getParams(ParamCallBack callBack) {
    callBack.call(_params);
    return this;
  }

  BuildRequest setHeaders(Map<String, dynamic> headers) {
    _headers = headers;
    return this;
  }

  BuildRequest setHeader(String key, dynamic value) {
    _headers[key] = value;
    return this;
  }

  BuildRequest setTag(String tag) {
    _cancleTag = tag;
    _cancelTokens[tag] = CancelToken();
    return this;
  }

  String? getTag() {
    return _cancleTag;
  }

  BuildRequest covertParamToBody() {
    _bodyData.addAll(_params);
    _params.clear();
    return this;
  }

  BuildRequest setCacheMode(CacheMode cacheMode) {
    _cacheMode = cacheMode;
    return this;
  }

  BuildRequest setOptions(Options options) {
    _options = options;
    return this;
  }

  void _doWorkRequest({
    HttpSuccessCallback? success,
    HttpFailureCallback? failure,
    bool cache = false,
    Function? readCache,
  }) async {

    ///检查网络是否连接
    ConnectivityResult connectivityResult =
        await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      if (failure != null) {
        failure(HttpError(HttpError.NETWORK_ERROR, "网络异常，请稍后重试！"));
      }
      LogUtil.v("请求网络异常，请稍后重试！");
      return;
    }

    String url = _path.toString();
    if (getEnableRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = httpType.name;
      Response<Map<String, dynamic>> response = await _rxNet.client!.request(
          url,
          data: _bodyData,
          queryParameters: _params,
          options: _options,
          cancelToken: _cancelTokens[getTag()]);

      ///成功
      if (response.statusCode == 200) {
        if (_useJsonAdapter && getJsonConvertAdapter() != null) {
          LogUtil.v("useJsonAdapter：true");
          var data =
              getJsonConvertAdapter()?.jsonTransformation.call(response.data!);
          success?.call(data, SourcesType.net);
        } else {
          LogUtil.v("useJsonAdapter：false");
          success?.call(response.data, SourcesType.net);
        }

        /// 数据库目前只支持 android 和 ios
        try {
          if (cache && (Platform.isIOS || Platform.isAndroid)) {
            /// 存储数据

          }
        } catch (e) {
          LogUtil.v("catch环境：web");
        }
      } else {
        if (readCache != null) {
          readCache.call();
        } else {
          ///失败
          failure?.call(response.data);
        }
      }
    } on DioError catch (e, s) {
      LogUtil.v("请求出错：$e\n$s");
      if (failure != null && e.type != DioErrorType.cancel) {
        failure(HttpError.dioError(e));
      }
    } catch (e, s) {
      LogUtil.v("未知异常出错：$e\n$s");
      if (failure != null) {
        failure(HttpError(HttpError.UNKNOWN, "网络异常，请稍后重试！"));
      }
    }
  }

  BuildRequest execute({HttpSuccessCallback? success, HttpFailureCallback? failure}) {
    switch (_cacheMode) {
      ///只获取网络
      case CacheMode.noCache:
        {
          _doWorkRequest(success: success, failure: failure);
          break;
        }
     ///先获取缓存，在获取网络
      case CacheMode.firstCacheThenRequest:
        {
          NetUtils.getCache("$_baseUrl$_path", _params).then((list) {
            if (list.isNotEmpty) {
              success?.call(list, SourcesType.cache);
            }
          });
          _doWorkRequest(
              success: success,
              failure: failure,
              /// 存储数据
              cache: true);
          break;
        }
     ///先请求网络，如果请求网络失败，则读取缓存，如果读取缓存失败，本次请求失败
      case CacheMode.requestFailedReadCache:
        {
          _doWorkRequest(
              success: success,
              failure: failure,
              cache: true,
              readCache: () {
                NetUtils.getCache("$_baseUrl$_path", _params).then((list) {
                  if (list.isNotEmpty) {
                    success?.call(list, SourcesType.cache);
                  } else {
                    failure?.call({});
                  }
                });
              });
          break;
        }
      default:
        _doWorkRequest(success: success, failure: failure, cache: true);
        break;
    }
    return this;
  }


  ///上传文件
  void upload({
    ProgressCallback? onSendProgress,
    HttpSuccessCallback? success,
    HttpFailureCallback? failure,
  }) async {
    ///检查网络是否连接
    ConnectivityResult connectivityResult =
    await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      if (failure != null) {
        failure(HttpError(HttpError.NETWORK_ERROR, "网络异常，请稍后重试！"));
      }
      LogUtil.v("请求网络异常，请稍后重试！");
      return;
    }

    String url = _path.toString();
    if (getEnableRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      Response<Map<String, dynamic>> response = await _rxNet.client!.request(
          url,
          onSendProgress: onSendProgress,
          data: _bodyData,
          queryParameters: _params,
          options: _options,
          cancelToken: _cancelTokens[_cancleTag]);

      if(response.statusCode == 200){
        success?.call(response.data, SourcesType.net);
      }else{
        failure?.call(response.data);
      }

    } on DioError catch (e, s) {
      LogUtil.v("请求出错：$e\n$s");
      if (failure != null && e.type != DioErrorType.cancel) {
        failure(HttpError.dioError(e));
      }
    } catch (e, s) {
      LogUtil.v("未知异常出错：$e\n$s");
      if (failure != null) {
        failure(HttpError(HttpError.UNKNOWN, "网络异常，请稍后重试！"));
      }
    }
  }


  ///下载文件
  ///[url] 下载地址
  ///[savePath]  文件保存路径
  void download({
    required String url,
    required String savePath,
    ProgressCallback? onReceiveProgress,
    HttpSuccessCallback? success,
    HttpFailureCallback? failure,
  }) async {
    ///检查网络是否连接
    ConnectivityResult connectivityResult =
    await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      if (failure != null) {
        failure(HttpError(HttpError.NETWORK_ERROR, "网络异常，请稍后重试！"));
      }
      LogUtil.v("请求网络异常，请稍后重试！");
      return;
    }

    ///0代表不设置超时
    int receiveTimeout = 0;
    var options = _options??Options(
      receiveTimeout: receiveTimeout
    );

    String url = _path.toString();
    if (getEnableRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      Response<dynamic> response = await _rxNet.client!.download(
          url,
          savePath,
          onReceiveProgress: onReceiveProgress,
          queryParameters: _params,
          data: _bodyData,
          options: options,
          cancelToken: _cancelTokens[_cancleTag]);
      ///成功
      if(response.statusCode==200){
        if (success != null) {
          success(response.data,SourcesType.net);
        }
      }else{
        failure?.call(response.data);
      }
    } on DioError catch (e, s) {
      LogUtil.v("请求出错：$e\n$s");
      if (failure != null && e.type != DioErrorType.cancel) {
        failure(HttpError.dioError(e));
      }
    } catch (e, s) {
      LogUtil.v("未知异常出错：$e\n$s");
      if (failure != null) {
        failure(HttpError(HttpError.UNKNOWN, "网络异常，请稍后重试！"));
      }
    }
  }

}
