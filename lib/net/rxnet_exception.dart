import 'dart:core';
import 'package:flutter_rxnet_forzzh/net/rx_result.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2023/9/16
/// create_time: 17:36
/// describe:
///
class RxNetException implements Exception{
  String? code;
  RxResult? resultEntity;

  RxNetException({this.code,this.resultEntity});

}