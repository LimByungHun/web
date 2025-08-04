import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/widget/genericstudy_widget.dart';
import 'package:sign_web/widget/quiz_widget.dart';
import 'package:sign_web/widget/stepdata.dart';
import 'package:sign_web/theme/tabler_theme.dart';

class StudyScreen extends StatefulWidget {
  final String course;
  final int day;
  const StudyScreen({super.key, required this.course, required this.day});

  @override
  StudyScreenState createState() => StudyScreenState();
}

class StudyScreenState extends State<StudyScreen> {
  int currentStep = 0;
  late List<StepData> steps;
  late List<String> todayItems;

  @override
  void initState() {
    super.initState();
    setupData();
  }

  void setupData() {
    final courseModel = context.read<CourseModel>();
    final stepNumber = widget.day; // 실제 step 번호 (1부터 시작)

    final todayWordMaps = courseModel.words
        .where((w) => w['step'] == stepNumber)
        .toList();

    todayItems = todayWordMaps.map((w) => w['word'].toString()).toList();

    if (stepNumber < 5) {
      steps = [
        StepData(
          title: '학습',
          widget: GenericStudyWidget(
            items: todayItems,
            sid: courseModel.sid,
            step: stepNumber,
          ),
        ),
      ];
    } else {
      steps = [
        StepData(
          title: '퀴즈',
          widget: GenericQuizWidget(
            words: todayWordMaps,
            sid: courseModel.sid,
            step: stepNumber,
          ),
        ),
      ];
    }

    currentStep = 0;
  }

  @override
  void didUpdateWidget(covariant StudyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.day != widget.day || oldWidget.course != widget.course) {
      setState(() {
        setupData();
      });
    }
  }

  Future<void> nextStep() async {
    if (currentStep < steps.length - 1) {
      setState(() => currentStep++);
    } else {
      context.read<CourseModel>().completeOneDay();

      if (!mounted) return;

      if (context.read<CourseModel>().isStepCompleted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('단계 완료'),
            backgroundColor: TablerColors.success,
          ),
        );

        await Future.delayed(const Duration(milliseconds: 500));
      }

      if (mounted) {
        GoRouter.of(context).go('/home');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepData = steps[currentStep];

    if (todayItems.isEmpty) {
      return Scaffold(
        backgroundColor: TablerColors.background,
        appBar: AppBar(
          title: Text(widget.course),
          backgroundColor: Colors.white,
          foregroundColor: TablerColors.textPrimary,
          elevation: 1,
          leading: IconButton(
            onPressed: () => GoRouter.of(context).go('/home'),
            icon: Icon(Icons.arrow_back),
          ),
        ),
        body: Center(
          child: Container(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: TablerColors.warning.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(40),
                  ),
                  child: Icon(
                    Icons.warning_outlined,
                    size: 40,
                    color: TablerColors.warning,
                  ),
                ),
                SizedBox(height: 24),
                Text(
                  '학습할 콘텐츠가 없습니다',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: TablerColors.textPrimary,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '다른 학습 코스를 선택해보세요',
                  style: TextStyle(
                    fontSize: 16,
                    color: TablerColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: TablerColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: TablerColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${widget.day}단계',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: TablerColors.primary,
                ),
              ),
            ),
            SizedBox(width: 12),
            Text('${widget.course} ${stepData.title}'),
          ],
        ),
        backgroundColor: Colors.white,
        foregroundColor: TablerColors.textPrimary,
        elevation: 1,
        leading: IconButton(
          onPressed: () => GoRouter.of(context).go('/home'),
          icon: Icon(Icons.arrow_back),
        ),
        actions: [
          // 진행률 표시
          Container(
            margin: EdgeInsets.only(right: 16),
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: TablerColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${currentStep + 1}/${steps.length}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: TablerColors.success,
              ),
            ),
          ),
        ],
      ),
      body: stepData.widget,
    );
  }
}
