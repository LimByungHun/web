import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:web/model/course_model.dart';
import 'package:web/service/study_api.dart';
import 'package:web/widget/button_widget.dart';
import 'package:web/widget/choice_widget.dart';
import 'package:web/widget/sidebar_widget.dart';

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
                                      "${course['Study_Course']} 안내 코스입니다. ",
                                  onSelect: () async {
                                    final courseName = course['Study_Course'];
                                    try {
                                      final detail =
                                          await StudyApi.fetchCourseDetail(
                                            courseName,
                                          );

                                      final words =
                                          List<Map<String, dynamic>>.from(
                                            detail['words'],
                                          );

                                      final seen = <int>{};
                                      final steps = <Map<String, dynamic>>[];
                                      for (final word in words) {
                                        final step = word['step'];
                                        final stepName = word['step_name'];
                                        if (step != null &&
                                            stepName != null &&
                                            !seen.contains(step)) {
                                          seen.add(step);
                                          steps.add({
                                            'step': step,
                                            'step_name': stepName,
                                          });
                                        }
                                      }
                                      steps.sort(
                                        (a, b) =>
                                            a['step'].compareTo(b['step']),
                                      );

                                      context.read<CourseModel>().selectCourse(
                                        course: courseName,
                                        sid: detail['sid'],
                                        words: words,
                                        steps: steps,
                                      );
                                      Navigator.pop(context);
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
