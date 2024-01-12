

import '../net/RxNet.dart';

Future<dynamic> rxPut(dynamic key, dynamic value) {
  if(RxNet().getDb()==null){
    throw ArgumentError('rxnet数据库还未初始化');
  }
  return RxNet().getDb()!.put(key,value);
}

Future<dynamic> rxGet(dynamic key) {
  if(RxNet().getDb()==null){
    throw ArgumentError('rxnet数据库还未初始化');
  }
  return RxNet().getDb()!.get(key);
}