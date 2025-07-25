import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:sign_web/widget/animation_widget.dart';
import 'package:sign_web/service/translate_api.dart';
import 'package:sign_web/widget/sidebar_widget.dart';
import 'package:image/image.dart' as img;

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});
  @override
  State<TranslateScreen> createState() => TranslateScreenWebState();
}

class TranslateScreenWebState extends State<TranslateScreen> {
  bool isSignToKorean = true; // true: 수어 -> 한글 | false 한글 -> 수어
  bool isCameraOn = false;
  XFile? capturedVideo;

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

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    stopCamera();
    super.dispose();
  }

  Future<void> sendFrames(List<Uint8List> frames) async {
    print("프레임 ${frames.length}개 서버로 전송 시도...");
    final List<String> base64Frames = frames
        .map((frame) => base64Encode(frame))
        .toList();

    try {
      final result = await TranslateApi.sendFrames(base64Frames);
      if (result != null) {
        print("서버 응답 성공: $result");
      } else {
        print("서버 응답 실패: result is null");
      }
    } catch (e) {
      print("프레임 전송 중 오류 발생: $e");
    }
  }

  Future<void> stopCamera() async {
    if (cameraController == null) return;

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

    try {
      // 영상 녹화 중이라면 정지
      if (cameraController!.value.isRecordingVideo) {
        print("영상 녹화 중지 시도...");
        final file = await cameraController!.stopVideoRecording();
        capturedVideo = file;
        print("영상 녹화 완료: ${file.path}");
      }
    } catch (e) {
      print("녹화 중지 오류: $e");
    }

    try {
      // 컨트롤러 dispose
      print("컨트롤러 dispose 시작...");
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

        if (frameBuffer.length > 30) {
          await sendFrames(List.from(frameBuffer));
          frameBuffer.clear();
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
      isCameraOn = false;
    });
  }

  void toggleCamera() {
    setState(() {
      isCameraOn = !isCameraOn;
    });
  }

  Future<Uint8List?> convertYUV420toJPEG(CameraImage image) async {
    try {
      final width = image.width;
      final height = image.height;

      final img.Image imgData = img.Image(width: width, height: height);

      final planeY = image.planes[0];
      final planeU = image.planes[1];
      final planeV = image.planes[2];

      final bytesY = planeY.bytes;
      final bytesU = planeU.bytes;
      final bytesV = planeV.bytes;

      final int rowStrideY = planeY.bytesPerRow;
      final int rowStrideU = planeU.bytesPerRow;
      final int pixelStrideU = planeU.bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = (y ~/ 2) * rowStrideU + (x ~/ 2) * pixelStrideU;
          final int yIndex = y * rowStrideY + x;

          final yp = bytesY[yIndex];
          final up = bytesU[uvIndex];
          final vp = bytesV[uvIndex];

          int r = (yp + 1.402 * (vp - 128)).round();
          int g = (yp - 0.344136 * (up - 128) - 0.714136 * (vp - 128)).round();
          int b = (yp + 1.772 * (up - 128)).round();

          imgData.setPixelRgb(
            x,
            y,
            r.clamp(0, 255),
            g.clamp(0, 255),
            b.clamp(0, 255),
          );
        }
      }

      final encodedBytes = img.encodeJpg(imgData, quality: 80);
      return Uint8List.fromList(encodedBytes);
    } catch (e) {
      print("convertYUV420toJPEG 오류: $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final inputLabel = isSignToKorean ? '수어 입력' : '$selectedLang 입력';

    final screenWidth = MediaQuery.of(context).size.width;
    double contentWidth = screenWidth * 0.8;
    if (contentWidth > 1100) contentWidth = 1100;
    if (contentWidth < 340) contentWidth = 340;

    // 카메라 상태에 따른 flex 비율 설정
    final inputFlex = (isSignToKorean && isCameraOn) ? 3 : 1;
    final resultFlex = (isSignToKorean && isCameraOn) ? 1 : 2;

    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(initialIndex: 3),
            VerticalDivider(width: 1),
            Expanded(
              child: Center(
                child: SizedBox(
                  width: contentWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 언어선택/스왑 Row
                      Padding(
                        padding: EdgeInsets.only(top: 24, bottom: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerRight,
                                child: isSignToKorean
                                    ? Text('수어', style: TextStyle(fontSize: 26))
                                    : DropdownButton<String>(
                                        value: selectedLang,
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                          size: 22,
                                        ),
                                        underline: SizedBox(),
                                        items: langs
                                            .map(
                                              (lang) => DropdownMenuItem(
                                                value: lang,
                                                child: Text(
                                                  lang,
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (lang) => setState(
                                          () => selectedLang = lang!,
                                        ),
                                      ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.sync_alt, size: 26),
                              onPressed: toggleDirection,
                            ),
                            Expanded(
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: isSignToKorean
                                    ? DropdownButton<String>(
                                        value: selectedLang,
                                        icon: Icon(
                                          Icons.arrow_drop_down,
                                          size: 22,
                                        ),
                                        underline: SizedBox(),
                                        items: langs
                                            .map(
                                              (lang) => DropdownMenuItem(
                                                value: lang,
                                                child: Text(
                                                  lang,
                                                  style: TextStyle(
                                                    fontSize: 20,
                                                  ),
                                                ),
                                              ),
                                            )
                                            .toList(),
                                        onChanged: (lang) => setState(
                                          () => selectedLang = lang!,
                                        ),
                                      )
                                    : Text(
                                        '수어',
                                        style: TextStyle(fontSize: 26),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 16),
                      // 입력/결과 영역을 Row로 배치 (좌: 입력, 우: 결과)
                      Expanded(
                        flex: 1,
                        child: Column(
                          children: [
                            // 입력 영역 - flex 비율 동적 적용
                            Expanded(
                              flex: inputFlex,
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    // 텍스트 입력 영역
                                    if (!isSignToKorean || !isCameraOn)
                                      Expanded(
                                        child: Container(
                                          padding: EdgeInsets.only(right: 40),
                                          alignment: Alignment.topLeft,
                                          child: TextField(
                                            controller: inputController,
                                            decoration: InputDecoration(
                                              border: InputBorder.none,
                                              hintText: inputLabel,
                                            ),
                                            style: TextStyle(fontSize: 15),
                                            maxLines: null,
                                            expands: true,
                                          ),
                                        ),
                                      ),
                                    // 카메라 프리뷰
                                    if (isSignToKorean &&
                                        isCameraOn &&
                                        cameraController != null &&
                                        cameraController!.value.isInitialized)
                                      Expanded(
                                        child: Container(
                                          constraints: BoxConstraints(
                                            maxWidth: contentWidth * 0.8,
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            child: CameraPreview(
                                              cameraController!,
                                            ),
                                          ),
                                        ),
                                      ),
                                    // 카메라 버튼
                                    if (isSignToKorean)
                                      Padding(
                                        padding: EdgeInsets.only(top: 12),
                                        child: IconButton(
                                          icon: Icon(
                                            isCameraOn
                                                ? Icons.camera_alt
                                                : Icons.no_photography,
                                            size: 32,
                                            color: isCameraOn
                                                ? Colors.red
                                                : Colors.grey,
                                          ),
                                          onPressed: toggleCamera,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            // 결과 영역 - flex 비율 동적 적용
                            Expanded(
                              flex: resultFlex,
                              child: AnimatedContainer(
                                duration: Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Expanded(
                                      child: SingleChildScrollView(
                                        child: Container(
                                          alignment: Alignment.topLeft,
                                          child: resultKorean == null
                                              ? Text(
                                                  '번역 결과',
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                  ),
                                                )
                                              : Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    if (isSignToKorean &&
                                                        resultKorean !=
                                                            null) ...[
                                                      Text(
                                                        '한글: $resultKorean',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      Text(
                                                        '영어: $resultEnglish',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      Text(
                                                        '일본어: $resultJapanese',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      Text(
                                                        '중국어: $resultChinese',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                      const SizedBox(
                                                        height: 12,
                                                      ),
                                                    ],
                                                    if (!isSignToKorean &&
                                                        decodeFrames.isNotEmpty)
                                                      Column(
                                                        children: [
                                                          AspectRatio(
                                                            aspectRatio: 16 / 9,
                                                            child: AnimationWidget(
                                                              key: animationKey,
                                                              frames:
                                                                  decodeFrames,
                                                            ),
                                                          ),
                                                          SizedBox(height: 8),
                                                          ElevatedButton.icon(
                                                            onPressed: () =>
                                                                animationKey
                                                                    .currentState
                                                                    ?.reset(),
                                                            icon: Icon(
                                                              Icons.replay,
                                                            ),
                                                            label: Text('다시보기'),
                                                          ),
                                                        ],
                                                      )
                                                    else if (!isSignToKorean)
                                                      const SizedBox(
                                                        height: 180,
                                                        child: Center(
                                                          child: Text(
                                                            "수어 영상 없음",
                                                          ),
                                                        ),
                                                      ),
                                                    if (resultKorean == null)
                                                      Text(
                                                        '번역결과',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 28),
                      SizedBox(
                        width: 260,
                        height: 42,
                        child: ElevatedButton(
                          onPressed: () async {
                            if (isSignToKorean) {
                              final result =
                                  await TranslateApi.translateLatest();
                              if (result != null) {
                                setState(() {
                                  resultKorean = result['korean'];
                                  resultEnglish = result['english'];
                                  resultJapanese = result['japanese'];
                                  resultChinese = result['chinese'];
                                });
                              } else {
                                Fluttertoast.showToast(
                                  msg: '번역 결과를 가져올 수 없습니다.',
                                );
                              }
                            } else {
                              // 한국어 → 수어
                              final word = inputController.text.trim();
                              if (word.isEmpty) {
                                Fluttertoast.showToast(msg: '번역할 단어를 입력하세요.');
                                return;
                              }
                              final frameList =
                                  await TranslateApi.translate_word_to_video(
                                    word,
                                  );
                              if (frameList != null && frameList.isNotEmpty) {
                                setState(() {
                                  decodeFrames = frameList
                                      .map((b64) => base64Decode(b64))
                                      .toList();
                                  resultKorean = word;
                                });
                              } else {
                                Fluttertoast.showToast(msg: '수어 애니메이션이 없습니다.');
                              }
                            }
                          },
                          child: Text('번역하기', style: TextStyle(fontSize: 16)),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
