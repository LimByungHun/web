import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/service/animation_api.dart';
import 'package:sign_web/widget/animation_widget.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/service/study_api.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

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
  String? selectedOption;
  late String correct;
  List<String> options = [];
  List<Uint8List>? base64Frames;
  bool isLoading = false;
  final GlobalKey<AnimationWidgetState> animationKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    initializeQuiz();
  }

  void initializeQuiz() {
    if (widget.words.isEmpty) {
      // 빈 리스트 처리
      setState(() {
        quizList = [];
        isLoading = false;
      });
      return;
    }

    quizList = List<Map<String, dynamic>>.from(widget.words)..shuffle();
    setup();
  }

  void setup() async {
    if (quizList.isEmpty || index >= quizList.length) {
      return;
    }

    final current = quizList[index];
    correct = current['word']?.toString() ?? '';

    if (correct.isEmpty) {
      onNext();
      return;
    }

    final allWords =
        widget.words
            .map((w) => w['word']?.toString() ?? '')
            .where((w) => w.isNotEmpty && w != correct)
            .toList()
          ..shuffle();

    final otherOptions = allWords.take(3).toList();
    options = [correct, ...otherOptions]..shuffle();

    while (options.length < 4) {
      options.add('선택지 ${options.length + 1}');
    }

    setState(() {
      isLoading = true;
      base64Frames = null;
      selectedOption = null;
      answered = false;
    });

    try {
      final result = await AnimationApi.loadAnimation(correct);
      if (!mounted) return;

      if (result != null && result.isNotEmpty) {
        setState(() {
          base64Frames = result.map((b64) => base64Decode(b64)).toList();
        });
      }
    } catch (e) {
      print('애니메이션 로드 오류: $e');
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  void onOptionSelected(String selected) {
    if (answered) return;

    final isCorrect = selected == correct;

    setState(() {
      answered = true;
      selectedOption = selected;
      if (isCorrect) correctCount++;
    });

    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        onNext();
      }
    });
  }

  void onNext() async {
    if (index < quizList.length - 1) {
      setState(() {
        index++;
      });
      setup();
    } else {
      final accuracy = quizList.isEmpty ? 0.0 : correctCount / quizList.length;
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
            backgroundColor: TablerColors.success,
            textColor: Colors.white,
          );
        } catch (e) {
          Fluttertoast.showToast(
            msg: "저장 실패: $e",
            backgroundColor: TablerColors.danger,
            textColor: Colors.white,
          );
        }
      } else {
        Fluttertoast.showToast(
          msg: "퀴즈 실패... ($percent%) 다시 도전해보세요!",
          backgroundColor: TablerColors.warning,
          textColor: Colors.white,
        );
      }

      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (quizList.isEmpty) {
      return Scaffold(
        backgroundColor: TablerColors.background,
        appBar: widget.showAppBar
            ? AppBar(
                title: Text('퀴즈'),
                backgroundColor: Colors.white,
                foregroundColor: TablerColors.textPrimary,
                elevation: 1,
              )
            : null,
        body: Center(
          child: TablerCard(
            padding: EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.quiz_outlined,
                  size: 64,
                  color: TablerColors.textSecondary,
                ),
                SizedBox(height: 16),
                Text(
                  '퀴즈 문제가 없습니다',
                  style: TextStyle(
                    fontSize: 18,
                    color: TablerColors.textSecondary,
                  ),
                ),
                SizedBox(height: 24),
                TablerButton(
                  text: '돌아가기',
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 700;

    return Scaffold(
      backgroundColor: TablerColors.background,
      appBar: widget.showAppBar
          ? AppBar(
              title: Text('퀴즈'),
              backgroundColor: Colors.white,
              foregroundColor: TablerColors.textPrimary,
              elevation: 1,
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  (widget.showAppBar ? 140 : 140), // AppBar 높이 고려
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: isDesktop ? 900 : double.infinity,
                ),
                child: Padding(
                  padding: EdgeInsets.all(isDesktop ? 32 : 16),
                  child: Column(
                    children: [
                      // 진행 상황 표시
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  '문제 ${index + 1}/${quizList.length}',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: TablerColors.textSecondary,
                                  ),
                                ),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: TablerColors.success.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: TablerColors.success.withOpacity(
                                        0.3,
                                      ),
                                    ),
                                  ),
                                  child: Text(
                                    '정답 $correctCount개',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: TablerColors.success,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            LinearProgressIndicator(
                              value: (index + 1) / quizList.length,
                              backgroundColor: TablerColors.border,
                              valueColor: AlwaysStoppedAnimation(
                                TablerColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),

                      SizedBox(height: 24),

                      // 메인 콘텐츠
                      Container(
                        width: double.infinity,
                        constraints: BoxConstraints(
                          minHeight: MediaQuery.of(context).size.height * 0.7,
                        ),
                        child: TablerCard(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              // 질문
                              Text(
                                '이것은 무엇일까요?',
                                style: TextStyle(
                                  fontSize: isDesktop ? 24 : 20,
                                  fontWeight: FontWeight.bold,
                                  color: TablerColors.textPrimary,
                                ),
                                textAlign: TextAlign.center,
                              ),

                              SizedBox(height: 24),

                              // 애니메이션 영역
                              Container(
                                width: double.infinity,
                                height: isDesktop ? 280 : 240,
                                constraints: BoxConstraints(
                                  maxWidth: isDesktop ? 400 : 350,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.black,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: TablerColors.border,
                                  ),
                                ),
                                child: isLoading
                                    ? Center(
                                        child: CircularProgressIndicator(
                                          valueColor: AlwaysStoppedAnimation(
                                            TablerColors.primary,
                                          ),
                                        ),
                                      )
                                    : (base64Frames != null &&
                                              base64Frames!.isNotEmpty
                                          ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              child: Stack(
                                                children: [
                                                  Positioned.fill(
                                                    child: AnimationWidget(
                                                      key: animationKey,
                                                      frames: base64Frames!,
                                                    ),
                                                  ),
                                                  Positioned(
                                                    bottom: 8,
                                                    right: 8,
                                                    child: Container(
                                                      decoration: BoxDecoration(
                                                        color: Colors.black
                                                            .withOpacity(0.7),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              20,
                                                            ),
                                                      ),
                                                      child: IconButton(
                                                        onPressed: () {
                                                          animationKey
                                                              .currentState
                                                              ?.reset();
                                                        },
                                                        icon: Icon(
                                                          Icons.replay,
                                                          color: Colors.white,
                                                          size: 20,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                          : Center(
                                              child: Text(
                                                '영상 없음',
                                                style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            )),
                              ),

                              SizedBox(height: 16),

                              // 선택지
                              SizedBox(
                                height: 250,
                                child: GridView.builder(
                                  physics:
                                      NeverScrollableScrollPhysics(), // 스크롤 비활성화5
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        childAspectRatio: 4,
                                        crossAxisSpacing: 16,
                                        mainAxisSpacing: 16,
                                      ),
                                  itemCount: options.length,
                                  itemBuilder: (context, i) {
                                    final option = options[i];
                                    final isSelected = selectedOption == option;
                                    final isCorrectOption = option == correct;

                                    Color? backgroundColor;
                                    Color? borderColor;
                                    Color? textColor;

                                    if (answered && isSelected) {
                                      if (isCorrectOption) {
                                        backgroundColor = TablerColors.success
                                            .withOpacity(0.1);
                                        borderColor = TablerColors.success;
                                        textColor = TablerColors.success;
                                      } else {
                                        backgroundColor = TablerColors.danger
                                            .withOpacity(0.1);
                                        borderColor = TablerColors.danger;
                                        textColor = TablerColors.danger;
                                      }
                                    } else if (answered && isCorrectOption) {
                                      backgroundColor = TablerColors.success
                                          .withOpacity(0.1);
                                      borderColor = TablerColors.success;
                                      textColor = TablerColors.success;
                                    }

                                    return Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        onTap: answered
                                            ? null
                                            : () => onOptionSelected(option),
                                        borderRadius: BorderRadius.circular(8),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                backgroundColor ?? Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color:
                                                  borderColor ??
                                                  TablerColors.border,
                                              width: borderColor != null
                                                  ? 2
                                                  : 1,
                                            ),
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Expanded(
                                                  child: Text(
                                                    option,
                                                    style: TextStyle(
                                                      fontSize: isDesktop
                                                          ? 16
                                                          : 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          textColor ??
                                                          TablerColors
                                                              .textPrimary,
                                                    ),
                                                    textAlign: TextAlign.center,
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                                if (answered && isSelected)
                                                  Padding(
                                                    padding: EdgeInsets.only(
                                                      left: 8,
                                                    ),
                                                    child: Icon(
                                                      isCorrectOption
                                                          ? Icons.check_circle
                                                          : Icons.cancel,
                                                      color: isCorrectOption
                                                          ? TablerColors.success
                                                          : TablerColors.danger,
                                                      size: 18,
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
