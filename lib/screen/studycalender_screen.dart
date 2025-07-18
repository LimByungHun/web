import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sign_web/service/calendar_api.dart';
import 'package:sign_web/widget/sidebar_widget.dart';

class StudycalenderScreen extends StatefulWidget {
  const StudycalenderScreen({super.key});

  @override
  State<StudycalenderScreen> createState() => StudycalenderScreenState();
}

class StudycalenderScreenState extends State<StudycalenderScreen> {
  final DateTime today = normalize(DateTime.now());
  DateTime focusedDay = DateTime.now();
  Set<DateTime> learnedDate = {};
  int streakDays = 0;
  int bestStreakDays = 0;
  static DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isLearned(DateTime day) => learnedDate.contains(normalize(day));
  int streakWeeks = 0;

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
                  constraints: BoxConstraints(maxWidth: 1100),
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 32, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // 불꽃 아이콘 + 캘린더
                        Column(
                          children: [
                            // 불꽃 아이콘 (캘린더 위)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Icon(
                                Icons.local_fire_department,
                                size: 48,
                                color: Colors.pinkAccent,
                              ),
                            ),
                            TableCalendar(
                              locale: 'ko_KR',
                              firstDay: DateTime(2025, 1, 1),
                              lastDay: DateTime(9999, 12, 31),
                              focusedDay: focusedDay,
                              onPageChanged: (day) =>
                                  setState(() => focusedDay = day),
                              headerStyle: HeaderStyle(
                                titleCentered: true,
                                formatButtonVisible: false,
                                leftChevronIcon: Icon(Icons.chevron_left),
                                rightChevronIcon: Icon(Icons.chevron_right),
                                titleTextStyle: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
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
                                cellMargin: EdgeInsets.symmetric(vertical: 4),
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
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Center(
                                      child: Text(
                                        '${day.day}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        // 기록 Row (캘린더 아래에 넓게)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStreakBox(
                              title: "기록",
                              value: "$streakDays",
                              desc: "연속 일",
                            ),
                            _buildStreakBox(
                              title: "기록",
                              value: "$streakWeeks",
                              desc: "연속 주",
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreakBox({
    required String title,
    required String value,
    required String desc,
  }) {
    return Expanded(
      child: Container(
        margin: EdgeInsets.symmetric(horizontal: 8),
        padding: EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.pink[50],
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.pink,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
            SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: Colors.pink,
                fontWeight: FontWeight.bold,
                fontSize: 28,
              ),
            ),
            SizedBox(height: 2),
            Text(desc, style: TextStyle(color: Colors.grey[800], fontSize: 13)),
          ],
        ),
      ),
    );
  }
}
