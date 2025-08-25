// message : "success感谢又拍云(upyun.com)提供CDN赞助"
// status : 200
// date : "20241230"
// time : "2024-12-30 16:40:54"
// cityInfo : {"city":"天津市","citykey":"101030100","parent":"天津","updateTime":"15:13"}
// data : {"shidu":"16%","pm25":11.0,"pm10":61.0,"quality":"良","wendu":"1.7","ganmao":"极少数敏感人群应减少户外活动","forecast":[{"date":"30","high":"高温 8℃","low":"低温 -6℃","ymd":"2024-12-30","week":"星期一","sunrise":"07:29","sunset":"16:57","aqi":46,"fx":"西北风","fl":"3级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"31","high":"高温 5℃","low":"低温 -3℃","ymd":"2024-12-31","week":"星期二","sunrise":"07:30","sunset":"16:58","aqi":54,"fx":"西风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"01","high":"高温 5℃","low":"低温 -4℃","ymd":"2025-01-01","week":"星期三","sunrise":"07:30","sunset":"16:59","aqi":59,"fx":"东北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"02","high":"高温 2℃","low":"低温 -2℃","ymd":"2025-01-02","week":"星期四","sunrise":"07:30","sunset":"17:00","aqi":50,"fx":"东北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"03","high":"高温 4℃","low":"低温 -5℃","ymd":"2025-01-03","week":"星期五","sunrise":"07:30","sunset":"17:00","aqi":65,"fx":"西风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"04","high":"高温 5℃","low":"低温 -5℃","ymd":"2025-01-04","week":"星期六","sunrise":"07:30","sunset":"17:01","aqi":86,"fx":"西南风","fl":"1级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"05","high":"高温 7℃","low":"低温 -2℃","ymd":"2025-01-05","week":"星期日","sunrise":"07:30","sunset":"17:02","aqi":75,"fx":"东北风","fl":"2级","type":"小雪","notice":"小雪虽美，赏雪别着凉"},{"date":"06","high":"高温 7℃","low":"低温 -2℃","ymd":"2025-01-06","week":"星期一","sunrise":"07:30","sunset":"17:03","aqi":31,"fx":"西北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"07","high":"高温 6℃","low":"低温 -2℃","ymd":"2025-01-07","week":"星期二","sunrise":"07:30","sunset":"17:04","aqi":32,"fx":"西北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"08","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-08","week":"星期三","sunrise":"07:30","sunset":"17:05","aqi":52,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"09","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-09","week":"星期四","sunrise":"07:30","sunset":"17:06","aqi":87,"fx":"西南风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"10","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-10","week":"星期五","sunrise":"07:29","sunset":"17:07","aqi":49,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"11","high":"高温 4℃","low":"低温 -2℃","ymd":"2025-01-11","week":"星期六","sunrise":"07:29","sunset":"17:08","aqi":46,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"12","high":"高温 3℃","low":"低温 -3℃","ymd":"2025-01-12","week":"星期日","sunrise":"07:29","sunset":"17:09","aqi":40,"fx":"西北风","fl":"3级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"13","high":"高温 3℃","low":"低温 -5℃","ymd":"2025-01-13","week":"星期一","sunrise":"07:29","sunset":"17:10","aqi":68,"fx":"南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"}],"yesterday":{"date":"29","high":"高温 6℃","low":"低温 -5℃","ymd":"2024-12-29","week":"星期日","sunrise":"07:29","sunset":"16:56","aqi":100,"fx":"西南风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"}}

class NewWeatherInfo {
  NewWeatherInfo({
      this.message, 
      this.status, 
      this.date, 
      this.time, 
      this.cityInfo, 
      this.data,});

  NewWeatherInfo.fromJson(Map<String, dynamic> json) {
    message = json['message'];
    status = json['status'];
    date = json['date'];
    time = json['time'];
    cityInfo = json['cityInfo'] != null ? CityInfo.fromJson(json['cityInfo']) : null;
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }
  String? message;
  num? status;
  String? date;
  String? time;
  CityInfo? cityInfo;
  Data? data;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['message'] = message;
    map['status'] = status;
    map['date'] = date;
    map['time'] = time;
    if (cityInfo != null) {
      map['cityInfo'] = cityInfo?.toJson();
    }
    if (data != null) {
      map['data'] = data?.toJson();
    }
    return map;
  }

}

//shidu : "16%"
//pm25 : 11.0
//pm10 : 61.0
//quality : "良"
//wendu : "1.7"
//ganmao : "极少数敏感人群应减少户外活动"
//forecast : [{"date":"30","high":"高温 8℃","low":"低温 -6℃","ymd":"2024-12-30","week":"星期一","sunrise":"07:29","sunset":"16:57","aqi":46,"fx":"西北风","fl":"3级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"31","high":"高温 5℃","low":"低温 -3℃","ymd":"2024-12-31","week":"星期二","sunrise":"07:30","sunset":"16:58","aqi":54,"fx":"西风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"01","high":"高温 5℃","low":"低温 -4℃","ymd":"2025-01-01","week":"星期三","sunrise":"07:30","sunset":"16:59","aqi":59,"fx":"东北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"02","high":"高温 2℃","low":"低温 -2℃","ymd":"2025-01-02","week":"星期四","sunrise":"07:30","sunset":"17:00","aqi":50,"fx":"东北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"03","high":"高温 4℃","low":"低温 -5℃","ymd":"2025-01-03","week":"星期五","sunrise":"07:30","sunset":"17:00","aqi":65,"fx":"西风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"04","high":"高温 5℃","low":"低温 -5℃","ymd":"2025-01-04","week":"星期六","sunrise":"07:30","sunset":"17:01","aqi":86,"fx":"西南风","fl":"1级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"05","high":"高温 7℃","low":"低温 -2℃","ymd":"2025-01-05","week":"星期日","sunrise":"07:30","sunset":"17:02","aqi":75,"fx":"东北风","fl":"2级","type":"小雪","notice":"小雪虽美，赏雪别着凉"},{"date":"06","high":"高温 7℃","low":"低温 -2℃","ymd":"2025-01-06","week":"星期一","sunrise":"07:30","sunset":"17:03","aqi":31,"fx":"西北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"07","high":"高温 6℃","low":"低温 -2℃","ymd":"2025-01-07","week":"星期二","sunrise":"07:30","sunset":"17:04","aqi":32,"fx":"西北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"08","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-08","week":"星期三","sunrise":"07:30","sunset":"17:05","aqi":52,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"09","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-09","week":"星期四","sunrise":"07:30","sunset":"17:06","aqi":87,"fx":"西南风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"10","high":"高温 3℃","low":"低温 -4℃","ymd":"2025-01-10","week":"星期五","sunrise":"07:29","sunset":"17:07","aqi":49,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"11","high":"高温 4℃","low":"低温 -2℃","ymd":"2025-01-11","week":"星期六","sunrise":"07:29","sunset":"17:08","aqi":46,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"12","high":"高温 3℃","low":"低温 -3℃","ymd":"2025-01-12","week":"星期日","sunrise":"07:29","sunset":"17:09","aqi":40,"fx":"西北风","fl":"3级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"13","high":"高温 3℃","low":"低温 -5℃","ymd":"2025-01-13","week":"星期一","sunrise":"07:29","sunset":"17:10","aqi":68,"fx":"南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"}]
//yesterday : {"date":"29","high":"高温 6℃","low":"低温 -5℃","ymd":"2024-12-29","week":"星期日","sunrise":"07:29","sunset":"16:56","aqi":100,"fx":"西南风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"}

class Data {
  Data({
      this.shidu, 
      this.pm25, 
      this.pm10, 
      this.quality, 
      this.wendu, 
      this.ganmao, 
      this.forecast, 
      this.yesterday,});

  Data.fromJson(dynamic json) {
    shidu = json['shidu'];
    pm25 = json['pm25'];
    pm10 = json['pm10'];
    quality = json['quality'];
    wendu = json['wendu'];
    ganmao = json['ganmao'];
    if (json['forecast'] != null) {
      forecast = [];
      json['forecast'].forEach((v) {
        forecast?.add(Forecast.fromJson(v));
      });
    }
    yesterday = json['yesterday'] != null ? Yesterday.fromJson(json['yesterday']) : null;
  }
  String? shidu;
  num? pm25;
  num? pm10;
  String? quality;
  String? wendu;
  String? ganmao;
  List<Forecast>? forecast;
  Yesterday? yesterday;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['shidu'] = shidu;
    map['pm25'] = pm25;
    map['pm10'] = pm10;
    map['quality'] = quality;
    map['wendu'] = wendu;
    map['ganmao'] = ganmao;
    if (forecast != null) {
      map['forecast'] = forecast?.map((v) => v.toJson()).toList();
    }
    if (yesterday != null) {
      map['yesterday'] = yesterday?.toJson();
    }
    return map;
  }

}

//date : "29"
//high : "高温 6℃"
//low : "低温 -5℃"
//ymd : "2024-12-29"
//week : "星期日"
//sunrise : "07:29"
//sunset : "16:56"
//aqi : 100
//fx : "西南风"
//fl : "2级"
//type : "多云"
//notice : "阴晴之间，谨防紫外线侵扰"

class Yesterday {
  Yesterday({
      this.date, 
      this.high, 
      this.low, 
      this.ymd, 
      this.week, 
      this.sunrise, 
      this.sunset, 
      this.aqi, 
      this.fx, 
      this.fl, 
      this.type, 
      this.notice,});

  Yesterday.fromJson(dynamic json) {
    date = json['date'];
    high = json['high'];
    low = json['low'];
    ymd = json['ymd'];
    week = json['week'];
    sunrise = json['sunrise'];
    sunset = json['sunset'];
    aqi = json['aqi'];
    fx = json['fx'];
    fl = json['fl'];
    type = json['type'];
    notice = json['notice'];
  }
  String? date;
  String? high;
  String? low;
  String? ymd;
  String? week;
  String? sunrise;
  String? sunset;
  num? aqi;
  String? fx;
  String? fl;
  String? type;
  String? notice;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['date'] = date;
    map['high'] = high;
    map['low'] = low;
    map['ymd'] = ymd;
    map['week'] = week;
    map['sunrise'] = sunrise;
    map['sunset'] = sunset;
    map['aqi'] = aqi;
    map['fx'] = fx;
    map['fl'] = fl;
    map['type'] = type;
    map['notice'] = notice;
    return map;
  }

}

//date : "30"
//high : "高温 8℃"
//low : "低温 -6℃"
//ymd : "2024-12-30"
//week : "星期一"
//sunrise : "07:29"
//sunset : "16:57"
//aqi : 46
//fx : "西北风"
//fl : "3级"
//type : "晴"
//notice : "愿你拥有比阳光明媚的心情"

class Forecast {
  Forecast({
      this.date, 
      this.high, 
      this.low, 
      this.ymd, 
      this.week, 
      this.sunrise, 
      this.sunset, 
      this.aqi, 
      this.fx, 
      this.fl, 
      this.type, 
      this.notice,});

  Forecast.fromJson(dynamic json) {
    date = json['date'];
    high = json['high'];
    low = json['low'];
    ymd = json['ymd'];
    week = json['week'];
    sunrise = json['sunrise'];
    sunset = json['sunset'];
    aqi = json['aqi'];
    fx = json['fx'];
    fl = json['fl'];
    type = json['type'];
    notice = json['notice'];
  }
  String? date;
  String? high;
  String? low;
  String? ymd;
  String? week;
  String? sunrise;
  String? sunset;
  num? aqi;
  String? fx;
  String? fl;
  String? type;
  String? notice;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['date'] = date;
    map['high'] = high;
    map['low'] = low;
    map['ymd'] = ymd;
    map['week'] = week;
    map['sunrise'] = sunrise;
    map['sunset'] = sunset;
    map['aqi'] = aqi;
    map['fx'] = fx;
    map['fl'] = fl;
    map['type'] = type;
    map['notice'] = notice;
    return map;
  }

}

//city : "天津市"
//citykey : "101030100"
//parent : "天津"
//updateTime : "15:13"

class CityInfo {
  CityInfo({
      this.city, 
      this.citykey, 
      this.parent, 
      this.updateTime,});

  CityInfo.fromJson(dynamic json) {
    city = json['city'];
    citykey = json['citykey'];
    parent = json['parent'];
    updateTime = json['updateTime'];
  }
  String? city;
  String? citykey;
  String? parent;
  String? updateTime;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['city'] = city;
    map['citykey'] = citykey;
    map['parent'] = parent;
    map['updateTime'] = updateTime;
    return map;
  }

}