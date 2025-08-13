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
  bool isSignToKorean = true; // true: 수어 -> 한글 | false 한글 -> 수어
  bool isCameraOn = false;
  bool isTranslating = false;
  XFile? capturedVideo;
  bool useRealtimeMode = true;

  final TextEditingController inputController = TextEditingController();

  // 콤보박스
  final List<String> langs = ['한국어', 'English', '日本語', '中文'];
  String selectedLang = '한국어';

  String? resultKorean;
  String? resultEnglish;
  String? resultJapanese;
  String? resultChinese;

  CameraController? cameraController;
  final List<Uint8List> frameBuffer = [];
  final GlobalKey<AnimationWidgetState> animationKey =
      GlobalKey<AnimationWidgetState>();
  List<Uint8List> decodeFrames = [];

  // 실시간 인식 결과 누적 및 폴링

  Timer? _recognitionPollingTimer;
  static const int _autoFinalizeWordCount = 3;
  bool _autoFinalized = false;
  final bool _continuousMode = true; // 연속 모드 활성화

  // 프레임 상태 표시용 변수 추가
  String frameStatus = '';
  bool isCollectingFrames = false;
  bool hasCollectedFramesOnce = false;

  // 실시간 번역 관련 변수들
  Timer? realtimeTranslationTimer;
  bool isRealtimeTranslating = false;
  List<String> translationHistory = []; // 번역 히스토리
  DateTime? lastTranslationTime;

  // 존재(움직임) 자동 감지 상태
  bool isSubjectPresent = false;
  int? lastFrameSample;
  int presenceScore = 0;
  static const int presenceScoreEnter = 60; // 이 값 이상이면 존재로 판정
  static const int presenceScoreExit = 30; // 이 값 이하이면 부재로 판정
  static const int presenceScoreInc = 12; // 모션 있을 때 점수 증가량
  static const int presenceScoreDecay = 6; // 모션 없을 때 점수 감소량

  // 프레임 수집 관련 변수들
  Timer? frameCollectionTimer;
  static const int frameCollectionCount = 45;
  static const int frameCollectionIntervalMs = 100;
  static const Duration frameCollectionInterval = Duration(
    milliseconds: frameCollectionIntervalMs,
  );

  // 웹 캡처 중복 호출 방지
  bool _isCapturingWeb = false;

  // 상태 텍스트 기반 보조 플래그
  bool get _isErrorState =>
      frameStatus.contains('오류') || frameStatus.contains('실패');
  bool get _isAnalyzingState => frameStatus.contains('분석');
  bool get _isRecognizingNow =>
      isCameraOn &&
      (_isAnalyzingState || isCollectingFrames || frameBuffer.isNotEmpty);

  Color get _cameraBorderColor {
    if (!isCameraOn) return TablerColors.border;
    if (_isErrorState) return TablerColors.danger;
    return isSubjectPresent ? TablerColors.success : TablerColors.danger;
  }

  double get _cameraBorderWidth => _isRecognizingNow ? 3 : 2;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    stopFrameCollection();
    _stopRealtimePolling();
    stopCamera();
    inputController.dispose();
    super.dispose();
  }

  Future<void> sendFrames(List<Uint8List> frames) async {
    if (!hasCollectedFramesOnce) {
      setState(() {
        frameStatus = "프레임 ${frames.length}개 서버로 전송 중...";
        isCollectingFrames = false;
      });
    }

    print("프레임 ${frames.length}개 서버로 전송 시도...");
    final List<String> base64Frames = frames
        .map((frame) => base64Encode(frame))
        .toList();

    try {
      final result = await TranslateApi.sendFrames(base64Frames);

      if (result != null) {
        print("서버 응답 성공: $result");
        if (!hasCollectedFramesOnce) {
          setState(() {
            frameStatus = "분석 중... 잠시만 기다려주세요";
          });
        }
      } else {
        print("서버 응답 실패: result is null");
        setState(() {
          frameStatus = "전송 실패";
        });
      }
    } catch (e) {
      print("프레임 전송 중 오류 발생: $e");
      setState(() {
        frameStatus = "전송 오류 발생";
      });
    }
  }

  void startFrameCollection() {
    frameCollectionTimer?.cancel();
    frameCollectionTimer = Timer.periodic(frameCollectionInterval, (
      timer,
    ) async {
      if (!isCameraOn || cameraController == null) {
        timer.cancel();
        return;
      }

      try {
        if (_isCapturingWeb) return; // 중복 캡처 방지
        _isCapturingWeb = true;

        final picture = await cameraController!.takePicture();
        final bytes = await picture.readAsBytes();
        frameBuffer.add(bytes);

        // 존재(움직임) 감지 업데이트
        _updatePresence(bytes);

        if (!hasCollectedFramesOnce) {
          setState(() {
            isCollectingFrames = true;
            frameStatus =
                "프레임 수집 중... (${frameBuffer.length}/$frameCollectionCount)\n지금 움직이세요!";
          });
        }

        // 프레임이 충분히 모이면 전송하고 버퍼만 클리어
        if (frameBuffer.length >= frameCollectionCount) {
          final framesToSend = List<Uint8List>.from(frameBuffer);
          frameBuffer.clear();

          await sendFrames(framesToSend);

          if (!hasCollectedFramesOnce) {
            hasCollectedFramesOnce = true;
            setState(() {
              frameStatus = "";
              isCollectingFrames = false;
            });
          }
        }
      } catch (e) {
        print("웹 캡처 오류: $e");
      } finally {
        _isCapturingWeb = false;
      }
    });
  }

  void stopFrameCollection() {
    frameCollectionTimer?.cancel();
    frameCollectionTimer = null;
  }

  // 프레임 바이트를 샘플링해 간단한 변화량 계산
  int _computeSample(Uint8List bytes) {
    int sum = 0;
    final int step = bytes.length > 200000 ? 400 : 200; // 대략 샘플 간격
    for (int i = 0; i < bytes.length; i += step) {
      sum += bytes[i];
    }
    return sum;
  }

  void _updatePresence(Uint8List bytes) {
    final int sample = _computeSample(bytes);

    if (lastFrameSample != null) {
      final int diff = (sample - lastFrameSample!).abs();
      // 프레임당 샘플 개수에 비례한 간단 임계값
      final int step = bytes.length > 200000 ? 400 : 200;
      final int samples = (bytes.length + step - 1) ~/ step;
      final int dynamicThreshold = samples * 8; // 기본 민감도

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
      );

      await cameraController!.initialize();

      startFrameCollection();
      if (isSignToKorean) {
        _startRealtimePolling();
      }

      setState(() {
        isCameraOn = true;
        _autoFinalized = false;
        if (!hasCollectedFramesOnce) {
          frameStatus = "카메라 준비 완료!\n수어 동작을 시작하세요";
        } else {
          frameStatus = "";
        }
      });

      Fluttertoast.showToast(
        msg: '카메라가 켜졌습니다',
        backgroundColor: TablerColors.success,
        textColor: Colors.white,
      );
    } catch (e) {
      print("카메라 초기화 실패: $e");
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

    print("카메라 중지 요청 수신");

    stopFrameCollection();
    _stopRealtimePolling();

    if (frameBuffer.isNotEmpty) {
      try {
        print("잔여 프레임 ${frameBuffer.length}개 정리 중...");
        frameBuffer.clear();
      } catch (e) {
        print("잔여 프레임 정리 실패: $e");
      }
    }

    try {
      await cameraController!.dispose();
      print("컨트롤러 dispose 완료");
    } catch (e) {
      print("컨트롤러 dispose 오류: $e");
    } finally {
      cameraController = null;
    }

    if (mounted) {
      setState(() {
        isCameraOn = false;
        frameStatus = "";
        hasCollectedFramesOnce = false;
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
    decodeFrames = [];
    inputController.clear();
    frameStatus = '';
    isCollectingFrames = false;
    hasCollectedFramesOnce = false;
    frameBuffer.clear();

    _autoFinalized = false;
  }

  // --- 실시간 인식 폴링 로직 ---
  void _startRealtimePolling() {
    _recognitionPollingTimer?.cancel();
    _recognitionPollingTimer = Timer.periodic(const Duration(seconds: 5), (
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

        setState(() {
          resultKorean = korean;
        });

        // 자동 완료 조건 체크 (단어 개수 기준) - 연속 모드에서는 비활성화
        if (!_continuousMode) {
          final wordCount = korean
              .split(RegExp(r"\s+"))
              .where((e) => e.trim().isNotEmpty)
              .length;
          if (!_autoFinalized && wordCount >= _autoFinalizeWordCount) {
            _autoFinalized = true;
            // 기존 버튼 로직 재사용
            await handleTranslate();
          }
        }
      } catch (_) {}
    });
  }

  void _stopRealtimePolling() {
    _recognitionPollingTimer?.cancel();
    _recognitionPollingTimer = null;
  }

  Future<void> handleTranslate() async {
    setState(() => isTranslating = true);

    try {
      if (isSignToKorean) {
        // 수어 -> 텍스트 번역
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
            isCollectingFrames = false;
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
        // 텍스트 -> 수어 번역
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
            decodeFrames = frameList.map((b64) => base64Decode(b64)).toList();
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

  Future<void> translateSignToText() async {
    try {
      final result = await TranslateApi.translateLatest();
      if (result != null) {
        setState(() {
          resultKorean = result['korean'] ?? '';
          resultEnglish = result['english'] ?? '';
          resultJapanese = result['japanese'] ?? '';
          resultChinese = result['chinese'] ?? '';
        });

        Fluttertoast.showToast(
          msg: '번역이 완료되었습니다',
          backgroundColor: TablerColors.success,
          textColor: Colors.white,
        );
      } else {
        showTranslationError('번역 결과를 가져올 수 없습니다');
      }
    } catch (e) {
      showTranslationError('번역 중 오류가 발생했습니다');
    }
  }

  Future<void> translateTextToSign() async {
    final word = inputController.text.trim();
    if (word.isEmpty) {
      Fluttertoast.showToast(
        msg: '번역할 단어를 입력하세요',
        backgroundColor: TablerColors.warning,
        textColor: Colors.white,
      );
      return;
    }

    try {
      final frameList = await TranslateApi.translate_word_to_video(word);
      if (frameList != null && frameList.isNotEmpty) {
        setState(() {
          decodeFrames = frameList.map((b64) => base64Decode(b64)).toList();
          resultKorean = word;
        });

        Fluttertoast.showToast(
          msg: '수어 번역이 완료되었습니다',
          backgroundColor: TablerColors.success,
          textColor: Colors.white,
        );
      } else {
        showTranslationError('해당 단어의 수어 영상을 찾을 수 없습니다');
      }
    } catch (e) {
      showTranslationError('수어 번역 중 오류가 발생했습니다');
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

    // 언어 선택 드롭다운
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
              boxShadow: _isRecognizingNow
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
    // 프레임 수집/전송 상태가 있으면 표시
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

    // 번역 결과가 있으면 표시
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
          // 수어 -> 텍스트 번역 결과
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
                  if (selectedLang == '한국어')
                    Text(
                      '$resultKorean',
                      style: TextStyle(
                        fontSize: 16,
                        color: TablerColors.textPrimary,
                      ),
                    ),
                  if (selectedLang == 'English')
                    Text(
                      '$resultEnglish',
                      style: TextStyle(
                        fontSize: 16,
                        color: TablerColors.textPrimary,
                      ),
                    ),
                  if (selectedLang == '日本語')
                    Text(
                      '$resultJapanese',
                      style: TextStyle(
                        fontSize: 16,
                        color: TablerColors.textPrimary,
                      ),
                    ),
                  if (selectedLang == '中文')
                    Text(
                      '$resultChinese',
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
    if (!isSignToKorean && decodeFrames.isNotEmpty) {
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
                    frames: decodeFrames,
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
