import 'package:flutter_rxnet_forzzh/net/result_entity.dart';
import '../net/rxnet_exception.dart';

void download({required String? url}){
   throw RxNetException(code: "800", resultEntity: ResultEntity(isError: true,value: "非Web端请使用 RxNet.download"));
}

