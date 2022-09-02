import 'package:rxnet_example/bean/normal_water_info_entity.dart';
import 'package:rxnet_example/json/base/json_convert_content.dart';

NormalWaterInfoEntity $NormalWaterInfoEntityFromJson(Map<String, dynamic> json) {
	final NormalWaterInfoEntity normalWaterInfoEntity = NormalWaterInfoEntity();
	final String? message = jsonConvert.convert<String>(json['message']);
	if (message != null) {
		normalWaterInfoEntity.message = message;
	}
	final int? status = jsonConvert.convert<int>(json['status']);
	if (status != null) {
		normalWaterInfoEntity.status = status;
	}
	final String? date = jsonConvert.convert<String>(json['date']);
	if (date != null) {
		normalWaterInfoEntity.date = date;
	}
	final String? time = jsonConvert.convert<String>(json['time']);
	if (time != null) {
		normalWaterInfoEntity.time = time;
	}
	final NormalWaterInfoCityInfo? cityInfo = jsonConvert.convert<NormalWaterInfoCityInfo>(json['cityInfo']);
	if (cityInfo != null) {
		normalWaterInfoEntity.cityInfo = cityInfo;
	}
	final NormalWaterInfoData? data = jsonConvert.convert<NormalWaterInfoData>(json['data']);
	if (data != null) {
		normalWaterInfoEntity.data = data;
	}
	return normalWaterInfoEntity;
}

Map<String, dynamic> $NormalWaterInfoEntityToJson(NormalWaterInfoEntity entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['message'] = entity.message;
	data['status'] = entity.status;
	data['date'] = entity.date;
	data['time'] = entity.time;
	data['cityInfo'] = entity.cityInfo?.toJson();
	data['data'] = entity.data?.toJson();
	return data;
}

NormalWaterInfoCityInfo $NormalWaterInfoCityInfoFromJson(Map<String, dynamic> json) {
	final NormalWaterInfoCityInfo normalWaterInfoCityInfo = NormalWaterInfoCityInfo();
	final String? city = jsonConvert.convert<String>(json['city']);
	if (city != null) {
		normalWaterInfoCityInfo.city = city;
	}
	final String? citykey = jsonConvert.convert<String>(json['citykey']);
	if (citykey != null) {
		normalWaterInfoCityInfo.citykey = citykey;
	}
	final String? parent = jsonConvert.convert<String>(json['parent']);
	if (parent != null) {
		normalWaterInfoCityInfo.parent = parent;
	}
	final String? updateTime = jsonConvert.convert<String>(json['updateTime']);
	if (updateTime != null) {
		normalWaterInfoCityInfo.updateTime = updateTime;
	}
	return normalWaterInfoCityInfo;
}

Map<String, dynamic> $NormalWaterInfoCityInfoToJson(NormalWaterInfoCityInfo entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['city'] = entity.city;
	data['citykey'] = entity.citykey;
	data['parent'] = entity.parent;
	data['updateTime'] = entity.updateTime;
	return data;
}

NormalWaterInfoData $NormalWaterInfoDataFromJson(Map<String, dynamic> json) {
	final NormalWaterInfoData normalWaterInfoData = NormalWaterInfoData();
	final String? shidu = jsonConvert.convert<String>(json['shidu']);
	if (shidu != null) {
		normalWaterInfoData.shidu = shidu;
	}
	final double? pm25 = jsonConvert.convert<double>(json['pm25']);
	if (pm25 != null) {
		normalWaterInfoData.pm25 = pm25;
	}
	final double? pm10 = jsonConvert.convert<double>(json['pm10']);
	if (pm10 != null) {
		normalWaterInfoData.pm10 = pm10;
	}
	final String? quality = jsonConvert.convert<String>(json['quality']);
	if (quality != null) {
		normalWaterInfoData.quality = quality;
	}
	final String? wendu = jsonConvert.convert<String>(json['wendu']);
	if (wendu != null) {
		normalWaterInfoData.wendu = wendu;
	}
	final String? ganmao = jsonConvert.convert<String>(json['ganmao']);
	if (ganmao != null) {
		normalWaterInfoData.ganmao = ganmao;
	}
	final List<NormalWaterInfoDataForecast>? forecast = jsonConvert.convertListNotNull<NormalWaterInfoDataForecast>(json['forecast']);
	if (forecast != null) {
		normalWaterInfoData.forecast = forecast;
	}
	final NormalWaterInfoDataYesterday? yesterday = jsonConvert.convert<NormalWaterInfoDataYesterday>(json['yesterday']);
	if (yesterday != null) {
		normalWaterInfoData.yesterday = yesterday;
	}
	return normalWaterInfoData;
}

Map<String, dynamic> $NormalWaterInfoDataToJson(NormalWaterInfoData entity) {
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

NormalWaterInfoDataForecast $NormalWaterInfoDataForecastFromJson(Map<String, dynamic> json) {
	final NormalWaterInfoDataForecast normalWaterInfoDataForecast = NormalWaterInfoDataForecast();
	final String? date = jsonConvert.convert<String>(json['date']);
	if (date != null) {
		normalWaterInfoDataForecast.date = date;
	}
	final String? high = jsonConvert.convert<String>(json['high']);
	if (high != null) {
		normalWaterInfoDataForecast.high = high;
	}
	final String? low = jsonConvert.convert<String>(json['low']);
	if (low != null) {
		normalWaterInfoDataForecast.low = low;
	}
	final String? ymd = jsonConvert.convert<String>(json['ymd']);
	if (ymd != null) {
		normalWaterInfoDataForecast.ymd = ymd;
	}
	final String? week = jsonConvert.convert<String>(json['week']);
	if (week != null) {
		normalWaterInfoDataForecast.week = week;
	}
	final String? sunrise = jsonConvert.convert<String>(json['sunrise']);
	if (sunrise != null) {
		normalWaterInfoDataForecast.sunrise = sunrise;
	}
	final String? sunset = jsonConvert.convert<String>(json['sunset']);
	if (sunset != null) {
		normalWaterInfoDataForecast.sunset = sunset;
	}
	final int? aqi = jsonConvert.convert<int>(json['aqi']);
	if (aqi != null) {
		normalWaterInfoDataForecast.aqi = aqi;
	}
	final String? fx = jsonConvert.convert<String>(json['fx']);
	if (fx != null) {
		normalWaterInfoDataForecast.fx = fx;
	}
	final String? fl = jsonConvert.convert<String>(json['fl']);
	if (fl != null) {
		normalWaterInfoDataForecast.fl = fl;
	}
	final String? type = jsonConvert.convert<String>(json['type']);
	if (type != null) {
		normalWaterInfoDataForecast.type = type;
	}
	final String? notice = jsonConvert.convert<String>(json['notice']);
	if (notice != null) {
		normalWaterInfoDataForecast.notice = notice;
	}
	return normalWaterInfoDataForecast;
}

Map<String, dynamic> $NormalWaterInfoDataForecastToJson(NormalWaterInfoDataForecast entity) {
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

NormalWaterInfoDataYesterday $NormalWaterInfoDataYesterdayFromJson(Map<String, dynamic> json) {
	final NormalWaterInfoDataYesterday normalWaterInfoDataYesterday = NormalWaterInfoDataYesterday();
	final String? date = jsonConvert.convert<String>(json['date']);
	if (date != null) {
		normalWaterInfoDataYesterday.date = date;
	}
	final String? high = jsonConvert.convert<String>(json['high']);
	if (high != null) {
		normalWaterInfoDataYesterday.high = high;
	}
	final String? low = jsonConvert.convert<String>(json['low']);
	if (low != null) {
		normalWaterInfoDataYesterday.low = low;
	}
	final String? ymd = jsonConvert.convert<String>(json['ymd']);
	if (ymd != null) {
		normalWaterInfoDataYesterday.ymd = ymd;
	}
	final String? week = jsonConvert.convert<String>(json['week']);
	if (week != null) {
		normalWaterInfoDataYesterday.week = week;
	}
	final String? sunrise = jsonConvert.convert<String>(json['sunrise']);
	if (sunrise != null) {
		normalWaterInfoDataYesterday.sunrise = sunrise;
	}
	final String? sunset = jsonConvert.convert<String>(json['sunset']);
	if (sunset != null) {
		normalWaterInfoDataYesterday.sunset = sunset;
	}
	final int? aqi = jsonConvert.convert<int>(json['aqi']);
	if (aqi != null) {
		normalWaterInfoDataYesterday.aqi = aqi;
	}
	final String? fx = jsonConvert.convert<String>(json['fx']);
	if (fx != null) {
		normalWaterInfoDataYesterday.fx = fx;
	}
	final String? fl = jsonConvert.convert<String>(json['fl']);
	if (fl != null) {
		normalWaterInfoDataYesterday.fl = fl;
	}
	final String? type = jsonConvert.convert<String>(json['type']);
	if (type != null) {
		normalWaterInfoDataYesterday.type = type;
	}
	final String? notice = jsonConvert.convert<String>(json['notice']);
	if (notice != null) {
		normalWaterInfoDataYesterday.notice = notice;
	}
	return normalWaterInfoDataYesterday;
}

Map<String, dynamic> $NormalWaterInfoDataYesterdayToJson(NormalWaterInfoDataYesterday entity) {
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