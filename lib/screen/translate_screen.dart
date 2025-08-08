import 'dart:async';
import 'dart:convert';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sign_web/widget/animation_widget.dart';
import 'package:sign_web/service/translate_api.dart';
import 'package:sign_web/widget/sidebar_widget.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

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

  Future<void>? initVideoPlayer;
  bool isProcessingFrame = false;
  CameraController? cameraController;
  final List<Uint8List> frameBuffer = [];
  final GlobalKey<AnimationWidgetState> animationKey =
      GlobalKey<AnimationWidgetState>();
  List<Uint8List> decodeFrames = [];

  // 프레임 상태 표시용 변수 추가
  String frameStatus = '';
  bool isCollectingFrames = false;
  bool hasCollectedFramesOnce = false;

  // 프레임 수집 관련 변수들
  Timer? frameCollectionTimer;
  static const int frameCollectionCount = 45; // 30에서 45로 변경
  static const int frameCollectionIntervalMs = 100; // 50에서 100으로 늘림
  static const Duration frameCollectionInterval = Duration(
    milliseconds: frameCollectionIntervalMs,
  );

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _stopFrameCollection();
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

  /// 프레임 수집을 시작합니다.
  void _startFrameCollection() {
    frameCollectionTimer?.cancel();
    frameCollectionTimer = Timer.periodic(frameCollectionInterval, (
      timer,
    ) async {
      if (!isCameraOn || cameraController == null) {
        timer.cancel();
        return;
      }

      try {
        final picture = await cameraController!.takePicture();
        final bytes = await picture.readAsBytes();
        frameBuffer.add(bytes);

        if (!hasCollectedFramesOnce) {
          setState(() {
            isCollectingFrames = true;
            frameStatus =
                "프레임 수집 중... (${frameBuffer.length}/$frameCollectionCount)\n지금 움직이세요!";
          });
        }

        // 프레임이 충분히 모이면 전송하고 버퍼만 클리어 (타이머는 계속 실행)
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
      }
    });
  }

  /// 프레임 수집을 중지합니다.
  void _stopFrameCollection() {
    frameCollectionTimer?.cancel();
    frameCollectionTimer = null;
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

      if (kIsWeb) {
        _startFrameCollection();
      } else {
        await cameraController!.startImageStream(onFrameAvailable);
      }

      setState(() {
        isCameraOn = true;
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

    // 프레임 수집 타이머 중지
    _stopFrameCollection();

    try {
      // 스트림 중지 (예외 없이 진행되도록)
      if (cameraController!.value.isStreamingImages) {
        print("이미지 스트림 중지 시도...");
        await cameraController!.stopImageStream();
        print("이미지 스트림 중지 완료");
      }
    } catch (e) {
      print("이미지 스트림 중지 오류: $e");
    }

    if (frameBuffer.isNotEmpty) {
      try {
        print("잔여 프레임 ${frameBuffer.length}개 정리 중...");
        frameBuffer.clear();
      } catch (e) {
        print("잔여 프레임 정리 실패: $e");
      }
    }

    try {
      // 컨트롤러 dispose
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

  void onFrameAvailable(CameraImage image) async {
    if (isProcessingFrame) return;
    isProcessingFrame = true;

    try {
      final jpeg = await convertYUV420toJPEG(image);
      if (jpeg != null) {
        frameBuffer.add(jpeg);

        // 프레임 수집 상태 업데이트
        if (!hasCollectedFramesOnce) {
          setState(() {
            isCollectingFrames = true;
            frameStatus =
                "프레임 수집 중... (${frameBuffer.length}/$frameCollectionCount)\n지금 움직이세요!";
          });
        }

        if (frameBuffer.length > frameCollectionCount) {
          await sendFrames(List.from(frameBuffer));
          frameBuffer.clear();
          if (!hasCollectedFramesOnce) {
            hasCollectedFramesOnce = true;
          }
        }
      } else {
        print("JPEG 변환 실패: convertYUV420toJPEG에서 null 반환");
      }
    } catch (e) {
      print("프레임 처리 오류 (YUV->JPEG): $e");
    } finally {
      isProcessingFrame = false;
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
  }

  Future<Uint8List?> convertYUV420toJPEG(CameraImage image) async {
    try {
      final int width = image.width;
      final int height = image.height;

      final planeY = image.planes[0];
      final planeU = image.planes[1];
      final planeV = image.planes[2];

      final Uint8List bytesY = planeY.bytes;
      final Uint8List bytesU = planeU.bytes;
      final Uint8List bytesV = planeV.bytes;

      final int yStride = planeY.bytesPerRow;
      final int uStride = planeU.bytesPerRow;
      final int pixelStrideU = planeU.bytesPerPixel ?? 1;

      String format = 'UNKNOWN';

      final int yHeight = height;
      final int yWidth = width;

      final int uWidthGuess = uStride ~/ (planeU.bytesPerPixel ?? 1);
      final int uHeightGuess = planeU.bytes.length ~/ uStride;

      if ((uWidthGuess - yWidth).abs() <= 32 &&
          (uHeightGuess - yHeight).abs() <= 2) {
        format = 'YUV444';
      } else if ((uWidthGuess - yWidth ~/ 2).abs() <= 32 &&
          (uHeightGuess - yHeight).abs() <= 2) {
        format = 'YUV422';
      } else if ((uWidthGuess - yWidth ~/ 2).abs() <= 32 &&
          (uHeightGuess - yHeight ~/ 2).abs() <= 2) {
        format = 'YUV420';
      } else {
        print("Unknown YUV format");
        print(
          "→ uStride: $uStride, uHeightGuess: $uHeightGuess, pixelStrideU: $pixelStrideU",
        );
        return null;
      }

      final img.Image output = img.Image(width: width, height: height);

      for (int y = 0; y < height; y++) {
        final int yRow = y * yStride;
        final int uvY = (format == 'YUV420')
            ? y ~/ 2
            : (format == 'YUV422')
            ? y
            : y;

        for (int x = 0; x < width; x++) {
          final int yIndex = yRow + x;

          final int uvX = (format == 'YUV444') ? x : x ~/ 2;
          final int uvIndex = uvY * uStride + uvX * pixelStrideU;

          final int Y = bytesY[yIndex];
          final int U = bytesU[uvIndex] - 128;
          final int V = bytesV[uvIndex] - 128;

          // TTA 기반 변환 공식
          int R = (Y + 0.956 * U + 0.621 * V).round();
          int G = (Y - 0.272 * U - 0.647 * V).round();
          int B = (Y + 1.106 * U + 1.703 * V).round();

          output.setPixelRgb(
            x,
            y,
            R.clamp(0, 255),
            G.clamp(0, 255),
            B.clamp(0, 255),
          );
        }
      }

      final encoded = img.encodeJpg(output, quality: 80);
      return Uint8List.fromList(encoded);
    } catch (e) {
      debugPrint("변환 오류: $e");
      return null;
    }
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
                    buildTranslateButton(),
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
                isSignToKorean ? '수어 입력' : '텍스트 입력',
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
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(8),
            ),
            child: isCameraOn && cameraController?.value.isInitialized == true
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: CameraPreview(cameraController!),
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
                          '카메라를 켜서\n수어를 입력하세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.white70),
                        ),
                      ],
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
                color: TablerColors.textSecondary,
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
            '번역 결과가 여기에\n표시됩니다',
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
          text: isTranslating ? '번역 중...' : '번역하기',
          icon: isTranslating ? null : Icons.translate,
          onPressed: isTranslating ? null : handleTranslate,
        ),
      ),
    );
  }
}
