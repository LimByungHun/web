import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/service/study_api.dart';
import 'package:sign_web/widget/button_widget.dart';
import 'package:sign_web/widget/choice_widget.dart';
import 'package:sign_web/widget/sidebar_widget.dart';

class StudycourceScreen extends StatefulWidget {
  const StudycourceScreen({super.key});

  @override
  State<StudycourceScreen> createState() => StudycourceScreenState();
}

class StudycourceScreenState extends State<StudycourceScreen> {
  List<Map<String, dynamic>> studyList = [];
  int? currentCourseIndex;
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
      Fluttertoast.showToast(msg: "학습 코스 목록 불러오기 실패");
      setState(() {
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(initialIndex: 4),
            VerticalDivider(width: 1),
            Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        '학습코스 선택',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        itemCount: studyList.length,
                        itemBuilder: (context, index) {
                          final isSelected = currentCourseIndex == index;
                          final course = studyList[index];
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              ButtonWidget(
                                text: course['Study_Course'],
                                selected: isSelected,
                                onTap: () {
                                  setState(() {
                                    currentCourseIndex = isSelected
                                        ? null
                                        : index;
                                  });
                                },
                              ),
                              if (isSelected)
                                ChoiceWidget(
                                  description:
                                      "${course['Study_Course']} 코스입니다. ",
                                  onSelect: () async {
                                    final courseName = course['Study_Course'];
                                    try {
                                      final detail =
                                          await StudyApi.fetchCourseDetail(
                                            courseName,
                                          );

                                      final rawWords = detail['words'];
                                      if (rawWords is! List) {
                                        throw Exception('words 필드가 List가 아님');
                                      }

                                      final words = <Map<String, dynamic>>[];
                                      for (final item in rawWords) {
                                        if (item is Map<String, dynamic>) {
                                          words.add(item);
                                        } else {
                                          debugPrint(
                                            '[오류] 잘못된 words 항목: $item',
                                          );
                                        }
                                      }

                                      final steps =
                                          List<Map<String, dynamic>>.from(
                                            detail['steps'],
                                          );

                                      context.read<CourseModel>().selectCourse(
                                        course: courseName,
                                        sid: detail['sid'],
                                        words: words,
                                        steps: steps,
                                      );

                                      WidgetsBinding.instance
                                          .addPostFrameCallback((_) {
                                            if (context.mounted) {
                                              GoRouter.of(context).go('/home');
                                            }
                                          });
                                    } catch (e) {
                                      Fluttertoast.showToast(
                                        msg: "코스 정보 불러오기 실패",
                                      );
                                    }
                                  },
                                  onClose: () {
                                    setState(() {
                                      currentCourseIndex = null;
                                    });
                                  },
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
