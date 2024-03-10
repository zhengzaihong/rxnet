

import '../net/RxNet.dart';

Future<dynamic> rxPut(dynamic key, dynamic value) async {
  if(RxNet().getDb()==null){
    throw ArgumentError('RxNet数据库还未初始化');
  }
  return RxNet().getDb()!.put(key,value);
}

Future<dynamic> rxGet(dynamic key)  async{
  if(RxNet().getDb()==null){
    throw ArgumentError('RxNet数据库还未初始化');
  }
  return RxNet().getDb()!.get(key);
}