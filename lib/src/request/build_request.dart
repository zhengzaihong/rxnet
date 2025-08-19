import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';
import '../../utils/net_utils.dart';
import '../../utils/rx_net_database.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2025-08-12
/// create_time: 17:22
/// describe: 优化 RxNet职责，将BuildRequest从RxNet中分离出来，
///
class BuildRequest<T> {

  final HttpType _httpType;
  final RxNet _rxNet;
  CancelToken? _cancelToken;
  String? _path;
  CacheMode? _cacheMode;
  Map<String, dynamic> _params = {};
  List<String> _ignoreCacheKeys = [];
  Map<String, dynamic> _headers = {};
  bool _enableGlobalHeader = true;
  dynamic _bodyData;
  bool _toFormData = false;
  bool _toBodyData = false;
  JsonTransformation? _jsonTransformation;
  Options? _options;
  int? _cacheInvalidationTime;
  bool _requestIgnoreCacheTime = false;
  int _retryCount = 0;
  int _retryInterval = 1000;
  bool _isLoop = false;
  bool _failRetry = true;
  bool _RESETFulUrl = false;
  CheckNetWork? checkNetWork;
  Function(Response response)? onResponse;

  BuildRequest(this._httpType, this._rxNet) {
    BaseOptions? op = _rxNet.client?.options;
    _options = Options(
      method: op?.method,
      sendTimeout: op?.sendTimeout,
      receiveTimeout: op?.receiveTimeout,
      extra: op?.extra,
      headers: op?.headers,
      responseType: op?.responseType,
      contentType: op?.contentType,
      validateStatus: op?.validateStatus,
      receiveDataWhenStatusError: op?.receiveDataWhenStatusError,
      followRedirects: op?.followRedirects,
      maxRedirects: op?.maxRedirects,
      requestEncoder: op?.requestEncoder,
      responseDecoder: op?.responseDecoder,
      listFormat: op?.listFormat,
    );
  }

  BuildRequest setJsonConvert(JsonTransformation convert) {
    _jsonTransformation = convert;
    return this;
  }

  BuildRequest setRestfulUrl(bool restful) {
    _RESETFulUrl = restful;
    return this;
  }

  bool isRestfulUrl() {
    return _RESETFulUrl;
  }

  BuildRequest setPath(String path) {
    _path = path;
    return this;
  }

  BuildRequest setParam(String key, dynamic value) {
    _params[key] = value;
    return this;
  }

  BuildRequest setParams(Map<String, dynamic> params) {
    _params = params;
    return this;
  }

  BuildRequest addParams(Map<String, dynamic> params) {
    _params.addAll(params);
    return this;
  }

  BuildRequest setParamsToFormData(bool toFormData) {
    _toFormData = toFormData;
    _toBodyData = false;
    return this;
  }

  BuildRequest setParamsToBodyData(bool toBody) {
    _toBodyData = toBody;
    _toFormData = false;
    return this;
  }

  BuildRequest toFormData() {
    setParamsToFormData(true);
    return this;
  }

  BuildRequest toBodyData() {
    setParamsToBodyData(true);
    return this;
  }

  BuildRequest toUrlEncoded() {
    setParamsToFormData(true);
    _options?.contentType = Headers.formUrlEncodedContentType;
    return this;
  }

  BuildRequest removeNullValueKeys() {
    _params.removeWhere((key, value) => value == null);
    return this;
  }

  BuildRequest getParams(ParamCallBack callBack) {
    callBack.call(_params);
    return this;
  }

  BuildRequest addHeaders(Map<String, dynamic> headers) {
    _headers = headers;
    return this;
  }

  BuildRequest setHeader(String key, dynamic value) {
    _headers[key] = value;
    return this;
  }

  BuildRequest setCancelToken(CancelToken cancelToken) {
    _cancelToken = cancelToken;
    return this;
  }

  BuildRequest setEnableGlobalHeader(bool enable) {
    _enableGlobalHeader = enable;
    return this;
  }

  BuildRequest setCacheMode(CacheMode cacheMode) {
    _cacheMode = cacheMode;
    if (RxNetPlatform.isWeb) {
      _cacheMode = CacheMode.onlyRequest;
    }
    return this;
  }

  BuildRequest setRequestIgnoreCacheTime(bool ignoreCache) {
    _requestIgnoreCacheTime = ignoreCache;
    return this;
  }

  BuildRequest setIgnoreCacheKeys(List<String> keys) {
    _ignoreCacheKeys.addAll(keys);
    return this;
  }

  BuildRequest setIgnoreCacheKey(String key) {
    _ignoreCacheKeys.add(key);
    return this;
  }

  BuildRequest setLoop(bool loop) {
    _isLoop = loop;
    return this;
  }

  BuildRequest setRetryCount(int count) {
    _retryCount = count;
    return this;
  }

  BuildRequest setRetryInterval(int interval) {
    _retryInterval = interval;
    return this;
  }

  BuildRequest setFailRetry(bool status) {
    _failRetry = status;
    return this;
  }

  BuildRequest setCacheInvalidationTime(int millisecond) {
    _cacheInvalidationTime = millisecond;
    return this;
  }

  BuildRequest setOptionConfig(OptionConfig callBack) {
    callBack.call(_options!);
    return this;
  }

  BuildRequest setCheckNetwork(CheckNetWork checkNetWork) {
    this.checkNetWork = checkNetWork;
    return this;
  }

  CancelToken? getCancelToken() {
    return _cancelToken;
  }

  BuildRequest setResponseCallBack(
      Function(Response response) responseCallBack) {
    this.onResponse = responseCallBack;
    return this;
  }

  Future<RxResult<T>> _doWorkRequest<T>({bool cache = false}) async {
    String url = _path.toString();
    Map<String, dynamic> queryParameters = {};
    dynamic requestBody = _bodyData;

    final Map<String, dynamic> tempParams = Map.from(_params);

    if (isRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), tempParams);
      // After building the restful URL, remaining params should be query parameters
      // queryParameters.addAll(tempParams);
    } else {
      queryParameters.addAll(tempParams);
    }

    bool hasFile = tempParams.values.any((element) => element is MultipartFile);
    if(hasFile) {
      _toFormData = true;
    }

    if (_toFormData) {
      requestBody = FormData.fromMap(tempParams);
      queryParameters = {}; // FormData sends params in the body
    } else if (_toBodyData) {
      requestBody = tempParams;
      queryParameters = {}; // Body data sends params in the body
    }


    int currentRetryCount = 0;

    while (currentRetryCount <= _retryCount) {
      try {
        _options?.method = _httpType.name;
        if (_headers.isNotEmpty) {
          _options?.headers = _headers;
        }
        if (_enableGlobalHeader) {
          _options?.headers ??= {};
          _options?.headers?.addAll(_rxNet.getHeaders());
        }


        LogUtil.v("$url，JsonConvert：${_jsonTransformation != null}");

        Response<dynamic> response = await _rxNet.client!.request(url,
            data: requestBody,
            queryParameters: queryParameters,
            options: _options,
            cancelToken: _cancelToken);

        onResponse?.call(response);
        var responseData = response.data;

        if (response.statusCode == 200) {
          T data;
          try {
            if (_jsonTransformation != null) {
              if (responseData is String) {
                responseData = jsonDecode(responseData);
              }
              data = await _jsonTransformation?.call(responseData) as T;
            } else {
              data = responseData as T;
            }
          } catch (e) {
            throw ParsingException("Data parsing failed", e);
          }

          if (cache && !RxNetPlatform.isWeb) {
            if (_rxNet.getIgnoreCacheKeys() != null) {
              _ignoreCacheKeys.addAll(_rxNet.getIgnoreCacheKeys()!);
              _ignoreCacheKeys = _ignoreCacheKeys.toSet().toList();
            }
            String cacheKey =
                NetUtils.getCacheKeyFromPath(_path, _params, _ignoreCacheKeys);
            final map = <String, dynamic>{
              'timestamp': DateTime.now().millisecondsSinceEpoch,
              'data': responseData
            };
            _rxNet.cacheManager.saveCache(cacheKey, jsonEncode(map));
          }
          return RxResult(value: data, model: SourcesType.net);
        } else {
          throw NetworkException("Request failed with status code ${response.statusCode}", response);
        }
      } catch (e, s) {
        LogUtil.v("请求出错：$e\n$s");
        if (e is DioException && CancelToken.isCancel(e)) {
          throw CancellationException("Request was cancelled", e);
        }
        if (e is RxError) {
           throw e;
        }
        if (!_failRetry || currentRetryCount >= _retryCount) {
           throw NetworkException("Request failed after retries", e);
        }
      }
      currentRetryCount++;
      if (_isLoop) {
        currentRetryCount = 0;
      }
      await Future.delayed(Duration(milliseconds: _retryInterval));
    }
     throw NetworkException("Request failed");
  }

  Future<RxResult<T>> _readCache<T>() async {
    if (RxNetPlatform.isWeb || !await RxNetDataBase.isDatabaseReady) {
      throw CacheException("Cache not available");
    }

    if (_rxNet.getIgnoreCacheKeys() != null) {
      _ignoreCacheKeys.addAll(_rxNet.getIgnoreCacheKeys()!);
      _ignoreCacheKeys = _ignoreCacheKeys.toSet().toList();
    }
    final cacheKey =
        NetUtils.getCacheKeyFromPath(_path, _params, _ignoreCacheKeys);
    final cacheData = await _rxNet.cacheManager.readCache(cacheKey);

    if (TextUtil.isEmpty(cacheData)) {
      throw CacheException("Cache is empty");
    }
    
    dynamic data;
    try {
      data = jsonDecode(cacheData);
    } catch(e) {
        throw ParsingException("Failed to decode cache data", e);
    }
    
    final timestamp = data['timestamp'];
    final dataValue = data['data'];
    LogUtil.v("-->缓存数据:${jsonEncode(data)}");

    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - timestamp > (_cacheInvalidationTime ?? _rxNet.getCacheInvalidationTime())) {
      LogUtil.v("-->缓存数据:超时效");
      throw CacheException("Cache expired");
    }
    if (dataValue != null ) {
      return _parseLocalData(dataValue);
    } else {
      throw CacheException("Cache is empty");
    }
  }

  Future<RxResult<T>> _parseLocalData<T>(dynamic cacheValue) async {
    try {
      if (_jsonTransformation != null) {
        LogUtil.v("JsonConvert：true");
        final data = await _jsonTransformation?.call(cacheValue) as T;
        return RxResult(value: data, model: SourcesType.cache);
      } else {
        LogUtil.v("JsonConvert：false");
        return RxResult(value: cacheValue as T, model: SourcesType.cache);
      }
    } catch (e) {
      LogUtil.v("RxNet：请检查json数据接收类是否正确: $e");
      throw ParsingException("Failed to parse cached data", e);
    }
  }

  Future<bool> _checkNetWork() async {
    if (checkNetWork != null) {
      return await checkNetWork!.call();
    }
    if (checkNetWork == null && _rxNet.getCheckNetWork() != null) {
      return await _rxNet.getCheckNetWork()!.call();
    }
    return true;
  }

  //使用回调的方式
  //How to use callbacks
  void execute<T>({Success<T>? success, Failure? failure, Completed? completed}) {
    executeStream().listen((result) {
      success?.call(result.value as T, result.model);
    }, onError: (e) {
      failure?.call(e);
    }, onDone: completed);
  }

  //更加现代化的 async/await 方式
  //A more modern async/await approach
  Future<RxResult<T>> request() async {
    final stream = executeStream();
    return await stream.last;
  }

  Stream<RxResult<T>> executeStream() {
    late StreamController<RxResult<T>> controller;
    if (TextUtil.isEmpty(_path)) {
      throw Exception("请求路径不能为空 path:$_path");
    }
    void start() async {
      if (!(await _checkNetWork())) {
         controller.addError(NetworkException("Network not available"));
         await controller.close();
        return;
      }
      _cacheMode ??= (_rxNet.getBaseCacheMode() ?? CacheMode.onlyRequest);

      switch (_cacheMode!) {
        case CacheMode.onlyRequest:
          try {
            final result = await _doWorkRequest<T>(cache: true);
            controller.add(result);
          } catch (e) {
            controller.addError(e);
          } finally {
            await controller.close();
          }
          break;
        case CacheMode.firstCacheThenRequest:
          try {
            final cacheResult = await _readCache<T>();
            controller.add(cacheResult);
          } catch (e) {
            // In this mode, cache errors are ignored, and we proceed to the network request.
          }
          try {
            final netResult = await _doWorkRequest<T>(cache: true);
            controller.add(netResult);
          } catch (e) {
            controller.addError(e);
          } finally {
             await controller.close();
          }
          break;
        case CacheMode.requestFailedReadCache:
          try {
            final netResult = await _doWorkRequest<T>(cache: true);
            controller.add(netResult);
          } catch (e) {
             try {
               final cacheResult = await _readCache<T>();
               controller.add(cacheResult);
             } catch (cacheError) {
               // Report the original network error
               controller.addError(e);
             }
          } finally {
            await controller.close();
          }
          break;
        case CacheMode.cacheNoneToRequest:
          if (_requestIgnoreCacheTime) {
            try {
              final result = await _doWorkRequest<T>(cache: true);
              controller.add(result);
            } catch (e) {
              controller.addError(e);
            } finally {
              await controller.close();
            }
            return;
          }
          try {
            final cacheResult = await _readCache<T>();
            controller.add(cacheResult);
             await controller.close();
          } catch (e) {
            try {
              final netResult = await _doWorkRequest<T>(cache: true);
              controller.add(netResult);
            } catch (netError) {
              controller.addError(netError);
            } finally {
               await controller.close();
            }
          }
          break;
        case CacheMode.onlyCache:
          try {
            final cacheResult = await _readCache<T>();
            controller.add(cacheResult);
          } catch (e) {
            controller.addError(e);
          } finally {
            await controller.close();
          }
          break;
      }
    }

    controller = StreamController<RxResult<T>>(onListen: start);
    return controller.stream;
  }

  void upload({
    ProgressCallback? onSendProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
  }) async {
    if (!(await _checkNetWork())) {
      return;
    }

    String url = _path.toString();
    if (isRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = _httpType.name;
      if (_headers.isNotEmpty) {
        _options?.headers = _headers;
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.getHeaders());
      }
      if (_toFormData) {
        _bodyData = FormData.fromMap(_params);
      }
      if (_toBodyData) {
        _bodyData = _params;
      }

      Response response = await _rxNet.client!.request(url,
          data: _bodyData,
          queryParameters:
              (isRestfulUrl() || _toFormData || _toBodyData) ? {} : _params,
          options: _options,
          cancelToken: _cancelToken);

      onResponse?.call(response);
      if (response.statusCode == 200) {
        success?.call(response.data, SourcesType.net);
      }
    } catch (e) {
      failure?.call(e);
    }
    completed?.call();
  }

  void download({
    required String savePath,
    ProgressCallback? onReceiveProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
  }) async {
    if (!(await _checkNetWork())) {
      return;
    }
    String url = _path.toString();
    if (isRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    try {
      _options?.method = _httpType.name;
      if (_headers.isNotEmpty) {
        _options?.headers = _headers;
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.getHeaders());
      }
      if (_toFormData) {
        _bodyData = FormData.fromMap(_params);
      }
      if (_toBodyData) {
        _bodyData = _params;
      }

      final response = await _rxNet.client!.download(url, savePath,
          onReceiveProgress: (received, total) {
        if (total != -1) {
          onReceiveProgress?.call(received, total);
        }
        if (received >= total) {
          success?.call(savePath, SourcesType.net);
        }},
          queryParameters: (isRestfulUrl() || _toFormData || _toBodyData) ? {} : _params,
          data: _bodyData,
          options: _options,
          cancelToken: _cancelToken);

      onResponse?.call(response);
      if (response.statusCode != 200) {
        failure?.call(response.data);
      }
    } catch (e) {
      failure?.call(e);
    }
    completed?.call();
  }

  void downloadBreakPoint({
    required String savePath,
    ProgressCallback? onReceiveProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
    Function()? cancelCallback,
  }) async {
    if (!(await _checkNetWork())) {
      return;
    }

    int downloadStart = 0;
    File file = File(savePath);
    try {
      String url = _path.toString();
      if (isRestfulUrl()) {
        url = NetUtils.restfulUrl(_path.toString(), _params);
      }
      if (file.existsSync()) {
        // Stream<List<int>> streamFileSize = file.openRead();
        // await for (var chunk in streamFileSize) {
        //   downloadStart += chunk.length;
        // }
        downloadStart = file.lengthSync();
      }
      _options?.method = _httpType.name;
      _options = _options?.copyWith(
        responseType: ResponseType.stream,
      );

      if (_headers.isNotEmpty) {
        _options?.headers?.addAll(_headers);
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.getHeaders());
      }
      _options?.headers?.addAll({"Range": "bytes=$downloadStart-"});
      if (_toFormData) {
        _bodyData = FormData.fromMap(_params);
      }
      if (_toBodyData) {
        _bodyData = _params;
      }

      final response = await _rxNet.client!.request<ResponseBody>(
        url,
        options: _options,
        cancelToken: _cancelToken,
        data: _bodyData,
        queryParameters:
            (isRestfulUrl() || _toFormData || _toBodyData) ? {} : _params,
      );
      onResponse?.call(response);
      RandomAccessFile raf = file.openSync(mode: FileMode.append);
      Stream<Uint8List> stream = response.data!.stream;

      final content = await getContentLength(response);
      final total = int.tryParse(content?.split('/').last ?? "0") ?? 0;

      final subscription = stream.listen((data) {
        raf.writeFromSync(data);
        downloadStart = downloadStart + data.length;
        if (total < downloadStart) {
          onReceiveProgress?.call(total, total);
          return;
        }
        onReceiveProgress?.call(downloadStart, total);
      }, onDone: () async {
        success?.call(file, SourcesType.net);
        await raf.close();
      }, onError: (e) async {
        failure?.call(e);
        await raf.close();
      }, cancelOnError: true);

      _cancelToken?.whenCancel.then((_) async {
        await subscription.cancel();
        await raf.close();
        cancelCallback?.call();
      });
    } on DioException catch (error) {
      if (error.response != null) {
        final content = await getContentLength(error.response!);
        final total = int.tryParse(content?.split('/').last ?? "0") ?? 0;
        if (total <= downloadStart) {
          onReceiveProgress?.call(total, total);
          success?.call(file, SourcesType.net);
        }
      }
      if (CancelToken.isCancel(error)) {
        cancelCallback?.call();
      } else {
        failure?.call(error);
      }
    }

    completed?.call();
  }

  void uploadFileBreakPoint({
    required String filePath,
    ProgressCallback? onSendProgress,
    Success? success,
    Failure? failure,
    Completed? completed,
    Function()? cancelCallback,
    int? start,
  }) async {
    if (!(await _checkNetWork())) {
      return;
    }
    String url = _path.toString();
    if (isRestfulUrl()) {
      url = NetUtils.restfulUrl(_path.toString(), _params);
    }
    var progress = start ?? 0;
    int fileSize = 0;
    File file = File(filePath);
    if (file.existsSync()) {
      // Stream<List<int>> streamFileSize = file.openRead();
      // await for (var chunk in streamFileSize) {
      //   fileSize += chunk.length;
      // }
      fileSize = file.lengthSync();
    }
    var data = file.openRead(progress, fileSize - progress);
    try {
      _options?.method = _httpType.name;
      if (_headers.isNotEmpty) {
        _options?.headers?.addAll(_headers);
      }
      if (_enableGlobalHeader) {
        _options?.headers ??= {};
        _options?.headers?.addAll(_rxNet.getHeaders());
      }
      _options?.headers?.addAll(
          {'Content-Range': 'bytes $progress-${fileSize - 1}/$fileSize'});

      if (_toFormData) {
        _bodyData = FormData.fromMap(_params);
      }
      if (_toBodyData) {
        _bodyData = _params;
      }
      final response = await _rxNet.client!.request<ResponseBody>(
        url,
        options: _options,
        cancelToken: _cancelToken,
        data: data,
        queryParameters:
            (isRestfulUrl() || _toFormData || _toBodyData) ? {} : _params,
      );
      onResponse?.call(response);
      Stream<Uint8List> stream = response.data!.stream;
      final subscription = stream.listen((data) {
        progress = progress + data.length;
        onSendProgress?.call(progress, fileSize);
      }, onDone: () async {
        success?.call(file, SourcesType.net);
      }, onError: (e) async {
        failure?.call(e);
      }, cancelOnError: true);
      _cancelToken?.whenCancel.then((_) async {
        await subscription.cancel();
        cancelCallback?.call();
      });
    } on DioException catch (error) {
      if (error.response != null) {
        if (progress <= fileSize) {
          onSendProgress?.call(progress, fileSize);
          success?.call(file, SourcesType.net);
        }
      }
      if (CancelToken.isCancel(error)) {
        cancelCallback?.call();
      } else {
        failure?.call(error);
      }
    }

    completed?.call();
  }

  Future<String?> getContentLength(Response<dynamic> response) async {
    try {
      return response.headers.value(HttpHeaders.contentRangeHeader);
    } catch (e) {
      return null;
    }
  }
}
