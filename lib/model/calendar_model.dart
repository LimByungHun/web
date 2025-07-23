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
