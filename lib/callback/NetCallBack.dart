import 'package:flutter/material.dart';

typedef NetCallbackFunction<T> = void Function(T);

class NetCallback<T> {
  NetCallbackFunction<T>? onNetFinish;
  NetCallbackFunction<T>? onCacheFinish;
  NetCallbackFunction<T>? onUnkownFinish;

  NetCallback({this.onCacheFinish, this.onNetFinish, this.onUnkownFinish});
}

class RequestData<T> {
  RequestType requestType;
  int? statusCode;
  T data;

//  RequestData(this.requestType, this.data);

  RequestData({required this.requestType, required this.data,  this.statusCode});
}

enum RequestType {
  NET,
  CACHE,
  UNKOWN,
}

