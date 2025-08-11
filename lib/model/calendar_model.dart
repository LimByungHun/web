import 'package:flutter/material.dart';

Widget buildStreakStats({
  required int bestStreakDays,
  required int streakDays,
  required bool isFireActive,
}) {
  final Color iconColor = isFireActive
      ? Colors.pinkAccent
      : Colors.black.withAlpha(100);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        streakInfo("최고 기록", "$bestStreakDays", "불꽃 연속일"),
        Icon(Icons.local_fire_department, color: iconColor, size: 72),
        streakInfo("기록", "$streakDays", "연속 학습일"),
      ],
    ),
  );
}

Widget streakInfo(String label, String number, String description) {
  return Column(
    children: [
      Text(label, style: const TextStyle(color: Colors.pinkAccent)),
      Text(
        number,
        style: const TextStyle(color: Colors.pinkAccent, fontSize: 24),
      ),
      Text(description, style: const TextStyle(color: Colors.grey)),
    ],
  );
}

class DayRecordItem {
  final int sid;
  final String studyCourse; // Study_Course
  final int step;
  final String? stepName; // StepName
  final DateTime studyTime; // Study_Date (ISO8601)
  final bool complete; // Complate

  DayRecordItem({
    required this.sid,
    required this.studyCourse,
    required this.step,
    required this.stepName,
    required this.studyTime,
    required this.complete,
  });

  factory DayRecordItem.fromJson(Map<String, dynamic> json) {
    return DayRecordItem(
      sid: (json['sid'] as num).toInt(),
      studyCourse: json['study_course'] as String,
      step: (json['step'] as num).toInt(),
      stepName: json['step_name'] as String?,
      studyTime: DateTime.parse(json['study_time'] as String),
      complete: json['complete'] as bool? ?? false,
    );
  }
}
