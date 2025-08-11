import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/service/study_api.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/sidebar_widget.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

class StudycourceScreen extends StatefulWidget {
  const StudycourceScreen({super.key});

  @override
  State<StudycourceScreen> createState() => StudycourceScreenState();
}

class StudycourceScreenState extends State<StudycourceScreen> {
  List<Map<String, dynamic>> studyList = [];
  int? selectedCourseIndex;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchStudyList();
  }

  Future<void> fetchStudyList() async {
    try {
      final data = await StudyApi.StudyCourses();
      setState(() {
        studyList = data;
        isLoading = false;
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: "학습 코스 목록 불러오기 실패",
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
      setState(() => isLoading = false);
    }
  }

  Future<void> selectCourse(int index) async {
    final course = studyList[index];
    final courseName = course['Study_Course'];

    try {
      final detail = await StudyApi.fetchCourseDetail(courseName);

      final rawWords = detail['words'];
      if (rawWords is! List) {
        throw Exception('words 필드가 List가 아님');
      }

      final words = <Map<String, dynamic>>[];
      for (final item in rawWords) {
        if (item is Map<String, dynamic>) {
          words.add(item);
        } else {
          debugPrint('[오류] 잘못된 words 항목: $item');
        }
      }

      final steps = List<Map<String, dynamic>>.from(detail['steps']);

      context.read<CourseModel>().selectCourse(
        course: courseName,
        sid: detail['sid'],
        words: words,
        steps: steps,
      );

      Fluttertoast.showToast(
        msg: "$courseName 코스가 선택되었습니다",
        backgroundColor: TablerColors.success,
        textColor: Colors.white,
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          GoRouter.of(context).go('/home');
        }
      });
    } catch (e) {
      Fluttertoast.showToast(
        msg: "코스 정보 불러오기 실패",
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablerColors.background,
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(initialIndex: 4),
            VerticalDivider(width: 1, color: TablerColors.border),
            Expanded(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 800),
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(),
                        SizedBox(height: 24),
                        Expanded(child: _buildCourseList()),
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

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TablerColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.menu_book,
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
                    '학습 코스 선택',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: TablerColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '원하는 학습 코스를 선택하여 수어 학습을 시작하세요',
                    style: TextStyle(
                      fontSize: 16,
                      color: TablerColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCourseList() {
    if (isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: TablerColors.primary),
            SizedBox(height: 16),
            Text(
              '학습 코스를 불러오는 중...',
              style: TextStyle(fontSize: 16, color: TablerColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (studyList.isEmpty) {
      return Center(
        child: TablerCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.folder_open_outlined,
                size: 64,
                color: TablerColors.textSecondary,
              ),
              SizedBox(height: 16),
              Text(
                '사용 가능한 학습 코스가 없습니다',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w500,
                  color: TablerColors.textPrimary,
                ),
              ),
              SizedBox(height: 8),
              Text(
                '나중에 다시 시도해주세요',
                style: TextStyle(
                  fontSize: 14,
                  color: TablerColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: studyList.length,
      separatorBuilder: (context, index) => SizedBox(height: 12),
      itemBuilder: (context, index) {
        final course = studyList[index];
        final isSelected = selectedCourseIndex == index;
        final courseName = course['Study_Course'] ?? '알 수 없는 코스';

        return AnimatedContainer(
          duration: Duration(milliseconds: 200),
          child: TablerCard(
            margin: EdgeInsets.zero,
            padding: EdgeInsets.zero,
            child: InkWell(
              onTap: () {
                setState(() {
                  selectedCourseIndex = isSelected ? null : index;
                });
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: isSelected
                                ? TablerColors.primary
                                : TablerColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.school_outlined,
                            color: isSelected
                                ? Colors.white
                                : TablerColors.primary,
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                courseName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: TablerColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          isSelected
                              ? Icons.keyboard_arrow_up
                              : Icons.keyboard_arrow_down,
                          color: TablerColors.textSecondary,
                        ),
                      ],
                    ),
                    if (isSelected) ...[
                      SizedBox(height: 20),
                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: TablerColors.info.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: TablerColors.info.withOpacity(0.2),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  size: 18,
                                  color: TablerColors.info,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  '$courseName 코스 정보',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: TablerColors.info,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 8),
                            Text(
                              '이 코스를 선택하면 단계별로 수어 학습을 진행할 수 있습니다.',
                              style: TextStyle(
                                fontSize: 13,
                                color: TablerColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TablerButton(
                                  text: '취소',
                                  outline: true,
                                  small: true,
                                  onPressed: () {
                                    setState(() {
                                      selectedCourseIndex = null;
                                    });
                                  },
                                ),
                                SizedBox(width: 12),
                                TablerButton(
                                  text: '학습 시작',
                                  small: true,
                                  icon: Icons.play_arrow,
                                  onPressed: () => selectCourse(index),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
