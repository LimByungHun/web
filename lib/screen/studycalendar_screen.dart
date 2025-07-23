import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sign_web/model/calendar_model.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sign_web/service/calendar_api.dart';
import 'package:sign_web/widget/sidebar_widget.dart';

class StudycalendarScreen extends StatefulWidget {
  const StudycalendarScreen({super.key});

  @override
  State<StudycalendarScreen> createState() => _StudycalendarScreenState();
}

class _StudycalendarScreenState extends State<StudycalendarScreen> {
  final DateTime today = normalize(DateTime.now());
  DateTime focusedDay = DateTime.now();
  Set<DateTime> learnedDate = {};
  int streakDays = 0;
  int bestStreakDays = 0;

  static DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isLearned(DateTime day) => learnedDate.contains(normalize(day));

  bool get isFireActive {
    final yesterday = today.subtract(const Duration(days: 1));
    return learnedDate.contains(today) || learnedDate.contains(yesterday);
  }

  @override
  void initState() {
    super.initState();
    CalendarApi.fetchLearnedDates()
        .then((stats) {
          setState(() {
            learnedDate = stats.learnedDates.map(normalize).toSet();
            streakDays = stats.streakDays;
            bestStreakDays = stats.bestStreakDays;
          });
        })
        .catchError((e) {
          Fluttertoast.showToast(msg: '학습 날짜 불러오기 실패했습니다.');
        });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(initialIndex: 1),
            VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 1000),
                  child: Column(
                    children: [
                      const SizedBox(height: 60),
                      buildStreakStats(
                        bestStreakDays: bestStreakDays,
                        streakDays: streakDays,
                        isFireActive: isFireActive,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.chevron_left),
                              onPressed: () {
                                setState(() {
                                  focusedDay = DateTime(
                                    focusedDay.year,
                                    focusedDay.month - 1,
                                    1,
                                  );
                                });
                              },
                            ),
                            Text(
                              '${focusedDay.year}년 ${focusedDay.month}월',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.chevron_right),
                              onPressed: () {
                                setState(() {
                                  focusedDay = DateTime(
                                    focusedDay.year,
                                    focusedDay.month + 1,
                                    1,
                                  );
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      TableCalendar(
                        locale: 'ko_KR',
                        firstDay: DateTime(2025, 1, 1),
                        lastDay: DateTime(9999, 12, 31),
                        focusedDay: focusedDay,
                        onPageChanged: (day) =>
                            setState(() => focusedDay = day),
                        headerVisible: false,
                        calendarFormat: CalendarFormat.month,
                        rowHeight: 48,
                        daysOfWeekHeight: 24,
                        selectedDayPredicate: _isLearned,
                        calendarStyle: CalendarStyle(
                          defaultTextStyle: const TextStyle(
                            color: Colors.black,
                          ),
                          weekendTextStyle: const TextStyle(
                            color: Colors.black,
                          ),
                          todayDecoration: BoxDecoration(
                            color: Colors.red.shade900,
                            shape: BoxShape.circle,
                          ),
                          selectedDecoration: BoxDecoration(
                            color: Colors.red.shade400,
                            shape: BoxShape.circle,
                          ),
                          markerDecoration: const BoxDecoration(
                            color: Colors.transparent,
                          ),
                          cellMargin: const EdgeInsets.symmetric(vertical: 4),
                        ),
                        calendarBuilders: CalendarBuilders(
                          defaultBuilder: (context, day, _) {
                            final isToday = normalize(day) == today;
                            final isLearned = _isLearned(day);
                            if (!isToday && !isLearned) return null;

                            return Container(
                              margin: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: isToday
                                    ? Colors.red.shade900
                                    : Colors.red.shade400,
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  '${day.day}',
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
