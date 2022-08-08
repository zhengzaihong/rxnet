import 'package:rxnet/generated/json/base/json_field.dart';
import 'package:rxnet/generated/json/test_json_convert_entity.g.dart';
import 'dart:convert';


@JsonSerializable()
class TestJsonConvertEntity{

	List<TestJsonConvertList>? list;
	String? pageId;
	int? totalNum;
  
  TestJsonConvertEntity();

  factory TestJsonConvertEntity.fromJson(Map<String, dynamic> json) => $TestJsonConvertEntityFromJson(json);

  Map<String, dynamic> toJson() => $TestJsonConvertEntityToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}

@JsonSerializable()
class TestJsonConvertList {

	int? id;
	String? goodsId;
	String? title;
	String? dtitle;
	double? originalPrice;
	double? actualPrice;
	int? shopType;
	int? monthSales;
	int? twoHoursSales;
	int? dailySales;
	int? commissionType;
	int? commissionRate;
	String? desc;
	int? couponReceiveNum;
	int? couponTotalNum;
	int? couponRemainCount;
	String? couponLink;
	String? couponId;
	String? couponEndTime;
	String? couponStartTime;
	int? couponPrice;
	String? couponConditions;
	int? cpaRewardAmount;
	int? activityType;
	String? activityStartTime;
	String? activityEndTime;
	String? shopName;
	int? shopLevel;
	double? descScore;
	double? dsrScore;
	int? dsrPercent;
	double? shipScore;
	double? shipPercent;
	double? serviceScore;
	double? servicePercent;
	int? brand;
	int? brandId;
	String? brandName;
	int? hotPush;
	String? teamName;
	String? itemLink;
	int? quanMLink;
	int? hzQuanOver;
	int? yunfeixian;
	int? estimateAmount;
	int? freeshipRemoteDistrict;
	int? discountType;
	int? discountFull;
	int? discountCut;
	double? discounts;
	List<dynamic>? marketGroup;
	List<dynamic>? activityInfo;
	int? inspectedGoods;
	int? divisor;
	String? mainPic;
	String? marketingMainPic;
	String? sellerId;
	String? activityId;
	int? cid;
	int? tbcid;
	List<int>? subcid;
	int? haitao;
	int? tchaoshi;
	int? lowest;
	int? goldSellers;
	List<dynamic>? specialText;
	List<dynamic>? smallImages;
	String? createTime;
	String? shopLogo;
  
  TestJsonConvertList();

  factory TestJsonConvertList.fromJson(Map<String, dynamic> json) => $TestJsonConvertListFromJson(json);

  Map<String, dynamic> toJson() => $TestJsonConvertListToJson(this);

  @override
  String toString() {
    return jsonEncode(this);
  }
}