import 'dart:convert';

import 'package:rxnet_example/json/base/json_field.dart';
import 'package:rxnet_example/json/water_info_entity.g.dart';

@JsonSerializable()
class WaterInfoEntity {

	String? shidu;
	double? pm25;
	double? pm10;
	String? quality;
	String? wendu;
	String? ganmao;
	List<WaterInfoForecast>? forecast;
	WaterInfoYesterday? yesterday;
  
  WaterInfoEntity();

  factory WaterInfoEntity.fromJson(Map<String, dynamic> json) => $WaterInfoEntityFromJson(json);

  Map<String, dynamic> toJson() => $WaterInfoEntityToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}

@JsonSerializable()
class WaterInfoForecast {

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
  
  WaterInfoForecast();

  factory WaterInfoForecast.fromJson(Map<String, dynamic> json) => $WaterInfoForecastFromJson(json);

  Map<String, dynamic> toJson() => $WaterInfoForecastToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}

@JsonSerializable()
class WaterInfoYesterday {

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
  
  WaterInfoYesterday();

  factory WaterInfoYesterday.fromJson(Map<String, dynamic> json) => $WaterInfoYesterdayFromJson(json);

  Map<String, dynamic> toJson() => $WaterInfoYesterdayToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}