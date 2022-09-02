import 'dart:convert';
import 'package:rxnet_example/json/base/json_field.dart';

import '../json/normal_water_info_entity.g.dart';

@JsonSerializable()
class NormalWaterInfoEntity {

	String? message;
	int? status;
	String? date;
	String? time;
	NormalWaterInfoCityInfo? cityInfo;
	NormalWaterInfoData? data;
  
  NormalWaterInfoEntity();

  factory NormalWaterInfoEntity.fromJson(Map<String, dynamic> json) => $NormalWaterInfoEntityFromJson(json);

  Map<String, dynamic> toJson() => $NormalWaterInfoEntityToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}

@JsonSerializable()
class NormalWaterInfoCityInfo {

	String? city;
	String? citykey;
	String? parent;
	String? updateTime;
  
  NormalWaterInfoCityInfo();

  factory NormalWaterInfoCityInfo.fromJson(Map<String, dynamic> json) => $NormalWaterInfoCityInfoFromJson(json);

  Map<String, dynamic> toJson() => $NormalWaterInfoCityInfoToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}

@JsonSerializable()
class NormalWaterInfoData {

	String? shidu;
	double? pm25;
	double? pm10;
	String? quality;
	String? wendu;
	String? ganmao;
	List<NormalWaterInfoDataForecast>? forecast;
	NormalWaterInfoDataYesterday? yesterday;
  
  NormalWaterInfoData();

  factory NormalWaterInfoData.fromJson(Map<String, dynamic> json) => $NormalWaterInfoDataFromJson(json);

  Map<String, dynamic> toJson() => $NormalWaterInfoDataToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}

@JsonSerializable()
class NormalWaterInfoDataForecast {

	String? date;
	String? high;
	String? low;
	String? ymd;
	String? week;
	String? sunrise;
	String? sunset;
	int? aqi;
	String? fx;
	String? fl;
	String? type;
	String? notice;
  
  NormalWaterInfoDataForecast();

  factory NormalWaterInfoDataForecast.fromJson(Map<String, dynamic> json) => $NormalWaterInfoDataForecastFromJson(json);

  Map<String, dynamic> toJson() => $NormalWaterInfoDataForecastToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}

@JsonSerializable()
class NormalWaterInfoDataYesterday {

	String? date;
	String? high;
	String? low;
	String? ymd;
	String? week;
	String? sunrise;
	String? sunset;
	int? aqi;
	String? fx;
	String? fl;
	String? type;
	String? notice;
  
  NormalWaterInfoDataYesterday();

  factory NormalWaterInfoDataYesterday.fromJson(Map<String, dynamic> json) => $NormalWaterInfoDataYesterdayFromJson(json);

  Map<String, dynamic> toJson() => $NormalWaterInfoDataYesterdayToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}