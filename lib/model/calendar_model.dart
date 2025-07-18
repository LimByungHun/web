import 'package:flutter/material.dart';

int calculateCurrentStreak(Set<DateTime> dates) {
  if (dates.isEmpty) return 0;

  final today = DateTime.now();
  DateTime day = DateTime(today.year, today.month, today.day);
  int streak = 0;

  while (dates.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }

  return streak;
}

int calculateLongestStreak(Set<DateTime> dates) {
  if (dates.isEmpty) return 0;

  final sortedDates = dates.toList()..sort((a, b) => a.compareTo(b));

  int longest = 1;
  int current = 1;

  for (int i = 1; i < sortedDates.length; i++) {
    final prev = sortedDates[i - 1];
    final curr = sortedDates[i];
    if (curr.difference(prev).inDays == 1) {
      current++;
      longest = current > longest ? current : longest;
    } else {
      current = 1;
    }
  }

  return longest;
}

Widget buildStreakStats(Set<DateTime> learnedDates) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));

  final int currentStreak = calculateCurrentStreak(learnedDates);
  final int longestStreak = calculateLongestStreak(learnedDates);

  final bool hasStreak =
      learnedDates.contains(today) || learnedDates.contains(yesterday);
  final int displayLongest = hasStreak ? longestStreak : 0;
  final int displayCurrent = hasStreak ? currentStreak : 0;
  final Color iconColor = hasStreak
      ? Colors.pinkAccent
      : Colors.black.withAlpha(100);

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        streakInfo("기록", "$displayLongest", "불꽃 연속일"),
        Icon(Icons.local_fire_department, color: iconColor, size: 72),
        streakInfo("기록", "$displayCurrent", "연속 주"),
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
