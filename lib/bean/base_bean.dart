

import 'package:rxnet/net/RxNet.dart';

abstract class BaseNetBean{

  DataModel dataModel = DataModel.cache;

  void parseJson();

  bool isSuccess();
}