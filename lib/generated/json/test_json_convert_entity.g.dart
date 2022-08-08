import 'package:rxnet/generated/json/base/json_convert_content.dart';
import 'package:rxnet/test/test_json_convert_entity.dart';

TestJsonConvertEntity $TestJsonConvertEntityFromJson(Map<String, dynamic> json) {
	final TestJsonConvertEntity testJsonConvertEntity = TestJsonConvertEntity();
	final List<TestJsonConvertList>? list = jsonConvert.convertListNotNull<TestJsonConvertList>(json['list']);
	if (list != null) {
		testJsonConvertEntity.list = list;
	}
	final String? pageId = jsonConvert.convert<String>(json['pageId']);
	if (pageId != null) {
		testJsonConvertEntity.pageId = pageId;
	}
	final int? totalNum = jsonConvert.convert<int>(json['totalNum']);
	if (totalNum != null) {
		testJsonConvertEntity.totalNum = totalNum;
	}
	return testJsonConvertEntity;
}

Map<String, dynamic> $TestJsonConvertEntityToJson(TestJsonConvertEntity entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['list'] =  entity.list?.map((v) => v.toJson()).toList();
	data['pageId'] = entity.pageId;
	data['totalNum'] = entity.totalNum;
	return data;
}

TestJsonConvertList $TestJsonConvertListFromJson(Map<String, dynamic> json) {
	final TestJsonConvertList testJsonConvertList = TestJsonConvertList();
	final int? id = jsonConvert.convert<int>(json['id']);
	if (id != null) {
		testJsonConvertList.id = id;
	}
	final String? goodsId = jsonConvert.convert<String>(json['goodsId']);
	if (goodsId != null) {
		testJsonConvertList.goodsId = goodsId;
	}
	final String? title = jsonConvert.convert<String>(json['title']);
	if (title != null) {
		testJsonConvertList.title = title;
	}
	final String? dtitle = jsonConvert.convert<String>(json['dtitle']);
	if (dtitle != null) {
		testJsonConvertList.dtitle = dtitle;
	}
	final double? originalPrice = jsonConvert.convert<double>(json['originalPrice']);
	if (originalPrice != null) {
		testJsonConvertList.originalPrice = originalPrice;
	}
	final double? actualPrice = jsonConvert.convert<double>(json['actualPrice']);
	if (actualPrice != null) {
		testJsonConvertList.actualPrice = actualPrice;
	}
	final int? shopType = jsonConvert.convert<int>(json['shopType']);
	if (shopType != null) {
		testJsonConvertList.shopType = shopType;
	}
	final int? monthSales = jsonConvert.convert<int>(json['monthSales']);
	if (monthSales != null) {
		testJsonConvertList.monthSales = monthSales;
	}
	final int? twoHoursSales = jsonConvert.convert<int>(json['twoHoursSales']);
	if (twoHoursSales != null) {
		testJsonConvertList.twoHoursSales = twoHoursSales;
	}
	final int? dailySales = jsonConvert.convert<int>(json['dailySales']);
	if (dailySales != null) {
		testJsonConvertList.dailySales = dailySales;
	}
	final int? commissionType = jsonConvert.convert<int>(json['commissionType']);
	if (commissionType != null) {
		testJsonConvertList.commissionType = commissionType;
	}
	final int? commissionRate = jsonConvert.convert<int>(json['commissionRate']);
	if (commissionRate != null) {
		testJsonConvertList.commissionRate = commissionRate;
	}
	final String? desc = jsonConvert.convert<String>(json['desc']);
	if (desc != null) {
		testJsonConvertList.desc = desc;
	}
	final int? couponReceiveNum = jsonConvert.convert<int>(json['couponReceiveNum']);
	if (couponReceiveNum != null) {
		testJsonConvertList.couponReceiveNum = couponReceiveNum;
	}
	final int? couponTotalNum = jsonConvert.convert<int>(json['couponTotalNum']);
	if (couponTotalNum != null) {
		testJsonConvertList.couponTotalNum = couponTotalNum;
	}
	final int? couponRemainCount = jsonConvert.convert<int>(json['couponRemainCount']);
	if (couponRemainCount != null) {
		testJsonConvertList.couponRemainCount = couponRemainCount;
	}
	final String? couponLink = jsonConvert.convert<String>(json['couponLink']);
	if (couponLink != null) {
		testJsonConvertList.couponLink = couponLink;
	}
	final String? couponId = jsonConvert.convert<String>(json['couponId']);
	if (couponId != null) {
		testJsonConvertList.couponId = couponId;
	}
	final String? couponEndTime = jsonConvert.convert<String>(json['couponEndTime']);
	if (couponEndTime != null) {
		testJsonConvertList.couponEndTime = couponEndTime;
	}
	final String? couponStartTime = jsonConvert.convert<String>(json['couponStartTime']);
	if (couponStartTime != null) {
		testJsonConvertList.couponStartTime = couponStartTime;
	}
	final int? couponPrice = jsonConvert.convert<int>(json['couponPrice']);
	if (couponPrice != null) {
		testJsonConvertList.couponPrice = couponPrice;
	}
	final String? couponConditions = jsonConvert.convert<String>(json['couponConditions']);
	if (couponConditions != null) {
		testJsonConvertList.couponConditions = couponConditions;
	}
	final int? cpaRewardAmount = jsonConvert.convert<int>(json['cpaRewardAmount']);
	if (cpaRewardAmount != null) {
		testJsonConvertList.cpaRewardAmount = cpaRewardAmount;
	}
	final int? activityType = jsonConvert.convert<int>(json['activityType']);
	if (activityType != null) {
		testJsonConvertList.activityType = activityType;
	}
	final String? activityStartTime = jsonConvert.convert<String>(json['activityStartTime']);
	if (activityStartTime != null) {
		testJsonConvertList.activityStartTime = activityStartTime;
	}
	final String? activityEndTime = jsonConvert.convert<String>(json['activityEndTime']);
	if (activityEndTime != null) {
		testJsonConvertList.activityEndTime = activityEndTime;
	}
	final String? shopName = jsonConvert.convert<String>(json['shopName']);
	if (shopName != null) {
		testJsonConvertList.shopName = shopName;
	}
	final int? shopLevel = jsonConvert.convert<int>(json['shopLevel']);
	if (shopLevel != null) {
		testJsonConvertList.shopLevel = shopLevel;
	}
	final double? descScore = jsonConvert.convert<double>(json['descScore']);
	if (descScore != null) {
		testJsonConvertList.descScore = descScore;
	}
	final double? dsrScore = jsonConvert.convert<double>(json['dsrScore']);
	if (dsrScore != null) {
		testJsonConvertList.dsrScore = dsrScore;
	}
	final int? dsrPercent = jsonConvert.convert<int>(json['dsrPercent']);
	if (dsrPercent != null) {
		testJsonConvertList.dsrPercent = dsrPercent;
	}
	final double? shipScore = jsonConvert.convert<double>(json['shipScore']);
	if (shipScore != null) {
		testJsonConvertList.shipScore = shipScore;
	}
	final double? shipPercent = jsonConvert.convert<double>(json['shipPercent']);
	if (shipPercent != null) {
		testJsonConvertList.shipPercent = shipPercent;
	}
	final double? serviceScore = jsonConvert.convert<double>(json['serviceScore']);
	if (serviceScore != null) {
		testJsonConvertList.serviceScore = serviceScore;
	}
	final double? servicePercent = jsonConvert.convert<double>(json['servicePercent']);
	if (servicePercent != null) {
		testJsonConvertList.servicePercent = servicePercent;
	}
	final int? brand = jsonConvert.convert<int>(json['brand']);
	if (brand != null) {
		testJsonConvertList.brand = brand;
	}
	final int? brandId = jsonConvert.convert<int>(json['brandId']);
	if (brandId != null) {
		testJsonConvertList.brandId = brandId;
	}
	final String? brandName = jsonConvert.convert<String>(json['brandName']);
	if (brandName != null) {
		testJsonConvertList.brandName = brandName;
	}
	final int? hotPush = jsonConvert.convert<int>(json['hotPush']);
	if (hotPush != null) {
		testJsonConvertList.hotPush = hotPush;
	}
	final String? teamName = jsonConvert.convert<String>(json['teamName']);
	if (teamName != null) {
		testJsonConvertList.teamName = teamName;
	}
	final String? itemLink = jsonConvert.convert<String>(json['itemLink']);
	if (itemLink != null) {
		testJsonConvertList.itemLink = itemLink;
	}
	final int? quanMLink = jsonConvert.convert<int>(json['quanMLink']);
	if (quanMLink != null) {
		testJsonConvertList.quanMLink = quanMLink;
	}
	final int? hzQuanOver = jsonConvert.convert<int>(json['hzQuanOver']);
	if (hzQuanOver != null) {
		testJsonConvertList.hzQuanOver = hzQuanOver;
	}
	final int? yunfeixian = jsonConvert.convert<int>(json['yunfeixian']);
	if (yunfeixian != null) {
		testJsonConvertList.yunfeixian = yunfeixian;
	}
	final int? estimateAmount = jsonConvert.convert<int>(json['estimateAmount']);
	if (estimateAmount != null) {
		testJsonConvertList.estimateAmount = estimateAmount;
	}
	final int? freeshipRemoteDistrict = jsonConvert.convert<int>(json['freeshipRemoteDistrict']);
	if (freeshipRemoteDistrict != null) {
		testJsonConvertList.freeshipRemoteDistrict = freeshipRemoteDistrict;
	}
	final int? discountType = jsonConvert.convert<int>(json['discountType']);
	if (discountType != null) {
		testJsonConvertList.discountType = discountType;
	}
	final int? discountFull = jsonConvert.convert<int>(json['discountFull']);
	if (discountFull != null) {
		testJsonConvertList.discountFull = discountFull;
	}
	final int? discountCut = jsonConvert.convert<int>(json['discountCut']);
	if (discountCut != null) {
		testJsonConvertList.discountCut = discountCut;
	}
	final double? discounts = jsonConvert.convert<double>(json['discounts']);
	if (discounts != null) {
		testJsonConvertList.discounts = discounts;
	}
	final List<dynamic>? marketGroup = jsonConvert.convertListNotNull<dynamic>(json['marketGroup']);
	if (marketGroup != null) {
		testJsonConvertList.marketGroup = marketGroup;
	}
	final List<dynamic>? activityInfo = jsonConvert.convertListNotNull<dynamic>(json['activityInfo']);
	if (activityInfo != null) {
		testJsonConvertList.activityInfo = activityInfo;
	}
	final int? inspectedGoods = jsonConvert.convert<int>(json['inspectedGoods']);
	if (inspectedGoods != null) {
		testJsonConvertList.inspectedGoods = inspectedGoods;
	}
	final int? divisor = jsonConvert.convert<int>(json['divisor']);
	if (divisor != null) {
		testJsonConvertList.divisor = divisor;
	}
	final String? mainPic = jsonConvert.convert<String>(json['mainPic']);
	if (mainPic != null) {
		testJsonConvertList.mainPic = mainPic;
	}
	final String? marketingMainPic = jsonConvert.convert<String>(json['marketingMainPic']);
	if (marketingMainPic != null) {
		testJsonConvertList.marketingMainPic = marketingMainPic;
	}
	final String? sellerId = jsonConvert.convert<String>(json['sellerId']);
	if (sellerId != null) {
		testJsonConvertList.sellerId = sellerId;
	}
	final String? activityId = jsonConvert.convert<String>(json['activityId']);
	if (activityId != null) {
		testJsonConvertList.activityId = activityId;
	}
	final int? cid = jsonConvert.convert<int>(json['cid']);
	if (cid != null) {
		testJsonConvertList.cid = cid;
	}
	final int? tbcid = jsonConvert.convert<int>(json['tbcid']);
	if (tbcid != null) {
		testJsonConvertList.tbcid = tbcid;
	}
	final List<int>? subcid = jsonConvert.convertListNotNull<int>(json['subcid']);
	if (subcid != null) {
		testJsonConvertList.subcid = subcid;
	}
	final int? haitao = jsonConvert.convert<int>(json['haitao']);
	if (haitao != null) {
		testJsonConvertList.haitao = haitao;
	}
	final int? tchaoshi = jsonConvert.convert<int>(json['tchaoshi']);
	if (tchaoshi != null) {
		testJsonConvertList.tchaoshi = tchaoshi;
	}
	final int? lowest = jsonConvert.convert<int>(json['lowest']);
	if (lowest != null) {
		testJsonConvertList.lowest = lowest;
	}
	final int? goldSellers = jsonConvert.convert<int>(json['goldSellers']);
	if (goldSellers != null) {
		testJsonConvertList.goldSellers = goldSellers;
	}
	final List<dynamic>? specialText = jsonConvert.convertListNotNull<dynamic>(json['specialText']);
	if (specialText != null) {
		testJsonConvertList.specialText = specialText;
	}
	final List<dynamic>? smallImages = jsonConvert.convertListNotNull<dynamic>(json['smallImages']);
	if (smallImages != null) {
		testJsonConvertList.smallImages = smallImages;
	}
	final String? createTime = jsonConvert.convert<String>(json['createTime']);
	if (createTime != null) {
		testJsonConvertList.createTime = createTime;
	}
	final String? shopLogo = jsonConvert.convert<String>(json['shopLogo']);
	if (shopLogo != null) {
		testJsonConvertList.shopLogo = shopLogo;
	}
	return testJsonConvertList;
}

Map<String, dynamic> $TestJsonConvertListToJson(TestJsonConvertList entity) {
	final Map<String, dynamic> data = <String, dynamic>{};
	data['id'] = entity.id;
	data['goodsId'] = entity.goodsId;
	data['title'] = entity.title;
	data['dtitle'] = entity.dtitle;
	data['originalPrice'] = entity.originalPrice;
	data['actualPrice'] = entity.actualPrice;
	data['shopType'] = entity.shopType;
	data['monthSales'] = entity.monthSales;
	data['twoHoursSales'] = entity.twoHoursSales;
	data['dailySales'] = entity.dailySales;
	data['commissionType'] = entity.commissionType;
	data['commissionRate'] = entity.commissionRate;
	data['desc'] = entity.desc;
	data['couponReceiveNum'] = entity.couponReceiveNum;
	data['couponTotalNum'] = entity.couponTotalNum;
	data['couponRemainCount'] = entity.couponRemainCount;
	data['couponLink'] = entity.couponLink;
	data['couponId'] = entity.couponId;
	data['couponEndTime'] = entity.couponEndTime;
	data['couponStartTime'] = entity.couponStartTime;
	data['couponPrice'] = entity.couponPrice;
	data['couponConditions'] = entity.couponConditions;
	data['cpaRewardAmount'] = entity.cpaRewardAmount;
	data['activityType'] = entity.activityType;
	data['activityStartTime'] = entity.activityStartTime;
	data['activityEndTime'] = entity.activityEndTime;
	data['shopName'] = entity.shopName;
	data['shopLevel'] = entity.shopLevel;
	data['descScore'] = entity.descScore;
	data['dsrScore'] = entity.dsrScore;
	data['dsrPercent'] = entity.dsrPercent;
	data['shipScore'] = entity.shipScore;
	data['shipPercent'] = entity.shipPercent;
	data['serviceScore'] = entity.serviceScore;
	data['servicePercent'] = entity.servicePercent;
	data['brand'] = entity.brand;
	data['brandId'] = entity.brandId;
	data['brandName'] = entity.brandName;
	data['hotPush'] = entity.hotPush;
	data['teamName'] = entity.teamName;
	data['itemLink'] = entity.itemLink;
	data['quanMLink'] = entity.quanMLink;
	data['hzQuanOver'] = entity.hzQuanOver;
	data['yunfeixian'] = entity.yunfeixian;
	data['estimateAmount'] = entity.estimateAmount;
	data['freeshipRemoteDistrict'] = entity.freeshipRemoteDistrict;
	data['discountType'] = entity.discountType;
	data['discountFull'] = entity.discountFull;
	data['discountCut'] = entity.discountCut;
	data['discounts'] = entity.discounts;
	data['marketGroup'] =  entity.marketGroup;
	data['activityInfo'] =  entity.activityInfo;
	data['inspectedGoods'] = entity.inspectedGoods;
	data['divisor'] = entity.divisor;
	data['mainPic'] = entity.mainPic;
	data['marketingMainPic'] = entity.marketingMainPic;
	data['sellerId'] = entity.sellerId;
	data['activityId'] = entity.activityId;
	data['cid'] = entity.cid;
	data['tbcid'] = entity.tbcid;
	data['subcid'] =  entity.subcid;
	data['haitao'] = entity.haitao;
	data['tchaoshi'] = entity.tchaoshi;
	data['lowest'] = entity.lowest;
	data['goldSellers'] = entity.goldSellers;
	data['specialText'] =  entity.specialText;
	data['smallImages'] =  entity.smallImages;
	data['createTime'] = entity.createTime;
	data['shopLogo'] = entity.shopLogo;
	return data;
}