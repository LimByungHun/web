import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/service/study_api.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/review_widget.dart';
import 'package:sign_web/widget/sidebar_widget.dart';
import 'package:sign_web/widget/daybar_widget.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  Set<DateTime> learnedDates = {};
  int learnedWordsCount = 0;
  int streakDays = 0;
  bool isLoading = true;
  double overallPercent = 0.0;

  @override
  void initState() {
    super.initState();
    context.read<CourseModel>().loadFromPrefs();
    loadStudyStats();
    context.read<CourseModel>().debugWords();
    context.read<CourseModel>().loadReviewableStep5Words();
  }

  Future<void> loadStudyStats() async {
    try {
      final result = await StudyApi.getStudyStats();
      final rate = await StudyApi.getCompletionRate();

      final courseModel = context.read<CourseModel>();
      courseModel.updateCompletedSteps(result.completedSteps);

      setState(() {
        learnedDates = result.learnedDates.toSet();
        streakDays = result.streakDays;
        learnedWordsCount = result.learnedWordsCount;
        overallPercent = rate;
        isLoading = false;
      });
    } catch (e) {
      debugPrint('학습 통계 로딩 실패: $e');
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final courseModel = context.watch<CourseModel>();

    if (isLoading) {
      return Scaffold(
        backgroundColor: TablerColors.background,
        body: Center(
          child: CircularProgressIndicator(color: TablerColors.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: TablerColors.background,
      body: SafeArea(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Sidebar(initialIndex: 0),
            VerticalDivider(width: 1, color: TablerColors.border),

            Expanded(
              child: Column(
                children: [
                  buildResponsiveHeader(courseModel),

                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final width = MediaQuery.of(context).size.width;

                        if (width > 1200) {
                          return Padding(
                            padding: EdgeInsets.all(16),
                            child: buildResponsiveContent(courseModel),
                          );
                        } else {
                          return SingleChildScrollView(
                            padding: EdgeInsets.all(16),
                            child: buildResponsiveContent(courseModel),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildResponsiveHeader(CourseModel courseModel) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: TablerColors.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isNarrow = constraints.maxWidth < 600;

          if (isNarrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [buildHeaderTitle(courseModel), SizedBox(height: 12)],
            );
          } else {
            return Row(
              children: [Expanded(child: buildHeaderTitle(courseModel))],
            );
          }
        },
      ),
    );
  }

  Widget buildHeaderTitle(CourseModel courseModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          courseModel.selectedCourse ?? '학습 코스를 선택해 주세요',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: TablerColors.textPrimary,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        if (courseModel.selectedCourse != null)
          Text(
            '${courseModel.currentDay}/${courseModel.totalDays} 단계',
            style: TextStyle(fontSize: 14, color: TablerColors.textSecondary),
          ),
      ],
    );
  }

  Widget buildHeaderButton(String text, IconData icon, String route) {
    return TablerButton(
      text: text,
      icon: icon,
      outline: true,
      small: true,
      onPressed: () => GoRouter.of(context).go(route),
    );
  }

  Widget buildResponsiveContent(CourseModel courseModel) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width > 1200) {
          // 전체화면: 기존 3분할 레이아웃
          return buildDesktopLayout(courseModel);
        } else {
          // 중간/작은 화면: 학습통계를 진행률 옆으로 배치
          return buildTabletLayoutImproved(courseModel);
        }
      },
    );
  }

  Widget buildDesktopLayout(CourseModel courseModel) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 55,
          child: Column(
            children: [
              SizedBox(height: 320, child: buildCourseCard(courseModel)),
              SizedBox(height: 20),
              Expanded(child: buildStatsCard()),
            ],
          ),
        ),
        SizedBox(width: 20),
        Expanded(flex: 30, child: ReviewCard()),
      ],
    );
  }

  Widget buildTabletLayoutImproved(CourseModel courseModel) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 학습 코스 카드 (고정 높이)
          buildCourseCardWithStats(courseModel),
          SizedBox(height: 20),
          // 복습 카드 (남은 공간 사용)
          ReviewCard(),
          buildStatsCard2(),
        ],
      ),
    );
  }

  Widget buildStatsCard2() {
    return TablerStatsCard2(
      learnedWords: learnedWordsCount,
      streakDays: streakDays,
      overallPercent: overallPercent,
    );
  }

  Widget buildCourseCard(CourseModel courseModel) {
    final hasCourse = courseModel.selectedCourse != null;

    return TablerCard(
      title: hasCourse ? '현재 학습 코스' : '학습 시작하기',
      child: hasCourse
          ? Column(
              children: [
                Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: TablerColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      DaybarWidget(
                        totalDays: courseModel.totalDays,
                        currentDay: courseModel.currentDay,
                        steps: courseModel.steps,
                      ),
                      SizedBox(height: 16),
                      LinearProgressIndicator(
                        value: courseModel.currentDay / courseModel.totalDays,
                        backgroundColor: TablerColors.border,
                        valueColor: AlwaysStoppedAnimation(
                          TablerColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 20),

                LayoutBuilder(
                  builder: (context, constraints) {
                    final isNarrow = constraints.maxWidth < 300;

                    if (isNarrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TablerButton(
                            text: '학습하기',
                            icon: Icons.play_arrow,
                            onPressed:
                                courseModel.currentDay <= courseModel.totalDays
                                ? () {
                                    final safeDay = courseModel.currentDay < 1
                                        ? 1
                                        : courseModel.currentDay;
                                    GoRouter.of(context).go(
                                      '/study',
                                      extra: {
                                        'course': courseModel.selectedCourse!,
                                        'day': safeDay,
                                      },
                                    );
                                  }
                                : null,
                          ),
                          SizedBox(height: 12),
                          TablerButton(
                            text: '코스 변경',
                            outline: true,
                            onPressed: () => GoRouter.of(context).go('/course'),
                          ),
                        ],
                      );
                    } else {
                      return Row(
                        children: [
                          Expanded(
                            child: TablerButton(
                              text: '학습하기',
                              icon: Icons.play_arrow,
                              onPressed:
                                  courseModel.currentDay <=
                                      courseModel.totalDays
                                  ? () {
                                      final safeDay = courseModel.currentDay < 1
                                          ? 1
                                          : courseModel.currentDay;
                                      GoRouter.of(context).go(
                                        '/study',
                                        extra: {
                                          'course': courseModel.selectedCourse!,
                                          'day': safeDay,
                                        },
                                      );
                                    }
                                  : null,
                            ),
                          ),
                          SizedBox(width: 12),
                          Expanded(
                            child: TablerButton(
                              text: '코스 변경',
                              outline: true,
                              onPressed: () =>
                                  GoRouter.of(context).go('/course'),
                            ),
                          ),
                        ],
                      );
                    }
                  },
                ),
              ],
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.school_outlined,
                    size: 64,
                    color: TablerColors.textSecondary,
                  ),
                  SizedBox(height: 16),
                  Text(
                    '학습 코스를 선택하여\n수어 학습을 시작해보세요',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 16,
                      color: TablerColors.textSecondary,
                    ),
                  ),
                  SizedBox(height: 20),
                  TablerButton(
                    text: '학습 코스 선택',
                    icon: Icons.arrow_forward,
                    onPressed: () => GoRouter.of(context).go('/course'),
                  ),
                ],
              ),
            ),
    );
  }

  Widget buildCourseCardWithStats(CourseModel courseModel) {
    final hasCourse = courseModel.selectedCourse != null;

    return TablerCard(
      title: hasCourse ? '현재 학습 코스' : '학습 시작하기',
      child: hasCourse
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 상단: 진행 단계 (고정 높이)
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: TablerColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      // DayBar를 상단에 배치
                      DaybarWidget(
                        totalDays: courseModel.totalDays,
                        currentDay: courseModel.currentDay,
                        steps: courseModel.steps,
                      ),
                      SizedBox(height: 12),
                      // 진행률과 통계를 가로로 배치
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // 왼쪽: 진행률 바
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                LinearProgressIndicator(
                                  value:
                                      courseModel.currentDay /
                                      courseModel.totalDays,
                                  backgroundColor: TablerColors.border,
                                  valueColor: AlwaysStoppedAnimation(
                                    TablerColors.primary,
                                  ),
                                  minHeight: 6,
                                ),
                                SizedBox(height: 2),
                                Text(
                                  '${((courseModel.currentDay / courseModel.totalDays) * 100).round()}% 완료',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: TablerColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 12),

                // 하단: 버튼들
                Row(
                  children: [
                    Expanded(
                      child: TablerButton(
                        text: '학습하기',
                        icon: Icons.play_arrow,
                        onPressed:
                            courseModel.currentDay <= courseModel.totalDays
                            ? () {
                                final safeDay = courseModel.currentDay < 1
                                    ? 1
                                    : courseModel.currentDay;
                                GoRouter.of(context).go(
                                  '/study',
                                  extra: {
                                    'course': courseModel.selectedCourse!,
                                    'day': safeDay,
                                  },
                                );
                              }
                            : null,
                      ),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: TablerButton(
                        text: '코스 변경',
                        outline: true,
                        onPressed: () => GoRouter.of(context).go('/course'),
                      ),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.school_outlined,
                  size: 48,
                  color: TablerColors.textSecondary,
                ),
                SizedBox(height: 12),
                Text(
                  '학습 코스를 선택하여\n수어 학습을 시작해보세요',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: TablerColors.textSecondary,
                  ),
                ),
                SizedBox(height: 16),
                TablerButton(
                  text: '학습 코스 선택',
                  icon: Icons.arrow_forward,
                  onPressed: () => GoRouter.of(context).go('/course'),
                ),
              ],
            ),
    );
  }

  Widget buildCompactStatItem(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Icon(icon, color: color, size: 14),
        ),
        SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: TablerColors.textPrimary,
          ),
        ),
        Text(
          label,
          style: TextStyle(fontSize: 8, color: TablerColors.textSecondary),
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget buildStatsCard() {
    return TablerStatsCard(
      learnedWords: learnedWordsCount,
      streakDays: streakDays,
      overallPercent: overallPercent,
    );
  }
}
