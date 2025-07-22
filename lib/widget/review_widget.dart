import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/widget/alllist_widget.dart';
import 'package:sign_web/widget/quiz_widget.dart';

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key});

  @override
  Widget build(BuildContext context) {
    final courseModel = context.watch<CourseModel>();
    final courseWordsMap = courseModel.getCompletedCourseStep5Words();

    final ButtonStyle buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: Colors.deepPurple,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
    );

    if (courseWordsMap.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(child: Text('복습할 내용이 없습니다.')),
      );
    }

    final previewEntries = courseWordsMap.entries.take(5).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          for (final entry in previewEntries)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      entry.key,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  ElevatedButton(
                    style: buttonStyle,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => GenericQuizWidget(
                            words: entry.value,
                            completeOnFinish: false,
                            showAppBar: true,
                          ),
                        ),
                      );
                    },
                    child: const Text('복습하기'),
                  ),
                ],
              ),
            ),

          if (courseWordsMap.length > 5)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton(
                  style: buttonStyle,
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AlllistWidget(
                          title: '복습할 수 있는 코스',
                          courseWordsMap: courseWordsMap,
                        ),
                      ),
                    );
                  },
                  child: const Text('전체 보기'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
