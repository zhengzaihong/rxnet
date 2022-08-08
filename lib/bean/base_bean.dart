import 'package:rxnet/net/RxNet.dart';

///
/// create_user: zhengzaihong
/// email:1096877329@qq.com
/// create_date: 2022/8/8
/// create_time: 11:03
/// describe: json 转数据模型的基础bean
/// 项目中的基础模型 需要继承该类，并复写方法
///
abstract class BaseNetBean{

  DataModel dataModel = DataModel.cache;

  void parseJson(dynamic data);

  bool isSuccess();

  dynamic callBackData();

}