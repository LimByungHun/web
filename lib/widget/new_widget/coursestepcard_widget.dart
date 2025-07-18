import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:web/screen/studycource_screen.dart';
import 'package:web/widget/new_widget/daybar_widget.dart';

class CoursestepcardWidget extends StatelessWidget {
  final double boxHeight;
  final double horizontalPadding;

  final String? selectedCourse;
  final int currentDay;
  final int totalDays;
  final List<Map<String, dynamic>> steps;
  final void Function(Map<String, dynamic> courseDetail) onSelectCourse;
  final void Function(int day) onStartStudy;

  const CoursestepcardWidget({
    super.key,
    required this.boxHeight,
    required this.horizontalPadding,
    required this.selectedCourse,
    required this.currentDay,
    required this.totalDays,
    required this.steps,
    required this.onSelectCourse,
    required this.onStartStudy,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Container(
        height: boxHeight,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.pink[50],
          borderRadius: BorderRadius.circular(20),
        ),
        child: LayoutBuilder(
          builder: (ctx, cons) {
            return Stack(
              children: [
                if (selectedCourse != null)
                  const Positioned(
                    left: 20,
                    top: 20,
                    child: Text(
                      '학습단계',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                if (selectedCourse != null)
                  Positioned(
                    top: cons.maxHeight * 0.3,
                    left: 0,
                    right: 0,
                    child: DaybarWidget(
                      totalDays: totalDays,
                      currentDay: currentDay,
                      steps: steps,
                    ),
                  ),
                if (selectedCourse != null)
                  Positioned(
                    right: 24,
                    bottom: 16,
                    child: OutlinedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StudycourceScreen(),
                          ),
                        );
                        if (result != null && result is Map<String, dynamic>) {
                          onSelectCourse(result);
                        }
                      },
                      child: const Text('다른 코스 선택'),
                    ),
                  ),
                if (selectedCourse != null)
                  Positioned(
                    left: 15,
                    bottom: 16,
                    child: ElevatedButton(
                      onPressed: () {
                        if (currentDay > totalDays) {
                          Fluttertoast.showToast(
                            msg: '모든 단계 클리어',
                            gravity: ToastGravity.BOTTOM,
                            backgroundColor: Colors.grey[800],
                            textColor: Colors.white,
                          );
                          return;
                        }
                        final safeDay = currentDay < 1 ? 1 : currentDay;
                        onStartStudy(safeDay);
                      },
                      child: const Text('학습하기'),
                    ),
                  ),
                if (selectedCourse == null)
                  Align(
                    child: ElevatedButton(
                      onPressed: () async {
                        final result = await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StudycourceScreen(),
                          ),
                        );
                        if (result != null && result is Map<String, dynamic>) {
                          onSelectCourse(result);
                        }
                      },
                      child: const Text('학습코스 선택하러가기'),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
