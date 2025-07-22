import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/service/study_api.dart';
import 'package:sign_web/widget/coursestepcard_widget.dart';
import 'package:sign_web/widget/review_widget.dart';
import 'package:sign_web/widget/sidebar_widget.dart';
import 'package:sign_web/widget/stetscard_widget.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  static DateTime normalize(DateTime d) => DateTime(d.year, d.month, d.day);

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
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    final contentPadding = screenWidth * 0.05;
    final headerHeight = screenHeight * 0.12;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Sidebar(initialIndex: 0),
                  VerticalDivider(width: 1, color: Colors.grey[300]),
                  Expanded(
                    child: Column(
                      children: [
                        Container(
                          width: double.infinity,
                          height: headerHeight > 80 ? 80 : headerHeight,
                          padding: EdgeInsets.symmetric(
                            horizontal: contentPadding,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: buildHeader(
                            screenWidth,
                            headerHeight > 80 ? 80 : headerHeight,
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: EdgeInsets.all(contentPadding),
                            child: buildUnifiedContent(
                              courseModel,
                              screenWidth,
                              screenHeight -
                                  headerHeight -
                                  (contentPadding * 2),
                            ),
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

  Widget buildHeader(double contentWidth, double headerHeight) {
    final courseModel = context.watch<CourseModel>();
    final title = courseModel.selectedCourse ?? '학습 코스를 선택해 주세요';

    double fontSize = headerHeight * 0.22;
    if (fontSize > 28) fontSize = 28;
    if (fontSize < 18) fontSize = 18;

    return Container(
      alignment: Alignment.center,
      child: Text(
        title,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
        textAlign: TextAlign.center,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        softWrap: false,
      ),
    );
  }

  Widget buildUnifiedContent(
    CourseModel courseModel,
    double width,
    double height,
  ) {
    final hasCourse = courseModel.selectedCourse != null;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isVertical = constraints.maxWidth < 1000;
        final cardPadding = 16.0;

        if (isVertical) {
          // 세로(모바일/좁은화면) : 학습코스 아래에 복습, 통계카드를 Row로 좌우 배치
          return Column(
            children: [
              Expanded(
                flex: 45,
                child: Container(
                  width: double.infinity,
                  margin: EdgeInsets.only(bottom: height * 0.03),
                  child: hasCourse
                      ? CoursestepcardWidget(
                          boxHeight: height * 0.65,
                          horizontalPadding: 0,
                          selectedCourse: courseModel.selectedCourse,
                          currentDay: courseModel.currentDay,
                          totalDays: courseModel.totalDays,
                          steps: courseModel.steps,
                          onSelectCourse: (_) async {
                            await courseModel.loadFromPrefs();
                          },
                          onStartStudy: (day) {
                            GoRouter.of(context).go(
                              '/study',
                              extra: {
                                'course': courseModel.selectedCourse!,
                                'day': day,
                              },
                            );
                          },
                        )
                      : buildNoCourseCard(height * 0.65, cardPadding),
                ),
              ),
              Expanded(
                flex: 50,
                child: Row(
                  children: [
                    Expanded(
                      flex: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: hasCourse
                            ? ReviewCard()
                            : Center(
                                child: Text(
                                  '학습 코스 선택 시 복습 카드가 표시됩니다.',
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    SizedBox(width: width * 0.025),
                    Expanded(
                      flex: 50,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        // child: hasCourse
                        //     ? StetscardWidget(
                        //         learnedWords: learnedWordsCount,
                        //         streakDays: streakDays,
                        //         overallPercent: overallPercent,
                        //       )
                        //     : Center(
                        //         child: Text(
                        //           '학습 코스 선택 시 통계가 표시됩니다.',
                        //           style: TextStyle(
                        //             color: Colors.grey,
                        //             fontSize: 16,
                        //           ),
                        //         ),
                        //       ),
                        child: StetscardWidget(
                          learnedWords: learnedWordsCount,
                          streakDays: streakDays,
                          overallPercent: overallPercent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        } else {
          // 전체화면(가로): 학습코스(왼쪽 위), 통계(왼쪽 아래), 복습(오른쪽)
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 55,
                child: Column(
                  children: [
                    Expanded(
                      flex: 60,
                      child: Container(
                        width: double.infinity,
                        margin: EdgeInsets.only(bottom: height * 0.02),
                        child: hasCourse
                            ? CoursestepcardWidget(
                                boxHeight: height * 0.65,
                                horizontalPadding: 0,
                                selectedCourse: courseModel.selectedCourse,
                                currentDay: courseModel.currentDay,
                                totalDays: courseModel.totalDays,
                                steps: courseModel.steps,
                                onSelectCourse: (_) async {
                                  await courseModel.loadFromPrefs();
                                },
                                onStartStudy: (day) {
                                  GoRouter.of(context).go(
                                    '/study',
                                    extra: {
                                      'course': courseModel.selectedCourse!,
                                      'day': day,
                                    },
                                  );
                                },
                              )
                            : buildNoCourseCard(height * 0.65, cardPadding),
                      ),
                    ),
                    SizedBox(height: height * 0.02),
                    Expanded(
                      flex: 40,
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              spreadRadius: 1,
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        // child: hasCourse
                        //     ? StetscardWidget(
                        //         learnedWords: learnedWordsCount,
                        //         streakDays: streakDays,
                        //         overallPercent: overallPercent,
                        //       )
                        //     : Center(
                        //         child: Text(
                        //           '학습 코스 선택 시 통계가 표시됩니다.',
                        //           style: TextStyle(
                        //             color: Colors.grey,
                        //             fontSize: 16,
                        //           ),
                        //         ),
                        //       ),
                        child: StetscardWidget(
                          learnedWords: learnedWordsCount,
                          streakDays: streakDays,
                          overallPercent: overallPercent,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: width * 0.025),
              Expanded(
                flex: 30,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withValues(alpha: 0.1),
                        spreadRadius: 1,
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: hasCourse
                      ? ReviewCard()
                      : Center(
                          child: Text(
                            '학습 코스 선택 시 복습 카드가 표시됩니다.',
                            style: TextStyle(color: Colors.grey, fontSize: 16),
                          ),
                        ),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget buildNoCourseCard(double cardHeight, double cardPadding) {
    return Container(
      height: cardHeight,
      margin: EdgeInsets.all(cardPadding),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            spreadRadius: 1,
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.school_outlined,
              size: cardHeight * 0.3,
              color: Colors.grey[400],
            ),
            SizedBox(height: cardHeight * 0.05),
            SizedBox(
              width: 400,
              height: 56,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () async {
                  await context.push('/course');
                  setState(() {});
                },
                child: Text(
                  '학습 코스를 선택해 주세요',
                  style: TextStyle(
                    fontSize: cardHeight * 0.08 > 22 ? 22 : cardHeight * 0.08,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
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
