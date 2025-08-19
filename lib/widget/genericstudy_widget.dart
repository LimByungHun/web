import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sign_web/service/animation_api.dart';
import 'package:sign_web/service/translate_api.dart';
import 'package:sign_web/widget/animation_widget.dart';
import 'package:sign_web/screen/study_screen.dart';
import 'package:sign_web/service/study_api.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

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
  bool isLoading = false;

  final GlobalKey<AnimationWidgetState> animationKey = GlobalKey();
  List<Uint8List>? base64Frames;

  bool isCameraOn = false;
  CameraController? cameraController;

  final List<Uint8List> frameBuffer = [];
  static const int batchSize = 20;
  static const int maxBuffer = 120;
  bool forcestop = false;
  Future<void> sendQueue = Future.value();
  String frameStatus = '';
  bool isCollectingFrames = false;
  bool isCapturingFrame = false;

  // 프레임 캡처 타이머
  Timer? frameTimer;

  List<String> recognizedWords = [];
  String? lastShownword;

  // 카메라 테두리 색상
  Color get cameraBorderColor {
    if (!isCameraOn) return TablerColors.border;
    return TablerColors.success; // 카메라 켜져 있을 때 녹색
  }

  double get cameraBorderWidth => isCameraOn ? 3 : 2;

  @override
  void initState() {
    super.initState();
    pageCtrl = PageController(initialPage: 0);
    loadAnimationFrames(widget.items[pageIndex]);
  }

  @override
  void dispose() {
    forcestop = true;
    stopFrameCapture();
    stopCamera();
    pageCtrl.dispose();
    super.dispose();
  }

  Future<void> onNext() async {
    if (pageIndex < widget.items.length - 1) {
      // 페이지 넘기기
      await pageCtrl.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      try {
        await StudyApi.completeStudy(sid: widget.sid, step: widget.step);
        print("학습 완료 저장 성공");
      } catch (e) {
        print("학습 완료 저장 실패: $e");
      }

      if (!mounted) return;

      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      final screenState = context.findAncestorStateOfType<StudyScreenState>();
      if (screenState != null) {
        await Future.delayed(const Duration(milliseconds: 100));
        screenState.nextStep(); // 여기서 GoRouter로 이동 처리됨
      } else {
        await Future.delayed(const Duration(milliseconds: 100));
        if (mounted) {
          GoRouter.of(context).go('/home');
        }
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

  Future<void> sendFrames(List<Uint8List> frames) async {
    try {
      debugPrint("프레임 ${frames.length}개 서버로 전송 시도...");
      final payload = frames.map((f) => base64Encode(f)).toList();
      final res = await TranslateApi.sendFrames(payload);

      if (res == null) {
        debugPrint('서버 응답 실패: result is null');
        return;
      }

      final String korean = (res['korean'] as String? ?? '').trim();

      if (korean.isEmpty ||
          korean.contains('인식된 단어가 없습니다') ||
          korean.contains('인식 실패') ||
          korean.contains('없음') ||
          korean.toLowerCase().contains('no word') ||
          korean.toLowerCase().contains('unknown')) {
        debugPrint('필터링된 결과: $korean');
        return;
      }

      if (korean == lastShownword) {
        debugPrint('중복 결과 무시: $korean');
        return;
      }

      if (!mounted) return;

      setState(() {
        lastShownword = korean;
        if (!recognizedWords.contains(korean)) {
          recognizedWords.add(korean);
        }
        frameStatus = '인식 완료: $korean';
      });
      Future.delayed(Duration(seconds: 2), () {
        if (mounted && isCameraOn) {
          setState(() {
            frameStatus = "프레임 수집 중... (실시간 인식)";
          });
        }
      });
    } catch (e) {
      debugPrint('프레임 전송 중 오류: $e');
      setState(() {
        frameStatus = '전송 오류 발생';
      });
    }
  }

  // 전송 직렬화
  void enqueueSend(List<Uint8List> frames) {
    sendQueue = sendQueue.then((_) => sendFrames(frames));
  }

  // 프레임 캡처
  void startFrameCapture() {
    frameTimer?.cancel();
    forcestop = false;
    frameTimer = Timer.periodic(const Duration(milliseconds: 33), (
      timer,
    ) async {
      if (forcestop ||
          !isCameraOn ||
          cameraController == null ||
          isCapturingFrame)
        return;

      isCapturingFrame = true;
      try {
        final picture = await cameraController!.takePicture();
        final bytes = await picture.readAsBytes();

        if (frameBuffer.length >= maxBuffer) {
          final int drop = frameBuffer.length - maxBuffer + 1;
          frameBuffer.removeRange(0, drop);
        }
        frameBuffer.add(bytes);

        if (frameBuffer.length >= batchSize) {
          final chunk = List<Uint8List>.from(frameBuffer.take(batchSize));
          frameBuffer.removeRange(0, batchSize);
          enqueueSend(chunk);
        } else {
          if (mounted && frameBuffer.length % 15 == 0) {
            setState(() {
              frameStatus = "프레임 수집 중... (${frameBuffer.length}/$batchSize)";
              isCollectingFrames = true;
            });
          }
        }
      } catch (e) {
        debugPrint('프레임 캡처 오류: $e');
        if (mounted && !frameStatus.contains('오류')) {
          setState(() {
            frameStatus = "프레임 캡처 오류 (재시도 중)";
          });
        }
      } finally {
        isCapturingFrame = false;
      }
    });
  }

  void stopFrameCapture() {
    forcestop = true;
    frameTimer?.cancel();
    frameTimer = null;
    isCapturingFrame = false;
  }

  Future<void> startCamera() async {
    try {
      setState(() {
        lastShownword = null;
        recognizedWords.clear();
        frameStatus = "카메라 초기화 중...";
      });

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw Exception('카메라를 찾을 수 없습니다');
      }

      final front = cameras.firstWhere(
        (cam) => cam.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      cameraController = CameraController(
        front,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await cameraController!.initialize();

      startFrameCapture();

      setState(() {
        isCameraOn = true;
        frameStatus = "준비완료 - 수어 동작을 시작하세요";
      });
    } catch (e) {
      debugPrint("카메라 초기화 실패: $e");
      setState(() {
        frameStatus = "카메라 오류: $e";
      });
    }
  }

  Future<void> stopCamera() async {
    forcestop = true;
    if (cameraController == null) return;

    setState(() {
      frameStatus = "카메라 중지 중...";
      isCollectingFrames = false;
      isCameraOn = false;
    });

    stopFrameCapture();

    try {
      await sendQueue;
    } catch (_) {}

    if (frameBuffer.isNotEmpty) {
      try {
        final leftover = List<Uint8List>.from(frameBuffer);
        frameBuffer.clear();
        await sendFrames(leftover);
      } catch (e) {
        debugPrint('잔여 프레임 전송 실패: $e');
      }
    }

    await Future.delayed(const Duration(milliseconds: 300));

    try {
      await cameraController!.dispose();
      debugPrint('컨트롤러 dispose 완료');
    } catch (e) {
      debugPrint('컨트롤러 dispose 오류: $e');
    } finally {
      cameraController = null;
    }

    if (mounted) {
      setState(() {
        isCameraOn = false;
        isCollectingFrames = false;
        frameStatus = "";
      });
    }
  }

  Future<void> analyzeFrames() async {
    try {
      final expected = widget.items[pageIndex];

      await stopCamera();

      // 최종 번역 결과
      setState(() {
        frameStatus = "번역 결과 확인 중...";
      });

      final result = await TranslateApi.translateLatest2();
      if (result != null) {
        final recognizedWord = result['korean'] is List
            ? (result['korean'] as List).join(' ')
            : result['korean']?.toString() ?? '';

        final isCorrect =
            recognizedWord.toLowerCase().trim() ==
            expected.toLowerCase().trim();

        if (mounted) {
          await showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color:
                          (isCorrect
                                  ? TablerColors.success
                                  : TablerColors.danger)
                              .withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Icon(
                      isCorrect ? Icons.check_circle : Icons.cancel,
                      color: isCorrect
                          ? TablerColors.success
                          : TablerColors.danger,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 12),
                  Text(
                    isCorrect ? '정답입니다!' : '다시 시도해주세요',
                    style: TextStyle(
                      color: isCorrect
                          ? TablerColors.success
                          : TablerColors.danger,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: TablerColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '인식된 단어: ',
                          style: TextStyle(
                            fontSize: 14,
                            color: TablerColors.textSecondary,
                          ),
                        ),
                        Text(
                          recognizedWord.isEmpty ? '인식 실패' : recognizedWord,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: TablerColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!isCorrect) ...[
                    SizedBox(height: 16),
                    Text(
                      '정확한 수어 동작을 다시 시도해주세요',
                      style: TextStyle(
                        fontSize: 14,
                        color: TablerColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
              actions: [
                if (!isCorrect)
                  TablerButton(
                    text: '다시 시도',
                    outline: true,
                    onPressed: () {
                      Navigator.of(context).pop();
                      startCamera();
                    },
                  ),
                if (isCorrect)
                  TablerButton(
                    text: '확인',
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
              ],
            ),
          );
        }

        // 정답이면 다음 페이지로 이동
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
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('번역 결과를 가져올 수 없습니다'),
              backgroundColor: TablerColors.danger,
            ),
          );
        }
      }
    } catch (e) {
      print('분석 오류: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('분석 중 오류가 발생했습니다: $e'),
            backgroundColor: TablerColors.danger,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final item = widget.items[pageIndex];

    return Container(
      color: TablerColors.background,
      child: Column(
        children: [
          // 진행 상황 표시
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: TablerColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${pageIndex + 1}/${widget.items.length}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: TablerColors.primary,
                    ),
                  ),
                ),
                SizedBox(width: 20),
                Expanded(
                  child: LinearProgressIndicator(
                    value: (pageIndex + 1) / widget.items.length,
                    backgroundColor: TablerColors.border,
                    valueColor: AlwaysStoppedAnimation(TablerColors.primary),
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: PageView.builder(
              key: PageStorageKey('study_pageview'),
              controller: pageCtrl,
              itemCount: widget.items.length,
              onPageChanged: (idx) {
                setState(() => pageIndex = idx);
                loadAnimationFrames(widget.items[idx]);
                if (isCameraOn) {
                  stopCamera();
                }
              },
              itemBuilder: (_, i) {
                return SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(isWide ? 32 : 16),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isWide ? 1400 : double.infinity,
                        ),
                        child: Column(
                          children: [
                            // 단어 제목
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                vertical: 16,
                                horizontal: 24,
                              ),
                              decoration: BoxDecoration(
                                color: TablerColors.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                item,
                                style: TextStyle(
                                  fontSize: isWide ? 32 : 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),

                            SizedBox(height: 20),

                            // 메인 콘텐츠 영역
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.all(isWide ? 32 : 20),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: TablerColors.border),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 12,
                                    offset: Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: isWide
                                  ? Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          flex: 1,
                                          child: buildVideoSection(),
                                        ),
                                        SizedBox(width: 24),
                                        Expanded(
                                          flex: 1,
                                          child: buildCameraSection(),
                                        ),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        buildVideoSection(),
                                        SizedBox(height: 20),
                                        buildCameraSection(),
                                      ],
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

          // 하단 버튼 영역
          Container(
            width: double.infinity,
            color: Colors.white,
            padding: EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 600),
                child: Row(
                  children: [
                    if (widget.onReview != null)
                      Expanded(
                        child: TablerButton(
                          text: "복습하기",
                          outline: true,
                          onPressed: widget.onReview,
                        ),
                      ),
                    if (widget.onReview != null) SizedBox(width: 16),
                    Expanded(
                      child: TablerButton(
                        text: pageIndex < widget.items.length - 1
                            ? '다음'
                            : '학습 완료',
                        icon: pageIndex < widget.items.length - 1
                            ? Icons.arrow_forward
                            : Icons.check,
                        onPressed: onNext,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildVideoSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final videoHeight = isWide ? 400.0 : 300.0;

    return Column(
      children: [
        Text(
          '수어 동작 보기',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: TablerColors.textPrimary,
          ),
        ),
        SizedBox(height: 12),
        Container(
          width: double.infinity,
          height: videoHeight,
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: TablerColors.border),
          ),
          child: isLoading
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation(
                          TablerColors.primary,
                        ),
                      ),
                      SizedBox(height: 12),
                      Text(
                        '영상 로딩 중...',
                        style: TextStyle(color: Colors.white70, fontSize: 14),
                      ),
                    ],
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
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.video_library_outlined,
                              color: Colors.white54,
                              size: 40,
                            ),
                            SizedBox(height: 8),
                            Text(
                              '영상을 불러올 수 없습니다',
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )),
        ),
        SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: TablerColors.info.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: TablerColors.info.withOpacity(0.3)),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: TablerColors.info, size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '수어 동작을 자세히 관찰하고 따라해 보세요',
                  style: TextStyle(
                    fontSize: 13,
                    color: TablerColors.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget buildCameraSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 900;
    final cameraHeight = isWide ? 400.0 : 300.0;

    return Column(
      children: [
        Text(
          '수어 동작 연습하기',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: TablerColors.textPrimary,
          ),
        ),
        SizedBox(height: 12),

        // 카메라 영역
        SizedBox(
          width: double.infinity,
          height: cameraHeight,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: cameraBorderColor,
                width: cameraBorderWidth,
              ),
              boxShadow: isCameraOn
                  ? [
                      BoxShadow(
                        color: cameraBorderColor.withOpacity(0.3),
                        blurRadius: 12,
                        spreadRadius: 1,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Container(
                decoration: BoxDecoration(color: Colors.black),
                child:
                    isCameraOn && cameraController?.value.isInitialized == true
                    ? Stack(
                        children: [
                          Positioned.fill(
                            child: CameraPreview(cameraController!),
                          ),
                        ],
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
                            SizedBox(height: 12),
                            Text(
                              '카메라로 수어 연습하기',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: TablerColors.textPrimary,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '아래 버튼을 눌러 카메라를 시작하세요',
                              style: TextStyle(
                                fontSize: 13,
                                color: TablerColors.textSecondary,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
        SizedBox(height: 12),

        SizedBox(
          width: double.infinity,
          child: TablerButton(
            text: isCameraOn ? '분석하기' : '카메라 시작',
            icon: isCameraOn ? Icons.analytics : Icons.videocam,
            outline: !isCameraOn,
            onPressed: () async {
              if (isCameraOn) {
                await analyzeFrames();
              } else {
                await startCamera();
              }
            },
          ),
        ),
      ],
    );
  }
}
