/// code : 0
/// msg : "获取成功"
/// data : {"message":"success感谢又拍云(upyun.com)提供CDN赞助","status":200,"date":"20240207","time":"2024-02-07 20:26:47","cityInfo":{"city":"天津市","citykey":"101030100","parent":"天津","updateTime":"18:31"},"data":{"shidu":"31%","pm25":13.0,"pm10":21.0,"quality":"优","wendu":"-1","ganmao":"各类人群可自由活动","forecast":[{"date":"07","high":"高温 5℃","low":"低温 -4℃","ymd":"2024-02-07","week":"星期三","sunrise":"07:11","sunset":"17:38","aqi":35,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"08","high":"高温 5℃","low":"低温 -5℃","ymd":"2024-02-08","week":"星期四","sunrise":"07:10","sunset":"17:39","aqi":62,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"09","high":"高温 7℃","low":"低温 -5℃","ymd":"2024-02-09","week":"星期五","sunrise":"07:09","sunset":"17:40","aqi":64,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"10","high":"高温 5℃","low":"低温 -4℃","ymd":"2024-02-10","week":"星期六","sunrise":"07:08","sunset":"17:41","aqi":68,"fx":"北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"11","high":"高温 10℃","low":"低温 -4℃","ymd":"2024-02-11","week":"星期日","sunrise":"07:07","sunset":"17:42","aqi":58,"fx":"西南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"12","high":"高温 11℃","low":"低温 -2℃","ymd":"2024-02-12","week":"星期一","sunrise":"07:06","sunset":"17:44","aqi":60,"fx":"西南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"13","high":"高温 12℃","low":"低温 0℃","ymd":"2024-02-13","week":"星期二","sunrise":"07:05","sunset":"17:45","aqi":72,"fx":"西南风","fl":"1级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"14","high":"高温 9℃","low":"低温 0℃","ymd":"2024-02-14","week":"星期三","sunrise":"07:03","sunset":"17:46","aqi":40,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"15","high":"高温 4℃","low":"低温 -2℃","ymd":"2024-02-15","week":"星期四","sunrise":"07:02","sunset":"17:47","aqi":46,"fx":"西北风","fl":"4级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"16","high":"高温 8℃","low":"低温 -3℃","ymd":"2024-02-16","week":"星期五","sunrise":"07:01","sunset":"17:48","aqi":38,"fx":"南风","fl":"3级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"17","high":"高温 10℃","low":"低温 3℃","ymd":"2024-02-17","week":"星期六","sunrise":"07:00","sunset":"17:49","aqi":34,"fx":"东风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"18","high":"高温 6℃","low":"低温 -1℃","ymd":"2024-02-18","week":"星期日","sunrise":"06:58","sunset":"17:50","aqi":57,"fx":"北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"19","high":"高温 3℃","low":"低温 -5℃","ymd":"2024-02-19","week":"星期一","sunrise":"06:57","sunset":"17:51","aqi":59,"fx":"东风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"20","high":"高温 3℃","low":"低温 -5℃","ymd":"2024-02-20","week":"星期二","sunrise":"06:56","sunset":"17:53","aqi":56,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"21","high":"高温 2℃","low":"低温 -6℃","ymd":"2024-02-21","week":"星期三","sunrise":"06:54","sunset":"17:54","aqi":97,"fx":"北风","fl":"2级","type":"霾","notice":"雾霾来袭，戴好口罩再出门"}],"yesterday":{"date":"06","high":"高温 5℃","low":"低温 -7℃","ymd":"2024-02-06","week":"星期二","sunrise":"07:12","sunset":"17:37","aqi":48,"fx":"西北风","fl":"2级","type":"霾","notice":"雾霾来袭，戴好口罩再出门"}}}

class WeatherInfo {
  WeatherInfo({
      this.code, 
      this.msg, 
      this.data,});

  WeatherInfo.fromJson(dynamic json) {
    code = json['code'];
    msg = json['msg'];
    data = json['data'] != null ? Data.fromJson(json['data']) : null;
  }
  num? code;
  String? msg;
  Data? data;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['code'] = code;
    map['msg'] = msg;
    if (data != null) {
      map['data'] = data?.toJson();
    }
    return map;
  }

}

/// message : "success感谢又拍云(upyun.com)提供CDN赞助"
/// status : 200
/// date : "20240207"
/// time : "2024-02-07 20:26:47"
/// cityInfo : {"city":"天津市","citykey":"101030100","parent":"天津","updateTime":"18:31"}
/// data : {"shidu":"31%","pm25":13.0,"pm10":21.0,"quality":"优","wendu":"-1","ganmao":"各类人群可自由活动","forecast":[{"date":"07","high":"高温 5℃","low":"低温 -4℃","ymd":"2024-02-07","week":"星期三","sunrise":"07:11","sunset":"17:38","aqi":35,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"08","high":"高温 5℃","low":"低温 -5℃","ymd":"2024-02-08","week":"星期四","sunrise":"07:10","sunset":"17:39","aqi":62,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"09","high":"高温 7℃","low":"低温 -5℃","ymd":"2024-02-09","week":"星期五","sunrise":"07:09","sunset":"17:40","aqi":64,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"10","high":"高温 5℃","low":"低温 -4℃","ymd":"2024-02-10","week":"星期六","sunrise":"07:08","sunset":"17:41","aqi":68,"fx":"北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"11","high":"高温 10℃","low":"低温 -4℃","ymd":"2024-02-11","week":"星期日","sunrise":"07:07","sunset":"17:42","aqi":58,"fx":"西南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"12","high":"高温 11℃","low":"低温 -2℃","ymd":"2024-02-12","week":"星期一","sunrise":"07:06","sunset":"17:44","aqi":60,"fx":"西南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"13","high":"高温 12℃","low":"低温 0℃","ymd":"2024-02-13","week":"星期二","sunrise":"07:05","sunset":"17:45","aqi":72,"fx":"西南风","fl":"1级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"14","high":"高温 9℃","low":"低温 0℃","ymd":"2024-02-14","week":"星期三","sunrise":"07:03","sunset":"17:46","aqi":40,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"15","high":"高温 4℃","low":"低温 -2℃","ymd":"2024-02-15","week":"星期四","sunrise":"07:02","sunset":"17:47","aqi":46,"fx":"西北风","fl":"4级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"16","high":"高温 8℃","low":"低温 -3℃","ymd":"2024-02-16","week":"星期五","sunrise":"07:01","sunset":"17:48","aqi":38,"fx":"南风","fl":"3级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"17","high":"高温 10℃","low":"低温 3℃","ymd":"2024-02-17","week":"星期六","sunrise":"07:00","sunset":"17:49","aqi":34,"fx":"东风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"18","high":"高温 6℃","low":"低温 -1℃","ymd":"2024-02-18","week":"星期日","sunrise":"06:58","sunset":"17:50","aqi":57,"fx":"北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"19","high":"高温 3℃","low":"低温 -5℃","ymd":"2024-02-19","week":"星期一","sunrise":"06:57","sunset":"17:51","aqi":59,"fx":"东风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"20","high":"高温 3℃","low":"低温 -5℃","ymd":"2024-02-20","week":"星期二","sunrise":"06:56","sunset":"17:53","aqi":56,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"21","high":"高温 2℃","low":"低温 -6℃","ymd":"2024-02-21","week":"星期三","sunrise":"06:54","sunset":"17:54","aqi":97,"fx":"北风","fl":"2级","type":"霾","notice":"雾霾来袭，戴好口罩再出门"}],"yesterday":{"date":"06","high":"高温 5℃","low":"低温 -7℃","ymd":"2024-02-06","week":"星期二","sunrise":"07:12","sunset":"17:37","aqi":48,"fx":"西北风","fl":"2级","type":"霾","notice":"雾霾来袭，戴好口罩再出门"}}

class Data {
  Data({
      this.message, 
      this.status, 
      this.date, 
      this.time, 
      this.cityInfo, 
      this.data,});

  Data.fromJson(dynamic json) {
    message = json['message'];
    status = json['status'];
    date = json['date'];
    time = json['time'];
    cityInfo = json['cityInfo'] != null ? CityInfo.fromJson(json['cityInfo']) : null;
    data = json['data'] != null ? DataPM.fromJson(json['data']) : null;
  }
  String? message;
  num? status;
  String? date;
  String? time;
  CityInfo? cityInfo;
  DataPM? data;

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

/// shidu : "31%"
/// pm25 : 13.0
/// pm10 : 21.0
/// quality : "优"
/// wendu : "-1"
/// ganmao : "各类人群可自由活动"
/// forecast : [{"date":"07","high":"高温 5℃","low":"低温 -4℃","ymd":"2024-02-07","week":"星期三","sunrise":"07:11","sunset":"17:38","aqi":35,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"08","high":"高温 5℃","low":"低温 -5℃","ymd":"2024-02-08","week":"星期四","sunrise":"07:10","sunset":"17:39","aqi":62,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"09","high":"高温 7℃","low":"低温 -5℃","ymd":"2024-02-09","week":"星期五","sunrise":"07:09","sunset":"17:40","aqi":64,"fx":"西北风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"10","high":"高温 5℃","low":"低温 -4℃","ymd":"2024-02-10","week":"星期六","sunrise":"07:08","sunset":"17:41","aqi":68,"fx":"北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"11","high":"高温 10℃","low":"低温 -4℃","ymd":"2024-02-11","week":"星期日","sunrise":"07:07","sunset":"17:42","aqi":58,"fx":"西南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"12","high":"高温 11℃","low":"低温 -2℃","ymd":"2024-02-12","week":"星期一","sunrise":"07:06","sunset":"17:44","aqi":60,"fx":"西南风","fl":"2级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"13","high":"高温 12℃","low":"低温 0℃","ymd":"2024-02-13","week":"星期二","sunrise":"07:05","sunset":"17:45","aqi":72,"fx":"西南风","fl":"1级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"14","high":"高温 9℃","low":"低温 0℃","ymd":"2024-02-14","week":"星期三","sunrise":"07:03","sunset":"17:46","aqi":40,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"15","high":"高温 4℃","low":"低温 -2℃","ymd":"2024-02-15","week":"星期四","sunrise":"07:02","sunset":"17:47","aqi":46,"fx":"西北风","fl":"4级","type":"晴","notice":"愿你拥有比阳光明媚的心情"},{"date":"16","high":"高温 8℃","low":"低温 -3℃","ymd":"2024-02-16","week":"星期五","sunrise":"07:01","sunset":"17:48","aqi":38,"fx":"南风","fl":"3级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"17","high":"高温 10℃","low":"低温 3℃","ymd":"2024-02-17","week":"星期六","sunrise":"07:00","sunset":"17:49","aqi":34,"fx":"东风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"18","high":"高温 6℃","low":"低温 -1℃","ymd":"2024-02-18","week":"星期日","sunrise":"06:58","sunset":"17:50","aqi":57,"fx":"北风","fl":"3级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"19","high":"高温 3℃","low":"低温 -5℃","ymd":"2024-02-19","week":"星期一","sunrise":"06:57","sunset":"17:51","aqi":59,"fx":"东风","fl":"2级","type":"阴","notice":"不要被阴云遮挡住好心情"},{"date":"20","high":"高温 3℃","low":"低温 -5℃","ymd":"2024-02-20","week":"星期二","sunrise":"06:56","sunset":"17:53","aqi":56,"fx":"西北风","fl":"2级","type":"多云","notice":"阴晴之间，谨防紫外线侵扰"},{"date":"21","high":"高温 2℃","low":"低温 -6℃","ymd":"2024-02-21","week":"星期三","sunrise":"06:54","sunset":"17:54","aqi":97,"fx":"北风","fl":"2级","type":"霾","notice":"雾霾来袭，戴好口罩再出门"}]
/// yesterday : {"date":"06","high":"高温 5℃","low":"低温 -7℃","ymd":"2024-02-06","week":"星期二","sunrise":"07:12","sunset":"17:37","aqi":48,"fx":"西北风","fl":"2级","type":"霾","notice":"雾霾来袭，戴好口罩再出门"}

class DataPM {
  DataPM({
      this.shidu, 
      this.pm25, 
      this.pm10, 
      this.quality, 
      this.wendu, 
      this.ganmao, 
      this.forecast, 
      this.yesterday,});

  DataPM.fromJson(dynamic json) {
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

/// date : "06"
/// high : "高温 5℃"
/// low : "低温 -7℃"
/// ymd : "2024-02-06"
/// week : "星期二"
/// sunrise : "07:12"
/// sunset : "17:37"
/// aqi : 48
/// fx : "西北风"
/// fl : "2级"
/// type : "霾"
/// notice : "雾霾来袭，戴好口罩再出门"

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

/// date : "07"
/// high : "高温 5℃"
/// low : "低温 -4℃"
/// ymd : "2024-02-07"
/// week : "星期三"
/// sunrise : "07:11"
/// sunset : "17:38"
/// aqi : 35
/// fx : "西北风"
/// fl : "2级"
/// type : "晴"
/// notice : "愿你拥有比阳光明媚的心情"

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

/// city : "天津市"
/// citykey : "101030100"
/// parent : "天津"
/// updateTime : "18:31"

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