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
import 'package:sign_web/service/opencv_web.dart';

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

  // 프레임 처리
  final List<Uint8List> frameBuffer = [];
  static const int batchSize = 20;
  static const int maxBuffer = 120;
  bool busy = false;

  bool forcestop = false;

  // 전송 큐
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

  // 누적 인식 결과들
  List<String> recognizedWords = [];

  final GlobalKey<AnimationWidgetState> animationKey =
      GlobalKey<AnimationWidgetState>();
  List<Uint8List> decodedFrames = [];

  // 프레임 캡처 타이머
  Timer? frameTimer;

  // 실시간 번역
  Timer? recognitionPollingTimer;

  // 상태 표시
  String frameStatus = '';
  bool isCollectingFrames = false;

  // 프레임 캡처 상태
  bool isCapturingFrame = false;

  // 카메라 테두리 색상
  Color get cameraBorderColor {
    if (!isCameraOn) return TablerColors.border;
    return TablerColors.success;
  }

  double get cameraBorderWidth => isCameraOn ? 3 : 2;

  @override
  void initState() {
    super.initState();
    OpenCVWeb.setProcessingMode(true);
  }

  @override
  void dispose() {
    forcestop = true;
    stopFrameCapture();
    stopRealtimePolling();
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

  // 서버 전송 함수
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

      // 필터링
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
        // 새로운 단어를 누적 리스트에 추가
        if (!recognizedWords.contains(korean)) {
          recognizedWords.add(korean);
        }
        resultKorean = recognizedWords.join(' ');
        resultEnglish = (res['english'] as String?) ?? '';
        resultJapanese = (res['japanese'] as String?) ?? '';
        resultChinese = (res['chinese'] as String?) ?? '';
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

        Uint8List processedBytes = bytes;

        // 프레임 버퍼 관리
        if (frameBuffer.length >= maxBuffer) {
          final int drop = frameBuffer.length - maxBuffer + 1;
          frameBuffer.removeRange(0, drop);
        }
        frameBuffer.add(processedBytes);

        if (frameBuffer.length >= batchSize) {
          final chunk = List<Uint8List>.from(frameBuffer.take(batchSize));
          frameBuffer.removeRange(0, batchSize);
          enqueueSend(chunk);
        } else {
          // 프레임 수집 중 상태
          if (mounted && frameBuffer.length % 15 == 0) {
            final processingStatus =
                OpenCVWeb.enableProcessing && OpenCVWeb.isAvailable ? "" : "";
            setState(() {
              frameStatus =
                  "$processingStatus 프레임 수집 중... (${frameBuffer.length}/$batchSize)";
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

  void stopRealtimePolling() {
    recognitionPollingTimer?.cancel();
    recognitionPollingTimer = null;
  }

  Future<void> startCamera() async {
    try {
      setState(() {
        lastShownword = null;
        recognizedWords.clear();
        frameStatus = "카메라 초기화 중...";
      });

      // OpenCV 상태 확인
      if (!OpenCVWeb.isAvailable && OpenCVWeb.enableProcessing) {
        setState(() {
          frameStatus = "컬러 최적화 엔진 로딩 중...";
        });

        final success = await OpenCVWeb.forceReinitialize();
        if (!success) {
          Fluttertoast.showToast(
            msg: '컬러 최적화 로드 실패 - 기본 모드로 실행됩니다',
            backgroundColor: TablerColors.warning,
            textColor: Colors.white,
            toastLength: Toast.LENGTH_LONG,
          );
        }
      }

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
        frameStatus = OpenCVWeb.isAvailable && OpenCVWeb.enableProcessing
            ? " 컬러 최적화 준비완료 - 수어 동작을 시작하세요"
            : " 기본 모드 준비완료 - 수어 동작을 시작하세요";
      });

      final message = OpenCVWeb.isAvailable && OpenCVWeb.enableProcessing
          ? ' 카메라 시작 (컬러 최적화 모드)'
          : ' 카메라 시작 (기본 모드)';

      Fluttertoast.showToast(
        msg: message,
        backgroundColor: TablerColors.success,
        textColor: Colors.white,
      );
    } catch (e) {
      debugPrint("카메라 초기화 실패: $e");
      setState(() {
        frameStatus = "카메라 오류: $e";
      });
      Fluttertoast.showToast(
        msg: '카메라를 켤 수 없습니다: $e',
        backgroundColor: TablerColors.danger,
        textColor: Colors.white,
      );
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
    stopRealtimePolling();

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

    // 카메라 종료 시 최종 번역 결과
    if (isSignToKorean) {
      setState(() {
        frameStatus = "최종 번역 결과 확인 중...";
      });

      try {
        final result = await TranslateApi.translateLatest();
        if (result != null && mounted) {
          final korean = result['korean'] is List
              ? (result['korean'] as List).join(' ')
              : result['korean']?.toString() ?? '';

          if (korean.isNotEmpty &&
              !korean.contains('인식된 단어가 없습니다') &&
              !korean.contains('인식 실패') &&
              !korean.contains('없음') &&
              !korean.toLowerCase().contains('no word') &&
              !korean.toLowerCase().contains('unknown')) {
            setState(() {
              if (korean != lastShownword) {
                lastShownword = korean;
                resultKorean = korean;
                resultEnglish = result['english'] ?? '';
                resultJapanese = result['japanese'] ?? '';
                resultChinese = result['chinese'] ?? '';
              }
              frameStatus = " 최종 인식 결과: $korean";
            });

            Fluttertoast.showToast(
              msg: '최종 인식: $korean',
              backgroundColor: TablerColors.success,
              textColor: Colors.white,
            );
          } else {
            setState(() {
              frameStatus = "수어 동작을 다시 시도해주세요";
            });
          }
        }
      } catch (e) {
        debugPrint('최종 번역 확인 실패: $e');
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
        if (frameStatus.contains('최종 인식 결과') || frameStatus.contains('다시 시도')) {
        } else {
          frameStatus = "";
        }
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
    recognizedWords.clear();
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
          final korean = result['korean'] is List
              ? (result['korean'] as List).join(' ')
              : result['korean']?.toString() ?? '';

          if (korean.isNotEmpty &&
              !korean.contains('인식된 단어가 없습니다') &&
              !korean.contains('인식 실패') &&
              !korean.contains('없음') &&
              !korean.toLowerCase().contains('no word') &&
              !korean.toLowerCase().contains('unknown')) {
            setState(() {
              if (recognizedWords.isNotEmpty) {
                resultKorean = recognizedWords.join(' ');
              } else {
                resultKorean = korean;
              }
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
            if (recognizedWords.isNotEmpty) {
              setState(() {
                resultKorean = recognizedWords.join(' ');
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
          }
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
        frameStatus = "오류 발생: $e";
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
                          // 카메라 프리뷰
                          Positioned.fill(
                            child: CameraPreview(cameraController!),
                          ),
                        ],
                      )
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
    if (frameStatus.isNotEmpty &&
        (frameStatus.contains('오류') ||
            frameStatus.contains('로딩') ||
            frameStatus.contains('초기화') ||
            frameStatus.contains('재시도'))) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              frameStatus.contains('오류')
                  ? Icons.error_outline
                  : Icons.info_outline,
              size: 48,
              color: frameStatus.contains('오류')
                  ? TablerColors.danger
                  : TablerColors.textSecondary,
            ),
            SizedBox(height: 16),
            Text(
              frameStatus,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: frameStatus.contains('오류')
                    ? TablerColors.danger
                    : TablerColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    // 번역 결과가 없을 때
    if (resultKorean == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.translate, size: 48, color: TablerColors.textSecondary),
            SizedBox(height: 16),
            Text(
              isCameraOn ? '수어 동작을 시작하면\n번역 결과가 표시됩니다' : '번역 결과가 여기에\n표시됩니다',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: TablerColors.textSecondary),
            ),
            if (isCameraOn) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: TablerColors.info.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: TablerColors.info.withOpacity(0.3)),
                ),
                child: Text(
                  '실시간 인식 중',
                  style: TextStyle(
                    fontSize: 12,
                    color: TablerColors.info,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // 번역 결과 표시
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            margin: EdgeInsets.only(bottom: 12),
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: TablerColors.success.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: TablerColors.success.withOpacity(0.3)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      '인식 결과',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: TablerColors.success,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8),
                Text(
                  resultKorean ?? '',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: TablerColors.textPrimary,
                  ),
                ),

                // 선택된 언어의 번역 결과
                if (selectedLang != '한국어' &&
                    selectedTranslation() != null &&
                    selectedTranslation()!.isNotEmpty) ...[
                  SizedBox(height: 12),
                  Divider(color: TablerColors.border),
                  SizedBox(height: 8),
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
                    selectedTranslation()!,
                    style: TextStyle(
                      fontSize: 16,
                      color: TablerColors.textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),

          // 상태 메시지
          if (frameStatus.contains('인식 완료') ||
              frameStatus.contains('번역 완료')) ...[
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: TablerColors.success.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  Icon(Icons.check, color: TablerColors.success, size: 16),
                  SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      frameStatus,
                      style: TextStyle(
                        fontSize: 12,
                        color: TablerColors.success,
                        fontWeight: FontWeight.w500,
                      ),
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
