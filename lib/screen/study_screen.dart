import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/widget/genericstudy_widget.dart';
import 'package:sign_web/widget/quiz_widget.dart';
import 'package:sign_web/widget/stepdata.dart';

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
      if (context.read<CourseModel>().isStepCompleted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('단계 완료')));
      }
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepData = steps[currentStep];
    if (todayItems.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(widget.course)),
        body: const Center(child: Text('학습할 콘텐츠가 없습니다.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text('${widget.course} ${stepData.title}')),
      body: stepData.widget,
    );
  }
}
