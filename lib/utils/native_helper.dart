import '../net/RxResult.dart';
import '../net/rxnet_exception.dart';

void download({required String? url}){
   throw RxNetException(code: "800", resultEntity: RxResult(isError: true,value: "非Web端请使用 RxNet.download"));
}

