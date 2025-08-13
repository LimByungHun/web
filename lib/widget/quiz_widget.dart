import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/service/animation_api.dart';
import 'package:sign_web/service/translate_api.dart';
import 'package:sign_web/widget/animation_widget.dart';
import 'package:sign_web/widget/camera_widget.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/service/study_api.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

enum QuizMode {
  videoToText, // 수어 애니메이션 보고 텍스트 선택
  textToSign, // 텍스트 보고 수어 동작 수행
}

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
  late List<QuizMode> quizModes; // 각 문제별 모드를 저장
  int index = 0;
  int correctCount = 0;

  // 현재 문제의 모드
  QuizMode get currentMode => quizModes[index];

  // VideoToText 모드용 변수들
  bool answered = false;
  String? selectedOption;
  late String correct;
  List<String> options = [];
  List<Uint8List>? base64Frames;
  bool isLoading = false;
  final GlobalKey<AnimationWidgetState> animationKey = GlobalKey();

  // TextToSign 모드용 변수들
  bool isAnalyzing = false;
  bool showCamera = false;
  String currentWord = '';
  bool? isLastAnswerCorrect;
  String? recognizedWord;

  @override
  void initState() {
    super.initState();
    initializeQuiz();
  }

  void initializeQuiz() {
    if (widget.words.isEmpty) {
      setState(() {
        quizList = [];
        quizModes = [];
        isLoading = false;
      });
      return;
    }

    quizList = List<Map<String, dynamic>>.from(widget.words)..shuffle();

    // 각 문제마다 랜덤하게 모드 할당
    quizModes = List.generate(
      quizList.length,
      (index) => QuizMode.values[DateTime.now().millisecondsSinceEpoch % 2],
    );

    // 더 랜덤하게 섞기
    for (int i = 0; i < quizModes.length; i++) {
      if ((i + DateTime.now().microsecond) % 2 == 0) {
        quizModes[i] = QuizMode.videoToText;
      } else {
        quizModes[i] = QuizMode.textToSign;
      }
    }

    setupCurrentQuestion();
  }

  void setupCurrentQuestion() {
    if (currentMode == QuizMode.videoToText) {
      setupVideoToTextQuestion();
    } else {
      setupTextToSignQuestion();
    }
  }

  // VideoToText 모드 설정
  void setupVideoToTextQuestion() async {
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

  // TextToSign 모드 설정
  void setupTextToSignQuestion() {
    if (quizList.isEmpty || index >= quizList.length) {
      return;
    }

    final current = quizList[index];
    setState(() {
      currentWord = current['word']?.toString() ?? '';
      isLastAnswerCorrect = null;
      recognizedWord = null;
      showCamera = false;
      isAnalyzing = false;
    });
  }

  // VideoToText 모드에서 옵션 선택
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

  // TextToSign 모드에서 카메라 프레임 처리
  Future<void> handleCameraFrames(List<Uint8List> frames) async {
    if (isAnalyzing) return;

    setState(() {
      isAnalyzing = true;
      showCamera = false;
    });

    try {
      final base64Frames = frames.map((frame) => base64Encode(frame)).toList();

      final sendResult = await TranslateApi.sendFrames(base64Frames);
      print('프레임 전송 결과: $sendResult');

      await Future.delayed(Duration(seconds: 2));
      final translateResult = await TranslateApi.translateLatest2();

      final recognized = translateResult?['korean']?.toString().trim() ?? '';
      final isCorrect = recognized.toLowerCase() == currentWord.toLowerCase();

      setState(() {
        isAnalyzing = false;
        recognizedWord = recognized;
        isLastAnswerCorrect = isCorrect;
        if (isCorrect) correctCount++;
      });

      await Future.delayed(Duration(seconds: 3));

      if (mounted) {
        onNext();
      }
    } catch (e) {
      print('수어 인식 오류: $e');
      setState(() {
        isAnalyzing = false;
        recognizedWord = '인식 실패';
        isLastAnswerCorrect = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('수어 인식 중 오류가 발생했습니다: $e'),
            backgroundColor: TablerColors.danger,
          ),
        );
      }

      await Future.delayed(Duration(seconds: 3));
      if (mounted) {
        onNext();
      }
    }
  }

  void onNext() async {
    if (index < quizList.length - 1) {
      setState(() {
        index++;
      });

      setupCurrentQuestion();
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
            msg: "통합 퀴즈 완료! 정답률: $percent%",
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
      return _buildEmptyState();
    }

    if (currentMode == QuizMode.textToSign && isAnalyzing) {
      return _buildAnalyzingState();
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 700;

    return Scaffold(
      backgroundColor: TablerColors.background,
      appBar: widget.showAppBar ? _buildAppBar() : null,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minHeight:
                  MediaQuery.of(context).size.height -
                  (widget.showAppBar ? 140 : 140),
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
                      _buildProgress(),
                      SizedBox(height: 24),
                      currentMode == QuizMode.videoToText
                          ? _buildVideoToTextContent(isDesktop)
                          : _buildTextToSignContent(isDesktop),
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

  Widget _buildEmptyState() {
    return Scaffold(
      backgroundColor: TablerColors.background,
      appBar: widget.showAppBar ? _buildAppBar() : null,
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

  Widget _buildAnalyzingState() {
    return Scaffold(
      backgroundColor: TablerColors.background,
      appBar: widget.showAppBar ? _buildAppBar() : null,
      body: Center(
        child: TablerCard(
          padding: EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: TablerColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(40),
                ),
                child: Center(
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation(TablerColors.primary),
                    strokeWidth: 4,
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                "수어 동작을 분석하고 있습니다",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: TablerColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                "잠시만 기다려주세요...",
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text('퀴즈'),
      backgroundColor: Colors.white,
      foregroundColor: TablerColors.textPrimary,
      elevation: 1,
    );
  }

  Widget _buildProgress() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    '문제 ${index + 1}/${quizList.length}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: TablerColors.textSecondary,
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: currentMode == QuizMode.videoToText
                          ? TablerColors.info.withOpacity(0.1)
                          : TablerColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: currentMode == QuizMode.videoToText
                            ? TablerColors.info.withOpacity(0.3)
                            : TablerColors.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      currentMode == QuizMode.videoToText ? '보기' : '실습',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: currentMode == QuizMode.videoToText
                            ? TablerColors.info
                            : TablerColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: TablerColors.success.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: TablerColors.success.withOpacity(0.3),
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
            valueColor: AlwaysStoppedAnimation(TablerColors.primary),
          ),
        ],
      ),
    );
  }

  // VideoToText 모드 콘텐츠
  Widget _buildVideoToTextContent(bool isDesktop) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: TablerCard(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
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

            Container(
              width: double.infinity,
              height: isDesktop ? 280 : 240,
              constraints: BoxConstraints(maxWidth: isDesktop ? 400 : 350),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TablerColors.border),
              ),
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                          TablerColors.primary,
                        ),
                      ),
                    )
                  : (base64Frames != null && base64Frames!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
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
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: IconButton(
                                      onPressed: () {
                                        animationKey.currentState?.reset();
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

            SizedBox(
              height: 250,
              child: GridView.builder(
                physics: NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
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
                      backgroundColor = TablerColors.success.withOpacity(0.1);
                      borderColor = TablerColors.success;
                      textColor = TablerColors.success;
                    } else {
                      backgroundColor = TablerColors.danger.withOpacity(0.1);
                      borderColor = TablerColors.danger;
                      textColor = TablerColors.danger;
                    }
                  } else if (answered && isCorrectOption) {
                    backgroundColor = TablerColors.success.withOpacity(0.1);
                    borderColor = TablerColors.success;
                    textColor = TablerColors.success;
                  }

                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: answered ? null : () => onOptionSelected(option),
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        decoration: BoxDecoration(
                          color: backgroundColor ?? Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: borderColor ?? TablerColors.border,
                            width: borderColor != null ? 2 : 1,
                          ),
                        ),
                        child: Center(
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Text(
                                  option,
                                  style: TextStyle(
                                    fontSize: isDesktop ? 16 : 14,
                                    fontWeight: FontWeight.w500,
                                    color:
                                        textColor ?? TablerColors.textPrimary,
                                  ),
                                  textAlign: TextAlign.center,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (answered && isSelected)
                                Padding(
                                  padding: EdgeInsets.only(left: 8),
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
    );
  }

  // TextToSign 모드 콘텐츠
  Widget _buildTextToSignContent(bool isDesktop) {
    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        minHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: TablerCard(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Container(
              padding: EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: TablerColors.primary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text(
                    '다음 단어를 수어로 표현해주세요',
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : 16,
                      color: Colors.white70,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 12),
                  Text(
                    currentWord,
                    style: TextStyle(
                      fontSize: isDesktop ? 36 : 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            SizedBox(height: 24),

            Container(
              width: double.infinity,
              height: isDesktop ? 320 : 280,
              constraints: BoxConstraints(maxWidth: isDesktop ? 500 : 400),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: TablerColors.border, width: 2),
              ),
              child: showCamera
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CameraWidget(
                        continuousMode: true,
                        onFramesAvailable: handleCameraFrames,
                      ),
                    )
                  : Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: TablerColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(32),
                              border: Border.all(
                                color: TablerColors.primary.withOpacity(0.3),
                                width: 2,
                              ),
                            ),
                            child: Icon(
                              Icons.videocam,
                              size: 32,
                              color: TablerColors.primary,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text(
                            '카메라를 시작하여\n수어 동작을 보여주세요',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: TablerColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
            ),

            SizedBox(height: 20),

            if (isLastAnswerCorrect != null) _buildResultDisplay(),

            _buildTextToSignControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildResultDisplay() {
    final isCorrect = isLastAnswerCorrect == true;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: (isCorrect ? TablerColors.success : TablerColors.danger)
            .withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: (isCorrect ? TablerColors.success : TablerColors.danger)
              .withOpacity(0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isCorrect ? Icons.check_circle : Icons.cancel,
            color: isCorrect ? TablerColors.success : TablerColors.danger,
            size: 24,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isCorrect ? '정답입니다!' : '틀렸습니다',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isCorrect
                        ? TablerColors.success
                        : TablerColors.danger,
                  ),
                ),
                if (recognizedWord?.isNotEmpty == true)
                  Text(
                    '인식된 단어: $recognizedWord',
                    style: TextStyle(
                      fontSize: 14,
                      color: TablerColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextToSignControls() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: TablerButton(
            text: showCamera ? '카메라 중지' : '카메라 시작',
            icon: showCamera ? Icons.videocam_off : Icons.videocam,
            outline: showCamera,
            type: showCamera
                ? TablerButtonType.danger
                : TablerButtonType.primary,
            onPressed: () => setState(() => showCamera = !showCamera),
          ),
        ),
      ],
    );
  }
}
