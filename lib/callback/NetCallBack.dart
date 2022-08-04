import 'package:flutter/material.dart';

typedef NetCallbackFunction<T> = void Function(T);

class NetCallback<T> {
  NetCallbackFunction<T> onNetFinish;
  NetCallbackFunction<T> onCacheFinish;
  NetCallbackFunction<T> onUnkownFinish;

  NetCallback({this.onCacheFinish, this.onNetFinish, this.onUnkownFinish});
}

class RequestData<T> {
  RequestType requestType;
  int statusCode;
  T data;

//  RequestData(this.requestType, this.data);

  RequestData({required this.requestType, required this.data,  this.statusCode});
}

enum RequestType {
  NET,
  CACHE,
  UNKOWN,
}

enum CacheMode {
  NO_CACHE, //没有缓存
  DEFAULT, //按照HTTP协议的默认缓存规则，例如有304响应头时缓存
  REQUEST_FAILED_READ_CACHE, //先请求网络，如果请求网络失败，则读取缓存，如果读取缓存失败，本次请求失败
  FIRST_CACHE_THEN_REQUEST, //先使用缓存，不管是否存在，仍然请求网络
}
