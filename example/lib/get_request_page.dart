

import 'package:flutter/material.dart';
import 'package:flutter_rxnet_forzzh/rxnet_lib.dart';
import 'package:rxnet_example/bean/normal_water_info_entity.dart';

class GetRequestPage extends StatefulWidget {

  const GetRequestPage({Key? key}) : super(key: key);

  @override
  State<GetRequestPage> createState() => _GetRequestPageState();
}

class _GetRequestPageState extends State<GetRequestPage> {

  SourcesType sourcesType =SourcesType.net;
  String content = "";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:  <Widget>[
          const SizedBox(height: 40),
          TextButton(
            onPressed: (){
              request();
            },
            style: ButtonStyle(
              backgroundColor:MaterialStateProperty.all(Colors.cyan),
            ),
            child: const Text("发起get请求",style: TextStyle(color: Colors.black,fontSize: 16)),),

          const SizedBox(height: 20),
          Expanded(child:Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              Text("数据来源：${sourcesType == SourcesType.net ? "网络" :"缓存"}",style: const TextStyle(color: Colors.black,fontSize: 16)),
              Expanded(
                  flex: 2,
                  child: Text(content,style:const TextStyle(color: Colors.black,fontSize: 12))),

            ],
          ))

        ],
      ),
    );
  }

  void request() {

    var success = ((data,mo){
      var source = mo as SourcesType;
      if(data is NormalWaterInfoEntity){
        content = data.toString();
      }
      if(source == SourcesType.net){
        sourcesType = SourcesType.net;
      }else{
        sourcesType = SourcesType.cache;
      }
      setState(() {});
    });

    var failure = ((error){

    });

    RxNet.get<NormalWaterInfoEntity>()  ///这里可以省略 泛型声明
        .setPath("api/weather")
        .setParam("city", "101030100")
        .setEnableRestfulUrl(true) ///Restful
        .setCacheMode(CacheMode.requestFailedReadCache)
        .setJsonConvert((data)=>NormalWaterInfoEntity.fromJson(data))
        //
        // .setJsonConvertAdapter(
        //   JsonConvertAdapter<NormalWaterInfoEntity>((data){
        //     return NormalWaterInfoEntity.fromJson(data);
        //   }))
        .execute(success: success,failure:failure);




  }

}
