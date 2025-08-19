import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/theme/tabler_theme.dart';

class DaybarWidget extends StatelessWidget {
  final int totalDays;
  final int currentDay; // 1부터 시작
  final List<Map<String, dynamic>> steps;
  final bool enableNavigation;

  const DaybarWidget({
    super.key,
    required this.totalDays,
    required this.currentDay,
    required this.steps,
    this.enableNavigation = false,
  });

  void navigateToStep(BuildContext context, int stepNumber) {
    if (!enableNavigation) return;

    final courseModel = context.read<CourseModel>();
    final courseName = courseModel.selectedCourse;

    if (courseName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('학습 코스가 선택되지 않았습니다.'),
          backgroundColor: TablerColors.danger,
        ),
      );
      return;
    }

    final completedSteps = courseModel.completedSteps[courseModel.sid] ?? [];
    final isCompleted = completedSteps.contains(stepNumber);
    final isCurrent = stepNumber == currentDay;

    // 완료된 단계이거나 현재 단계만 이동 가능
    if (isCompleted || isCurrent) {
      GoRouter.of(
        context,
      ).go('/study', extra: {'course': courseName, 'day': stepNumber});
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('아직 이용할 수 없는 단계입니다.'),
          backgroundColor: TablerColors.warning,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(totalDays, (index) {
          final stepNumber = index + 1;
          final courseModel = context.watch<CourseModel>();
          final completedSteps =
              courseModel.completedSteps[courseModel.sid] ?? [];

          bool isCompleted = completedSteps.contains(stepNumber);
          bool isCurrent = stepNumber == currentDay;
          bool isAccessible = enableNavigation && (isCompleted || isCurrent);
          final stepName = steps.length > index
              ? steps[index]['step_name'] ?? '$stepNumber단계'
              : '$stepNumber단계';

          Widget stepWidget = Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: isCurrent
                  ? TablerColors.primary
                  : isCompleted
                  ? TablerColors.success
                  : TablerColors.border,
              shape: BoxShape.circle,
              border: Border.all(
                color: isCurrent
                    ? TablerColors.primary
                    : isCompleted
                    ? TablerColors.success
                    : TablerColors.border,
                width: 2,
              ),
            ),
            alignment: Alignment.center,
            child: isCompleted && !isCurrent
                ? Icon(Icons.check, color: Colors.white, size: 16)
                : Text(
                    '$stepNumber',
                    style: TextStyle(
                      color: isCurrent
                          ? Colors.white
                          : isCompleted
                          ? Colors.white
                          : TablerColors.textSecondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
          );

          return Padding(
            padding: EdgeInsets.symmetric(
              horizontal: MediaQuery.of(context).size.width * 0.02,
            ),
            child: Column(
              children: [
                enableNavigation
                    ? Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: isAccessible
                              ? () => navigateToStep(context, stepNumber)
                              : null,
                          borderRadius: BorderRadius.circular(15),
                          child: Container(
                            padding: EdgeInsets.all(4),
                            child: Column(
                              children: [
                                stepWidget,
                                SizedBox(height: 4),
                                Text(
                                  stepName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: isAccessible
                                        ? TablerColors.textPrimary
                                        : TablerColors.textSecondary,
                                    fontWeight: isAccessible
                                        ? FontWeight.w500
                                        : FontWeight.normal,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ),
                      )
                    : Column(
                        children: [
                          stepWidget,
                          SizedBox(height: 4),
                          Text(
                            stepName,
                            style: const TextStyle(fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
              ],
            ),
          );
        }),
      ),
    );
  }
}
