import 'package:rxnet_example/bean/water_info_entity.dart';
import 'package:rxnet_example/json/base/json_convert_content.dart';

WaterInfoEntity $WaterInfoEntityFromJson(Map<String, dynamic> json) {
	final WaterInfoEntity waterInfoEntity = WaterInfoEntity();
	final String? shidu = jsonConvert.convert<String>(json['shidu']);
	if (shidu != null) {
		waterInfoEntity.shidu = shidu;
	}
	final double? pm25 = jsonConvert.convert<double>(json['pm25']);
	if (pm25 != null) {
		waterInfoEntity.pm25 = pm25;
	}
	final double? pm10 = jsonConvert.convert<double>(json['pm10']);
	if (pm10 != null) {
		waterInfoEntity.pm10 = pm10;
	}
	final String? quality = jsonConvert.convert<String>(json['quality']);
	if (quality != null) {
		waterInfoEntity.quality = quality;
	}
	final String? wendu = jsonConvert.convert<String>(json['wendu']);
	if (wendu != null) {
		waterInfoEntity.wendu = wendu;
	}
	final String? ganmao = jsonConvert.convert<String>(json['ganmao']);
	if (ganmao != null) {
		waterInfoEntity.ganmao = ganmao;
	}
	final List<WaterInfoForecast>? forecast = jsonConvert.convertListNotNull<WaterInfoForecast>(json['forecast']);
	if (forecast != null) {
		waterInfoEntity.forecast = forecast;
	}
	final WaterInfoYesterday? yesterday = jsonConvert.convert<WaterInfoYesterday>(json['yesterday']);
	if (yesterday != null) {
		waterInfoEntity.yesterday = yesterday;
	}
	return waterInfoEntity;
}

Map<String, dynamic> $WaterInfoEntityToJson(WaterInfoEntity entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['shidu'] = entity.shidu;
	data['pm25'] = entity.pm25;
	data['pm10'] = entity.pm10;
	data['quality'] = entity.quality;
	data['wendu'] = entity.wendu;
	data['ganmao'] = entity.ganmao;
	data['forecast'] =  entity.forecast?.map((v) => v.toJson()).toList();
	data['yesterday'] = entity.yesterday?.toJson();
	return data;
}

WaterInfoForecast $WaterInfoForecastFromJson(Map<String, dynamic> json) {
	final WaterInfoForecast waterInfoForecast = WaterInfoForecast();
	final String? date = jsonConvert.convert<String>(json['date']);
	if (date != null) {
		waterInfoForecast.date = date;
	}
	final String? high = jsonConvert.convert<String>(json['high']);
	if (high != null) {
		waterInfoForecast.high = high;
	}
	final String? low = jsonConvert.convert<String>(json['low']);
	if (low != null) {
		waterInfoForecast.low = low;
	}
	final String? ymd = jsonConvert.convert<String>(json['ymd']);
	if (ymd != null) {
		waterInfoForecast.ymd = ymd;
	}
	final String? week = jsonConvert.convert<String>(json['week']);
	if (week != null) {
		waterInfoForecast.week = week;
	}
	final String? sunrise = jsonConvert.convert<String>(json['sunrise']);
	if (sunrise != null) {
		waterInfoForecast.sunrise = sunrise;
	}
	final String? sunset = jsonConvert.convert<String>(json['sunset']);
	if (sunset != null) {
		waterInfoForecast.sunset = sunset;
	}
	final int? aqi = jsonConvert.convert<int>(json['aqi']);
	if (aqi != null) {
		waterInfoForecast.aqi = aqi;
	}
	final String? fx = jsonConvert.convert<String>(json['fx']);
	if (fx != null) {
		waterInfoForecast.fx = fx;
	}
	final String? fl = jsonConvert.convert<String>(json['fl']);
	if (fl != null) {
		waterInfoForecast.fl = fl;
	}
	final String? type = jsonConvert.convert<String>(json['type']);
	if (type != null) {
		waterInfoForecast.type = type;
	}
	final String? notice = jsonConvert.convert<String>(json['notice']);
	if (notice != null) {
		waterInfoForecast.notice = notice;
	}
	return waterInfoForecast;
}

Map<String, dynamic> $WaterInfoForecastToJson(WaterInfoForecast entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['date'] = entity.date;
	data['high'] = entity.high;
	data['low'] = entity.low;
	data['ymd'] = entity.ymd;
	data['week'] = entity.week;
	data['sunrise'] = entity.sunrise;
	data['sunset'] = entity.sunset;
	data['aqi'] = entity.aqi;
	data['fx'] = entity.fx;
	data['fl'] = entity.fl;
	data['type'] = entity.type;
	data['notice'] = entity.notice;
	return data;
}

WaterInfoYesterday $WaterInfoYesterdayFromJson(Map<String, dynamic> json) {
	final WaterInfoYesterday waterInfoYesterday = WaterInfoYesterday();
	final String? date = jsonConvert.convert<String>(json['date']);
	if (date != null) {
		waterInfoYesterday.date = date;
	}
	final String? high = jsonConvert.convert<String>(json['high']);
	if (high != null) {
		waterInfoYesterday.high = high;
	}
	final String? low = jsonConvert.convert<String>(json['low']);
	if (low != null) {
		waterInfoYesterday.low = low;
	}
	final String? ymd = jsonConvert.convert<String>(json['ymd']);
	if (ymd != null) {
		waterInfoYesterday.ymd = ymd;
	}
	final String? week = jsonConvert.convert<String>(json['week']);
	if (week != null) {
		waterInfoYesterday.week = week;
	}
	final String? sunrise = jsonConvert.convert<String>(json['sunrise']);
	if (sunrise != null) {
		waterInfoYesterday.sunrise = sunrise;
	}
	final String? sunset = jsonConvert.convert<String>(json['sunset']);
	if (sunset != null) {
		waterInfoYesterday.sunset = sunset;
	}
	final int? aqi = jsonConvert.convert<int>(json['aqi']);
	if (aqi != null) {
		waterInfoYesterday.aqi = aqi;
	}
	final String? fx = jsonConvert.convert<String>(json['fx']);
	if (fx != null) {
		waterInfoYesterday.fx = fx;
	}
	final String? fl = jsonConvert.convert<String>(json['fl']);
	if (fl != null) {
		waterInfoYesterday.fl = fl;
	}
	final String? type = jsonConvert.convert<String>(json['type']);
	if (type != null) {
		waterInfoYesterday.type = type;
	}
	final String? notice = jsonConvert.convert<String>(json['notice']);
	if (notice != null) {
		waterInfoYesterday.notice = notice;
	}
	return waterInfoYesterday;
}

Map<String, dynamic> $WaterInfoYesterdayToJson(WaterInfoYesterday entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['date'] = entity.date;
	data['high'] = entity.high;
	data['low'] = entity.low;
	data['ymd'] = entity.ymd;
	data['week'] = entity.week;
	data['sunrise'] = entity.sunrise;
	data['sunset'] = entity.sunset;
	data['aqi'] = entity.aqi;
	data['fx'] = entity.fx;
	data['fl'] = entity.fl;
	data['type'] = entity.type;
	data['notice'] = entity.notice;
	return data;
}