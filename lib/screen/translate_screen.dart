import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sign_web/widget/animation_widget.dart';
import 'package:sign_web/service/translate_api.dart';
import 'package:sign_web/widget/sidebar_widget.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});
  @override
  State<TranslateScreen> createState() => TranslateScreenWebState();
}

class TranslateScreenWebState extends State<TranslateScreen> {
  // 기본 상태 변수들
  bool isSignToKorean = true;
  bool isCameraOn = false;
  bool isTranslating = false;
  CameraController? cameraController;

  // 프레임 처리 (모바일 방식 채택)
  final List<Uint8List> frameBuffer = [];
  static const int batchSize = 45; // 서버로 보낼 배치 크기
  static const int maxBuffer = 120; // 메모리 보호 상한
  bool busy = false; // 프레임 콜백 배압 플래그

  // 전송 큐(직렬화) - 모바일과 동일
  Future<void> sendQueue = Future.value();

  // UI 및 번역 결과
  final TextEditingController inputController = TextEditingController();
  final List<String> langs = ['한국어', 'English', '日本語', '中文'];
  String selectedLang = '한국어';

  String? resultKorean;
  String? resultEnglish;
  String? resultJapanese;
  String? resultChinese;
  String? lastShownword;

  final GlobalKey<AnimationWidgetState> animationKey =
      GlobalKey<AnimationWidgetState>();
  List<Uint8List> decodedFrames = [];

  // 웹 전용 프레임 캡처 타이머 (이미지 스트림 대신)
  Timer? frameTimer;
  bool _isCapturingFrame = false;

  // 실시간 번역 폴링
  Timer? _recognitionPollingTimer;

  // 상태 표시
  String frameStatus = '';
  bool isCollectingFrames = false;

  // 존재 감지 (모바일과 동일한 로직)
  bool isSubjectPresent = false;
  int? lastFrameSample;
  int presenceScore = 0;
  static const int presenceScoreEnter = 60;
  static const int presenceScoreExit = 30;
  static const int presenceScoreInc = 12;
  static const int presenceScoreDecay = 6;

  Color get _cameraBorderColor {
    if (!isCameraOn) return TablerColors.border;
    return isSubjectPresent ? TablerColors.success : TablerColors.danger;
  }

  double get _cameraBorderWidth => isCameraOn ? 3 : 2;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _stopFrameCapture();
    _stopRealtimePolling();
    stopCamera();
    inputController.dispose();
    super.dispose();
  }

  String? selectedTranslation() {
    switch (selectedLang) {
      case '한국어':
        return resultKorean;
      case 'English':
        return resultEnglish;
      case '日本語':
        return resultJapanese;
      case '中文':
        return resultChinese;
      default:
        return resultKorean;
    }
  }

  // 프레임 샘플링 (모바일과 동일)
  int _computeSample(Uint8List bytes) {
    int sum = 0;
    final int step = bytes.length > 200000 ? 400 : 200;
    for (int i = 0; i < bytes.length; i += step) {
      sum += bytes[i];
    }
    return sum;
  }

  // 존재 감지 업데이트 (모바일과 동일)
  void _updatePresence(Uint8List bytes) {
    final int sample = _computeSample(bytes);

    if (lastFrameSample != null) {
      final int diff = (sample - lastFrameSample!).abs();
      final int step = bytes.length > 200000 ? 400 : 200;
      final int samples = (bytes.length + step - 1) ~/ step;
      final int dynamicThreshold = samples * 8;

      final bool hasMotion = diff > dynamicThreshold;
      if (hasMotion) {
        presenceScore = (presenceScore + presenceScoreInc).clamp(0, 100);
      } else {
        presenceScore = (presenceScore - presenceScoreDecay).clamp(0, 100);
      }

      final bool enter = presenceScore >= presenceScoreEnter;
      final bool exit = presenceScore <= presenceScoreExit;

      bool changed = false;
      if (enter && !isSubjectPresent) {
        isSubjectPresent = true;
        changed = true;
      } else if (exit && isSubjectPresent) {
        isSubjectPresent = false;
        changed = true;
      }

      if (changed && mounted) setState(() {});
    }

    lastFrameSample = sample;
  }

  // 서버 전송 함수 (모바일과 동일)
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
      if (korean.isEmpty) return;
      if (korean == lastShownword) return;
      if (!mounted) return;

      setState(() {
        lastShownword = korean;
        resultKorean = korean;
        resultEnglish = (res['english'] as String?) ?? '';
        resultJapanese = (res['japanese'] as String?) ?? '';
        resultChinese = (res['chinese'] as String?) ?? '';
        frameStatus = '';
      });
    } catch (e) {
      debugPrint('프레임 전송 중 오류: $e');
      setState(() {
        frameStatus = '전송 오류 발생';
      });
    }
  }

  // 전송 직렬화 (모바일과 동일)
  void _enqueueSend(List<Uint8List> frames) {
    sendQueue = sendQueue.then((_) => sendFrames(frames));
  }

  // 웹용 프레임 캡처 시작
  void _startFrameCapture() {
    frameTimer?.cancel();
    frameTimer = Timer.periodic(const Duration(milliseconds: 111), (
      timer,
    ) async {
      if (!isCameraOn || cameraController == null || _isCapturingFrame) return;

      _isCapturingFrame = true;
      try {
        final picture = await cameraController!.takePicture();
        final bytes = await picture.readAsBytes();

        // 존재 감지 업데이트
        _updatePresence(bytes);

        // 프레임 버퍼 관리 (모바일과 동일한 로직)
        if (frameBuffer.length >= maxBuffer) {
          final int drop = frameBuffer.length - maxBuffer + 1;
          frameBuffer.removeRange(0, drop);
        }
        frameBuffer.add(bytes);

        // 상태 업데이트
        if (mounted) {
          setState(() {
            isCollectingFrames = true;
            frameStatus = "프레임 수집 중... (${frameBuffer.length}/$batchSize)";
          });
        }

        // 배치 전송
        while (frameBuffer.length >= batchSize) {
          final chunk = List<Uint8List>.from(frameBuffer.take(batchSize));
          frameBuffer.removeRange(0, batchSize);
          _enqueueSend(chunk);

          if (mounted) {
            setState(() {
              frameStatus = "분석 중... 잠시만 기다려주세요";
            });
          }
        }
      } catch (e) {
        debugPrint('웹 프레임 캡처 오류: $e');
      } finally {
        _isCapturingFrame = false;
      }
    });
  }

  void _stopFrameCapture() {
    frameTimer?.cancel();
    frameTimer = null;
  }

  // 실시간 폴링 (모바일과 동일)
  void _startRealtimePolling() {
    _recognitionPollingTimer?.cancel();
    _recognitionPollingTimer = Timer.periodic(const Duration(seconds: 3), (
      timer,
    ) async {
      if (!mounted || !isCameraOn || !isSignToKorean) return;

      try {
        final latest = await TranslateApi.translateLatest();
        if (latest == null) return;

        String? korean;
        final k = latest['korean'];
        if (k is List) {
          korean = k.join(' ');
        } else if (k is String) {
          korean = k.trim();
        }

        if (korean == null || korean.isEmpty) return;
        if (korean == lastShownword) return;

        setState(() {
          lastShownword = korean;
          resultKorean = korean;
          resultEnglish = latest['english'] ?? '';
          resultJapanese = latest['japanese'] ?? '';
          resultChinese = latest['chinese'] ?? '';
        });
      } catch (e) {
        debugPrint('실시간 폴링 오류: $e');
      }
    });
  }

  void _stopRealtimePolling() {
    _recognitionPollingTimer?.cancel();
    _recognitionPollingTimer = null;
  }

  Future<void> startCamera() async {
    try {
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
        // 웹에서는 JPEG 형식 사용
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await cameraController!.initialize();

      // 웹용 프레임 캡처 시작
      _startFrameCapture();

      if (isSignToKorean) {
        _startRealtimePolling();
      }

      setState(() {
        isCameraOn = true;
        frameStatus = "카메라 준비 완료! 수어 동작을 시작하세요";
      });

      Fluttertoast.showToast(
        msg: '카메라가 켜졌습니다',
        backgroundColor: TablerColors.success,
        textColor: Colors.white,
      );
    } catch (e) {
      debugPrint("카메라 초기화 실패: $e");
      setState(() {
        frameStatus = "카메라 오류";
      });
      Fluttertoast.showToast(
        msg: '카메라를 켤 수 없습니다',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
    }
  }

  Future<void> stopCamera() async {
    if (cameraController == null) return;

    setState(() {
      frameStatus = "카메라 중지 중...";
      isCollectingFrames = false;
    });

    _stopFrameCapture();
    _stopRealtimePolling();

    // 전송 큐 대기
    try {
      await sendQueue;
    } catch (_) {}

    // 잔여 프레임 전송
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
        frameStatus = "";
        isCollectingFrames = false;
      });
    }
  }

  void toggleDirection() {
    setState(() {
      isSignToKorean = !isSignToKorean;
      clearResults();
    });

    if (isCameraOn) {
      stopCamera();
    }
  }

  void clearResults() {
    resultKorean = null;
    resultEnglish = null;
    resultJapanese = null;
    resultChinese = null;
    decodedFrames = [];
    inputController.clear();
    frameStatus = '';
    isCollectingFrames = false;
    frameBuffer.clear();
    lastShownword = null;
  }

  Future<void> handleTranslate() async {
    setState(() => isTranslating = true);

    try {
      if (isSignToKorean) {
        setState(() {
          frameStatus = "번역 결과 처리 중...";
        });

        final result = await TranslateApi.translateLatest();
        if (result != null) {
          setState(() {
            resultKorean = result['korean'] is List
                ? (result['korean'] as List).join(' ')
                : result['korean']?.toString();
            resultEnglish = result['english'];
            resultJapanese = result['japanese'];
            resultChinese = result['chinese'];
            frameStatus = "";
          });

          Fluttertoast.showToast(
            msg: '번역이 완료되었습니다',
            backgroundColor: TablerColors.success,
            textColor: Colors.white,
          );
        } else {
          setState(() {
            frameStatus = "번역 실패";
          });
          showTranslationError('번역 결과를 가져올 수 없습니다');
        }
      } else {
        final word = inputController.text.trim();
        if (word.isEmpty) {
          Fluttertoast.showToast(
            msg: '번역할 단어를 입력하세요',
            backgroundColor: TablerColors.warning,
            textColor: Colors.white,
          );
          return;
        }

        final frameList = await TranslateApi.translate_word_to_video(word);
        if (frameList != null && frameList.isNotEmpty) {
          setState(() {
            decodedFrames = frameList.map((b64) => base64Decode(b64)).toList();
            resultKorean = word;
          });

          Fluttertoast.showToast(
            msg: '수어 번역이 완료되었습니다',
            backgroundColor: TablerColors.success,
            textColor: Colors.white,
          );
        } else {
          showTranslationError('수어 애니메이션이 없습니다');
        }
      }
    } catch (e) {
      setState(() {
        frameStatus = "오류 발생";
      });
      showTranslationError('번역 중 오류가 발생했습니다');
    } finally {
      setState(() => isTranslating = false);
    }
  }

  void showTranslationError(String message) {
    Fluttertoast.showToast(
      msg: message,
      backgroundColor: TablerColors.danger,
      textColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TablerColors.background,
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(initialIndex: 3),
            VerticalDivider(width: 1, color: TablerColors.border),
            Expanded(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  children: [
                    buildLanguageSelector(),
                    SizedBox(height: 24),
                    Expanded(child: buildTranslationArea()),
                    SizedBox(height: 24),
                    if (!isSignToKorean) buildTranslateButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildLanguageSelector() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TablerColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: buildLanguageBox(
              isSignToKorean ? '수어' : selectedLang,
              false,
            ),
          ),
          SizedBox(width: 16),
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TablerColors.primary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: Icon(Icons.swap_horiz, color: Colors.white, size: 20),
              onPressed: toggleDirection,
              tooltip: '번역 방향 전환',
              padding: EdgeInsets.zero,
              constraints: BoxConstraints(),
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: buildLanguageBox(isSignToKorean ? selectedLang : '수어', true),
          ),
        ],
      ),
    );
  }

  Widget buildLanguageBox(String language, bool isTarget) {
    if (language == '수어') {
      return Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: TablerColors.primary.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: TablerColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sign_language, color: TablerColors.primary, size: 20),
            SizedBox(width: 8),
            Text(
              '수어',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: TablerColors.primary,
              ),
            ),
          ],
        ),
      );
    }

    bool canChange =
        (isSignToKorean && isTarget) || (!isSignToKorean && !isTarget);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TablerColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedLang,
          isExpanded: true,
          icon: Icon(Icons.arrow_drop_down, color: TablerColors.textSecondary),
          items: langs
              .map(
                (lang) => DropdownMenuItem(
                  value: lang,
                  child: Text(
                    lang,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: TablerColors.textPrimary,
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: canChange
              ? (lang) => setState(() => selectedLang = lang!)
              : null,
        ),
      ),
    );
  }

  Widget buildTranslationArea() {
    return Row(
      children: [
        Expanded(child: buildInputCard()),
        SizedBox(width: 24),
        Expanded(child: buildResultCard()),
      ],
    );
  }

  Widget buildInputCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TablerColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSignToKorean ? Icons.videocam : Icons.text_fields,
                color: TablerColors.textSecondary,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                isSignToKorean ? '수어 동작' : '텍스트 입력',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: TablerColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(child: isSignToKorean ? buildCameraArea() : buildTextArea()),
        ],
      ),
    );
  }

  Widget buildCameraArea() {
    return Column(
      children: [
        Expanded(
          child: AnimatedContainer(
            duration: Duration(milliseconds: 250),
            curve: Curves.easeInOut,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _cameraBorderColor,
                width: _cameraBorderWidth,
              ),
              boxShadow: isCameraOn
                  ? [
                      BoxShadow(
                        color: _cameraBorderColor.withOpacity(0.3),
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
                    ? CameraPreview(cameraController!)
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.videocam_off,
                              size: 48,
                              color: Colors.white54,
                            ),
                            SizedBox(height: 16),
                            Text(
                              '카메라를 켜서\n수어 동작을 실행하십시오.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
        SizedBox(height: 16),
        SizedBox(
          width: double.infinity,
          child: TablerButton(
            text: isCameraOn ? '카메라 끄기' : '카메라 켜기',
            icon: isCameraOn ? Icons.videocam_off : Icons.videocam,
            outline: !isCameraOn,
            onPressed: isCameraOn ? stopCamera : startCamera,
          ),
        ),
      ],
    );
  }

  Widget buildTextArea() {
    return TextField(
      controller: inputController,
      maxLines: null,
      expands: true,
      textAlignVertical: TextAlignVertical.top,
      decoration: InputDecoration(
        hintText: '번역할 텍스트를 입력하세요...',
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: TablerColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: TablerColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: TablerColors.primary, width: 2),
        ),
        contentPadding: EdgeInsets.all(16),
      ),
      style: TextStyle(fontSize: 16),
    );
  }

  Widget buildResultCard() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: TablerColors.background.withOpacity(0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: TablerColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isSignToKorean ? Icons.text_fields : Icons.videocam,
                color: const Color.fromARGB(255, 188, 190, 192),
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                '번역 결과',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: TablerColors.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: isSignToKorean ? buildTextResults() : buildVideoResult(),
          ),
        ],
      ),
    );
  }

  Widget buildTextResults() {
    if (frameStatus.isNotEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.info_outline,
              size: 48,
              color: TablerColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              frameStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: TablerColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (resultKorean == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.translate, size: 48, color: TablerColors.textSecondary),
            SizedBox(height: 16),
            Text(
              '번역 결과가 여기에\n표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: TablerColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isSignToKorean && resultKorean != null) ...[
            Container(
              margin: EdgeInsets.only(bottom: 12),
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: TablerColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: TablerColors.primary.withOpacity(0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    selectedLang,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: TablerColors.primary,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    selectedTranslation() ?? '',
                    style: TextStyle(
                      fontSize: 16,
                      color: TablerColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget buildVideoResult() {
    if (!isSignToKorean && decodedFrames.isNotEmpty) {
      return Column(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: AspectRatio(
                  aspectRatio: 16 / 9,
                  child: AnimationWidget(
                    key: animationKey,
                    frames: decodedFrames,
                    fps: 12.0,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: TablerButton(
              text: '다시보기',
              icon: Icons.replay,
              outline: true,
              onPressed: () => animationKey.currentState?.reset(),
            ),
          ),
        ],
      );
    } else if (!isSignToKorean) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.video_library_outlined,
              size: 48,
              color: TablerColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              '수어 영상이 여기에\n표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: TablerColors.textSecondary),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.translate, size: 48, color: TablerColors.textSecondary),
          SizedBox(height: 16),
          Text(
            '결과가 여기에\n표시됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: TablerColors.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget buildTranslateButton() {
    return Center(
      child: SizedBox(
        width: 200,
        height: 48,
        child: TablerButton(
          text: isTranslating ? '확인 중...' : '결과 확인',
          icon: isTranslating ? null : Icons.translate,
          onPressed: isTranslating ? null : handleTranslate,
        ),
      ),
    );
  }
}
