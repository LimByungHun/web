import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_web/service/animation_api.dart';
import 'package:sign_web/service/translate_api.dart';
import 'package:sign_web/widget/animation_widget.dart';

import 'package:sign_web/screen/study_screen.dart';
import 'package:sign_web/service/study_api.dart';
import 'package:sign_web/widget/camera_widget.dart';

class GenericStudyWidget extends StatefulWidget {
  final List<String> items;
  final int sid;
  final int step;
  final VoidCallback? onReview;
  const GenericStudyWidget({
    super.key,
    required this.items,
    required this.sid,
    required this.step,
    this.onReview,
  });

  @override
  State<GenericStudyWidget> createState() => GenericStudyWidgetState();
}

class GenericStudyWidgetState extends State<GenericStudyWidget> {
  late PageController pageCtrl;
  int pageIndex = 0;
  bool showCamera = false;
  bool isAnalyzing = false;
  bool isLoading = false;

  final GlobalKey<AnimationWidgetState> animationKey = GlobalKey();
  List<Uint8List>? base64Frames;

  @override
  void initState() {
    super.initState();
    pageCtrl = PageController(initialPage: 0);
    loadAnimationFrames(widget.items[pageIndex]);
  }

  Future<void> onNext() async {
    if (pageIndex < widget.items.length - 1) {
      pageCtrl.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      try {
        await StudyApi.completeStudy(sid: widget.sid, step: widget.step);
        print("학습 완료 저장 성공");
      } catch (e) {
        print("학습 완료 저장 실패: $e");
      }

      final screenState = context.findAncestorStateOfType<StudyScreenState>();
      if (screenState != null) {
        screenState.nextStep();
      } else {
        GoRouter.of(context).go('/home');
      }
    }
  }

  Future<void> loadAnimationFrames(String wordText) async {
    setState(() {
      isLoading = true;
      base64Frames = null;
    });
    final result = await AnimationApi.loadAnimation(wordText);
    if (result != null) {
      setState(() {
        base64Frames = result.map((b64) => base64Decode(b64)).toList();
      });
    }
    setState(() => isLoading = false);
  }

  @override
  void dispose() {
    pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWide = screenWidth > 900;
    final usableHeight = screenHeight - 350;
    final maxChildWidth = (screenWidth - 64) / 2;
    final adjustedSize = usableHeight.clamp(150.0, maxChildWidth);
    final item = widget.items[pageIndex];

    if (isAnalyzing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text("동작 확인중! 조금만 기다려주세요", style: TextStyle(fontSize: 18)),
          ],
        ),
      );
    }

    Widget videoWidget = SizedBox(
      width: adjustedSize,
      height: adjustedSize,
      child: base64Frames != null
          ? Column(
              children: [
                FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: adjustedSize,
                    height: adjustedSize,
                    child: AnimationWidget(
                      key: animationKey,
                      frames: base64Frames!,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    animationKey.currentState?.reset();
                  },
                  icon: Icon(Icons.replay),
                  label: Text('다시보기'),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );

    Widget cameraControlWidget = Column(
      children: [
        IconButton(
          icon: const Icon(Icons.videocam, size: 36),
          onPressed: () => setState(() => showCamera = true),
        ),
        if (showCamera)
          SizedBox(
            width: adjustedSize,
            height: adjustedSize,
            child: CameraWidget(
              continuousMode: true, // 연속 모드로 프레임들을 받음
              onFramesAvailable: (frames) async {
                // 프레임들이 준비되면 바로 서버로 전송
                setState(() => isAnalyzing = true);

                try {
                  final expected = widget.items[pageIndex];

                  // 프레임들을 base64로 변환
                  final base64Frames = frames
                      .map((frame) => base64Encode(frame))
                      .toList();

                  // 서버로 전송
                  final sendResult = await TranslateApi.sendFrames(
                    base64Frames,
                  );
                  print('프레임 전송 결과: $sendResult');

                  // 분석 결과 가져오기
                  await Future.delayed(Duration(seconds: 1)); // 서버 처리 대기
                  final translateResult = await TranslateApi.translateLatest();

                  final recognizedWord = translateResult?['korean'] ?? '';
                  final isCorrect =
                      recognizedWord.toLowerCase().trim() ==
                      expected.toLowerCase().trim();

                  setState(() {
                    isAnalyzing = false;
                    showCamera = false;
                  });

                  if (!mounted) return;

                  await showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text(
                        isCorrect ? '정답입니다!' : '다시 시도해주세요',
                        style: TextStyle(
                          color: isCorrect ? Colors.green : Colors.red,
                        ),
                      ),
                      content: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            isCorrect ? '✓' : '✗',
                            style: TextStyle(
                              fontSize: 60,
                              fontWeight: FontWeight.bold,
                              color: isCorrect ? Colors.green : Colors.red,
                            ),
                          ),
                          SizedBox(height: 16),
                          Text('예상: $expected'),
                          Text('인식: $recognizedWord'),
                          if (!isCorrect)
                            Padding(
                              padding: EdgeInsets.only(top: 10),
                              child: Text(
                                '다시 시도해주세요',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                        ],
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: Text('확인'),
                        ),
                      ],
                    ),
                  );

                  if (isCorrect) {
                    await Future.delayed(Duration(milliseconds: 500));
                    if (pageIndex < widget.items.length - 1) {
                      pageCtrl.nextPage(
                        duration: Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                      );
                    } else {
                      await onNext();
                    }
                  }
                } catch (e) {
                  print('분석 오류: $e');
                  setState(() {
                    isAnalyzing = false;
                    showCamera = false;
                  });

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('분석 중 오류가 발생했습니다: $e')),
                    );
                  }
                }
              },
            ),
          )
        else
          const Text('카메라를 실행하려면 아이콘을 누르세요', style: TextStyle(fontSize: 12)),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            key: PageStorageKey('study_pageview'),
            controller: pageCtrl,
            itemCount: widget.items.length,
            onPageChanged: (idx) {
              setState(() => pageIndex = idx);
              loadAnimationFrames(widget.items[idx]);
            },
            itemBuilder: (_, i) {
              return SingleChildScrollView(
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          item,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (isWide)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(child: videoWidget),
                                const SizedBox(width: 24),
                                Flexible(child: cameraControlWidget),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: [
                              videoWidget,
                              const SizedBox(height: 5),
                              cameraControlWidget,
                            ],
                          ),
                        const SizedBox(height: 10),
                        Text(
                          '$item 수어 표현 방법 적어야함',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: onNext,
            child: Text(pageIndex < widget.items.length - 1 ? '다음' : '학습 완료'),
          ),
        ),
        if (widget.onReview != null) SizedBox(width: 12),
        if (widget.onReview != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReview,
                    child: const Text("복습하기"),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
