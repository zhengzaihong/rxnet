// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'dart:convert';

import 'package:flutter/cupertino.dart';

void main() {
  final map = <String, String>{};
  map['test'] = 'test';
  map['test2'] = 'test2';
  map['test3'] = 'test3';
  map['test4'] = 'test4';

  final list = ["test","test4","test4","test4"];

  map.removeWhere((key, value) => list.contains(key));

  debugPrint('-----map:${jsonEncode(map)}');
}
