import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sign_web/model/calendar_model.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:sign_web/service/calendar_api.dart';
import 'package:sign_web/widget/sidebar_widget.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

// DayRecordsResult class (instead of Record type)
class DayRecordsResult {
  final String date;
  final List<DayRecordItem> items;

  DayRecordsResult({required this.date, required this.items});
}

class StudycalendarScreen extends StatefulWidget {
  const StudycalendarScreen({super.key});

  @override
  State<StudycalendarScreen> createState() => StudycalendarScreenState();
}

class StudycalendarScreenState extends State<StudycalendarScreen> {
  final DateTime today = normalize(DateTime.now());
  DateTime focusedDay = DateTime.now();
  Set<DateTime> learnedDate = {};
  int streakDays = 0;
  int bestStreakDays = 0;

  DateTime? selectedDay;
  bool isLoadingRecords = false;
  DayRecordsResult? dayResult;

  static DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);
  bool _isLearned(DateTime day) => learnedDate.contains(normalize(day));

  bool get isFireActive {
    final yesterday = today.subtract(const Duration(days: 1));
    return learnedDate.contains(today) || learnedDate.contains(yesterday);
  }

  @override
  void initState() {
    super.initState();
    _loadCalendarData();
  }

  Future<void> _loadCalendarData() async {
    try {
      final stats = await CalendarApi.fetchLearnedDates();
      setState(() {
        learnedDate = stats.learnedDates.map(normalize).toSet();
        streakDays = stats.streakDays;
        bestStreakDays = stats.bestStreakDays;
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: '학습 날짜 불러오기 실패했습니다.',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
    }
  }

  Future<void> showDayRecords(BuildContext context, DateTime day) async {
    setState(() {
      selectedDay = day;
      isLoadingRecords = true;
      dayResult = null;
    });

    try {
      // CalendarApi.fetchDayRecords returns Record type
      final result = await CalendarApi.fetchDayRecords(day);
      if (!mounted) return;

      // Destructure the Record type
      final (date: resultDate, items: resultItems) = result;

      setState(() {
        dayResult = DayRecordsResult(date: resultDate, items: resultItems);
      });
    } catch (e) {
      if (!mounted) return;
      Fluttertoast.showToast(
        msg: '기록 조회 실패: $e',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
    } finally {
      if (mounted) {
        setState(() {
          isLoadingRecords = false;
        });
      }
    }
  }

  void _navigateMonth(int direction) {
    setState(() {
      focusedDay = DateTime(focusedDay.year, focusedDay.month + direction, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;

    return Scaffold(
      backgroundColor: TablerColors.background,
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(initialIndex: 1),
            VerticalDivider(width: 1, color: TablerColors.border),
            Expanded(
              child: SingleChildScrollView(
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: isDesktop ? 1200 : double.infinity,
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(isDesktop ? 32 : 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header
                          _buildHeader(),
                          SizedBox(height: 24),

                          // Main content
                          if (isDesktop)
                            _buildDesktopLayout()
                          else
                            _buildTabletLayout(),
                        ],
                      ),
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

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TablerColors.primary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            Icons.calendar_today,
            color: TablerColors.primary,
            size: 24,
          ),
        ),
        SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '학습 달력',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: TablerColors.textPrimary,
                ),
              ),
              SizedBox(height: 4),
              Text(
                '날짜별 학습 기록을 확인하세요',
                style: TextStyle(
                  fontSize: 16,
                  color: TablerColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopLayout() {
    return Column(
      children: [
        // Top: Calendar and side statistics in one row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left stats (best record)
            Expanded(flex: 1, child: _buildLeftStatCard()),
            SizedBox(width: 24),
            // Center calendar
            Expanded(flex: 3, child: _buildCalendarOnlyCard()),
            SizedBox(width: 24),
            // Right stats (current streak)
            Expanded(flex: 1, child: _buildRightStatCard()),
          ],
        ),
        SizedBox(height: 24),
        // Bottom: Study records
        _buildRecordsCard(),
      ],
    );
  }

  Widget _buildTabletLayout() {
    return Column(
      children: [
        // Calendar and side statistics in one row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left stats (best record)
            Expanded(flex: 1, child: _buildLeftStatCard()),
            SizedBox(width: 16),
            // Center calendar
            Expanded(flex: 2, child: _buildCalendarOnlyCard()),
            SizedBox(width: 16),
            // Right stats (current streak)
            Expanded(flex: 1, child: _buildRightStatCard()),
          ],
        ),
        SizedBox(height: 24),
        // Bottom study records
        _buildRecordsCard(),
      ],
    );
  }

  Widget _buildLeftStatCard() {
    return TablerCard(
      title: '최고 기록',
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: TablerColors.warning.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.emoji_events,
              color: TablerColors.warning,
              size: 40,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '$bestStreakDays일',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: TablerColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '불꽃 연속일',
            style: TextStyle(fontSize: 14, color: TablerColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildRightStatCard() {
    return TablerCard(
      title: '현재 연속',
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: TablerColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(40),
            ),
            child: Icon(
              Icons.trending_up,
              color: TablerColors.success,
              size: 40,
            ),
          ),
          SizedBox(height: 16),
          Text(
            '$streakDays일',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: TablerColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            '연속 학습일',
            style: TextStyle(fontSize: 14, color: TablerColors.textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarOnlyCard() {
    return TablerCard(
      title: '달력',
      actions: MediaQuery.of(context).size.width < 700
          ? [] // 화면이 작으면 년/월 표시 박스 완전히 숨김
          : [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: TablerColors.textSecondary,
                    ),
                    onPressed: () => _navigateMonth(-1),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: TablerColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${focusedDay.year}년 ${focusedDay.month}월',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: TablerColors.primary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: TablerColors.textSecondary,
                    ),
                    onPressed: () => _navigateMonth(1),
                  ),
                ],
              ),
            ],
      child: TableCalendar<DateTime>(
        locale: 'ko_KR',
        firstDay: DateTime(2025, 1, 1),
        lastDay: DateTime(9999, 12, 31),
        focusedDay: focusedDay,
        onPageChanged: (day) => setState(() => focusedDay = day),
        onDaySelected: (selectedDay, newFocusedDay) async {
          setState(() => focusedDay = newFocusedDay);
          await showDayRecords(context, selectedDay);
        },
        headerVisible: false,
        calendarFormat: CalendarFormat.month,
        rowHeight: 48,
        daysOfWeekHeight: 32,
        selectedDayPredicate: (day) =>
            selectedDay != null && normalize(day) == normalize(selectedDay!),
        calendarStyle: CalendarStyle(
          outsideDaysVisible: false,
          defaultTextStyle: TextStyle(
            fontSize: 14,
            color: TablerColors.textPrimary,
          ),
          weekendTextStyle: TextStyle(
            fontSize: 14,
            color: TablerColors.textPrimary,
          ),
          todayDecoration: BoxDecoration(
            color: TablerColors.primary,
            shape: BoxShape.circle,
          ),
          selectedDecoration: BoxDecoration(
            color: TablerColors.info,
            shape: BoxShape.circle,
          ),
          markerDecoration: BoxDecoration(color: Colors.transparent),
          cellMargin: EdgeInsets.all(2),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: TablerColors.textSecondary,
          ),
          weekendStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: TablerColors.textSecondary,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          defaultBuilder: (context, day, _) {
            final isToday = normalize(day) == today;
            final isLearned = _isLearned(day);

            if (isLearned && !isToday) {
              return Container(
                margin: EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: TablerColors.success,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${day.day}',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              );
            }
            return null;
          },
          markerBuilder: (context, day, events) {
            if (_isLearned(day) && normalize(day) != today) {
              return Positioned(
                bottom: 2,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: TablerColors.success,
                    shape: BoxShape.circle,
                  ),
                ),
              );
            }
            return null;
          },
        ),
      ),
    );
  }

  Widget _buildRecordsCard() {
    return TablerCard(
      title: selectedDay != null
          ? '${selectedDay!.year}-${selectedDay!.month.toString().padLeft(2, '0')}-${selectedDay!.day.toString().padLeft(2, '0')} 학습 기록'
          : '학습 기록',
      actions: selectedDay != null
          ? [
              IconButton(
                icon: Icon(Icons.refresh, color: TablerColors.textSecondary),
                onPressed: () {
                  if (selectedDay != null) {
                    showDayRecords(context, selectedDay!);
                  }
                },
              ),
            ]
          : null,
      child: SizedBox(height: 400, child: _buildRecordsContent()),
    );
  }

  Widget _buildRecordsContent() {
    if (isLoadingRecords) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation(TablerColors.primary),
            ),
            SizedBox(height: 16),
            Text(
              '학습 기록을 불러오는 중...',
              style: TextStyle(fontSize: 16, color: TablerColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (selectedDay == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: TablerColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.calendar_month,
                size: 32,
                color: TablerColors.info,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '날짜를 선택하세요',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: TablerColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '달력에서 날짜를 클릭하면\n해당 날짜의 학습 기록을 확인할 수 있습니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: TablerColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (dayResult == null || dayResult!.items.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: TablerColors.warning.withOpacity(0.1),
                borderRadius: BorderRadius.circular(32),
              ),
              child: Icon(
                Icons.event_busy,
                size: 32,
                color: TablerColors.warning,
              ),
            ),
            SizedBox(height: 16),
            Text(
              '학습 기록이 없습니다',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: TablerColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              '선택한 날짜에는 학습 기록이 없습니다',
              style: TextStyle(fontSize: 14, color: TablerColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      itemCount: dayResult!.items.length,
      separatorBuilder: (_, __) =>
          Divider(height: 1, color: TablerColors.border),
      itemBuilder: (_, idx) {
        final record = dayResult!.items[idx];
        final time = TimeOfDay.fromDateTime(record.studyTime);
        final timeStr =
            '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

        return Container(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              // Completion status icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: record.complete
                      ? TablerColors.success.withOpacity(0.1)
                      : TablerColors.warning.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  record.complete ? Icons.check_circle : Icons.schedule,
                  color: record.complete
                      ? TablerColors.success
                      : TablerColors.warning,
                  size: 20,
                ),
              ),
              SizedBox(width: 16),

              // Study information
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      record.studyCourse,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: TablerColors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      record.stepName != null
                          ? 'Step ${record.step} · ${record.stepName}'
                          : 'Step ${record.step}',
                      style: TextStyle(
                        fontSize: 14,
                        color: TablerColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Time and status
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: TablerColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: record.complete
                          ? TablerColors.success.withOpacity(0.1)
                          : TablerColors.warning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: record.complete
                            ? TablerColors.success.withOpacity(0.3)
                            : TablerColors.warning.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      record.complete ? '완료' : '미완료',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: record.complete
                            ? TablerColors.success
                            : TablerColors.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
