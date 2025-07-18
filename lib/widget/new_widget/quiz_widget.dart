import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:video_player/video_player.dart';
import 'package:web/model/course_model.dart';
import 'package:web/service/study_api.dart';

class GenericQuizWidget extends StatefulWidget {
  final List<Map<String, dynamic>> words;
  final int? sid;
  final int? step;
  final bool completeOnFinish;
  final bool showAppBar;

  const GenericQuizWidget({
    super.key,
    required this.words,
    this.sid,
    this.step,
    this.completeOnFinish = true,
    this.showAppBar = false,
  });

  @override
  State<GenericQuizWidget> createState() => _GenericQuizWidgetState();
}

class _GenericQuizWidgetState extends State<GenericQuizWidget> {
  late List<Map<String, dynamic>> quizList;
  int index = 0;
  int correctCount = 0;
  bool answered = false;
  bool? answereIcon;
  late String correct;
  List<String> options = [];
  VideoPlayerController? videoplayer;

  @override
  void initState() {
    super.initState();
    quizList = List<Map<String, dynamic>>.from(widget.words)..shuffle();
    setup();
  }

  void setup() {
    final current = quizList[index];
    correct = current['word']?.toString() ?? '';

    final allWords =
        widget.words
            .map((w) => w['word'].toString())
            .where((w) => w != correct)
            .toList()
          ..shuffle();

    options = [correct, ...allWords.take(3)]..shuffle();

    // videoplayer?.dispose();
    // videoplayer = VideoPlayerController.networkUrl(
    //   Uri.parse('http://10.101.170.63/video/${Uri.encodeComponent(correct)}.mp4'),
    // )
    //   ..setLooping(true)
    //   ..setPlaybackSpeed(1.0)
    //   ..initialize().then((_) {
    //     if (mounted) setState(() {});
    //   });
  }

  void onOptionSelected(String selected) {
    if (answered) return;

    final isCorrect = selected == correct;

    setState(() {
      answered = true;
      answereIcon = isCorrect;
      if (selected == correct) correctCount++;
    });

    Future.delayed(const Duration(seconds: 1), () {
      setState(() {
        answereIcon = null;
      });
      onNext();
    });
  }

  void onNext() async {
    if (index < quizList.length - 1) {
      setState(() {
        index++;
        answered = false;
        setup();
      });
    } else {
      final accuracy = correctCount / quizList.length;
      final percent = (accuracy * 100).toStringAsFixed(1);

      if (accuracy >= 0.6 &&
          widget.completeOnFinish &&
          widget.sid != null &&
          widget.step != null) {
        try {
          await StudyApi.completeStudy(sid: widget.sid!, step: widget.step!);

          final stats = await StudyApi.getStudyStats();
          if (context.mounted) {
            context.read<CourseModel>().updateCompletedSteps(
              stats.completedSteps,
            );
          }

          Fluttertoast.showToast(
            msg: "퀴즈 완료! 정답률: $percent%",
            toastLength: Toast.LENGTH_SHORT,
          );
        } catch (e) {
          Fluttertoast.showToast(
            msg: "저장 실패: $e",
            toastLength: Toast.LENGTH_SHORT,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: "퀴즈 실패... ($percent%) 다시 도전해보세요!",
          toastLength: Toast.LENGTH_SHORT,
        );
      }

      Navigator.pop(context);
    }
  }

  @override
  void dispose() {
    videoplayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 700; // PC 웹 기준

    return Scaffold(
      body: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 800), // 웹에서 최대 너비 제한
          padding: EdgeInsets.all(isDesktop ? 32 : 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: isDesktop ? 40 : 20),
              Text(
                '이것은 무엇일까요?',
                style: TextStyle(
                  fontSize: isDesktop ? 40 : 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: isDesktop ? 24 : 12),
              Container(
                width: isDesktop ? 500 : screenWidth * 0.8,
                height: isDesktop ? 320 : 180,
                color: Colors.black,
                // ...영상 등
              ),
              SizedBox(height: isDesktop ? 32 : 16),
              Text(
                '정답 $correctCount / ${quizList.length}',
                style: TextStyle(fontSize: isDesktop ? 20 : 16),
              ),
              SizedBox(height: isDesktop ? 32 : 16),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: isDesktop ? 24 : 12,
                runSpacing: isDesktop ? 24 : 12,
                children: List.generate(options.length, (i) {
                  final opt = options[i];
                  return SizedBox(
                    width: isDesktop ? 150 : 120,
                    height: isDesktop ? 48 : 40,
                    child: ElevatedButton(
                      onPressed: answered ? null : () => onOptionSelected(opt),
                      style: ElevatedButton.styleFrom(
                        textStyle: TextStyle(fontSize: isDesktop ? 20 : 16),
                        padding: EdgeInsets.symmetric(
                          vertical: isDesktop ? 14 : 10,
                        ),
                      ),
                      child: Text(opt),
                    ),
                  );
                }),
              ),
              if (answereIcon != null)
                Container(
                  alignment: Alignment.center,
                  child: Icon(
                    answereIcon! ? Icons.circle_outlined : Icons.close,
                    size: 10,
                    color: answereIcon! ? Colors.green : Colors.red,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
