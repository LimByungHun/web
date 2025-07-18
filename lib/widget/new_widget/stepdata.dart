import 'package:flutter/material.dart';

/// 1. 한 스텝 단위: 제목 + 실제 표시할 위젯
class StepData {
  final String title;
  final Widget widget;
  StepData({required this.title, required this.widget});
}
