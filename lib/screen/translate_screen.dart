import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';
// import 'package:sign_language/widget/camera_widget.dart';
import 'package:video_player/video_player.dart';
import 'package:image/image.dart' as img;
import 'package:web/service/translate_api.dart';
import 'package:web/widget/sidebar_widget.dart';

class TranslateScreen extends StatefulWidget {
  const TranslateScreen({super.key});
  @override
  State<TranslateScreen> createState() => TranslateScreenWebState();
}

class TranslateScreenWebState extends State<TranslateScreen> {
  bool isSignToKorean = true; // true: 수어 -> 한글 | false 한글 -> 수어
  bool isCameraOn = false;
  // int countdown = 0;
  XFile? capturedVideo;

  CameraController? cameraController;

  final TextEditingController inputController = TextEditingController();

  // 콤보박스
  final List<String> langs = ['한국어', 'English', '日本語', '中文'];
  String selectedLang = '한국어';

  String? resultKorean;
  String? resultEnglish;
  String? resultJapanese;
  String? resultChinese;

  VideoPlayerController? controller;
  Future<void>? initVideoPlayer;

  List<Uint8List> frameBuffer = [];
  bool isProcessingFrame = false;

  Timer? frameSendTimer;
  final int framesPerSend = 10;
  final Duration sendInterval = Duration(milliseconds: 500);

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    await [Permission.camera].request();
  }

  Future<void> sendFrames(List<Uint8List> frames) async {
    print("--- 프레임 ${frames.length}개 서버로 전송 시도...");
    final List<String> base64Frames = frames
        .map((frame) => base64Encode(frame))
        .toList();

    try {
      final result = await TranslateApi.sendFrames(base64Frames);
      if (result != null) {
        print("--- 서버 응답 성공: $result");
      } else {
        print("--- 서버 응답 실패: result is null");
      }
    } catch (e) {
      print("--- 프레임 전송 중 오류 발생: $e");
    }
  }

  void onFrameAvailable(CameraImage image) async {
    if (isProcessingFrame) {
      return;
    }
    isProcessingFrame = true;

    try {
      final converted = await convertYUV420toJPEG(image);
      if (converted != null) {
        frameBuffer.add(converted);
      } else {
        print("-- JPEG 변환 실패: convertYUV420toJPEG에서 null 반환");
      }
    } catch (e) {
      print("--- 프레임 처리 오류 (YUV->JPEG): $e");
    } finally {
      isProcessingFrame = false;
    }
  }

  void startFrameSendTimer() {
    frameSendTimer?.cancel();
    frameSendTimer = Timer.periodic(sendInterval, (timer) async {
      if (frameBuffer.isNotEmpty) {
        final framesToSend = List<Uint8List>.from(frameBuffer);
        frameBuffer.clear();
        await sendFrames(framesToSend);
      }
    });
  }

  void stopFrameSendTimer() {
    frameSendTimer?.cancel();
    frameSendTimer = null;
  }

  void toggleDirection() {
    setState(() {
      isSignToKorean = !isSignToKorean;
      stopCamera();
    });
  }

  Future<void> toggleCamera() async {
    if (isCameraOn) {
      await stopCamera();
    } else {
      await startCamera();
    }
  }

  Future<void> startCamera() async {
    try {
      final cameras = await availableCameras();
      final cameraController = CameraController(
        cameras.first,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await cameraController.initialize();
      setState(() => isCameraOn = true);
      print("--- 카메라 스트림 시작됨.");
    } catch (e) {
      print("--- 카메라 시작 실패: $e");
      Fluttertoast.showToast(msg: "카메라 시작 실패: $e");
    }
  }

  Future<void> stopCamera() async {
    if (cameraController == null) return;

    stopFrameSendTimer();
    frameBuffer.clear();

    try {
      if (cameraController!.value.isStreamingImages) {
        await cameraController!.stopImageStream();
        print("--- 카메라 이미지 스트림 중지됨.");
      }
      if (cameraController!.value.isRecordingVideo) {
        final file = await cameraController!.stopVideoRecording();
        capturedVideo = file;
        final size = await File(file.path).length();
        print("--- 영상 저장됨: ${file.path}, 크기: $size bytes");
      }
    } catch (e) {
      print("--- 녹화/스트림 종료 실패: $e");
      Fluttertoast.showToast(msg: "녹화/스트림 종료 실패: $e");
    }

    try {
      await cameraController!.dispose();
      print("--- 카메라 컨트롤러 dispose 됨.");
    } catch (e) {
      print("--- 카메라 dispose 중 오류: $e");
    } finally {
      cameraController = null;
    }

    if (mounted) {
      setState(() {
        isCameraOn = false;
      });
    }
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
      print("--- convertYUV420toJPEG 오류: $e");
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
                            // 입력 영역 (세로 전체 채우기)
                            Expanded(
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Stack(
                                  children: [
                                    if (isSignToKorean &&
                                        isCameraOn &&
                                        cameraController != null &&
                                        cameraController!.value.isInitialized)
                                      AspectRatio(
                                        aspectRatio:
                                            cameraController!.value.aspectRatio,
                                        child: CameraPreview(cameraController!),
                                      ),
                                    Container(
                                      color: isSignToKorean && isCameraOn
                                          ? Colors.black.withOpacity(0.5)
                                          : Colors.transparent,
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
                                    if (isSignToKorean)
                                      Positioned(
                                        right: 10,
                                        child: IconButton(
                                          icon: Icon(
                                            isCameraOn
                                                ? Icons.camera_alt
                                                : Icons.no_photography,
                                            size: 24,
                                          ),
                                          onPressed: toggleCamera,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                            SizedBox(height: 10),
                            // 결과 영역
                            Expanded(
                              flex: 2,
                              child: Container(
                                padding: EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.black),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.max,
                                  children: [
                                    Expanded(
                                      child: Container(
                                        alignment: Alignment.topLeft,
                                        child: resultKorean == null
                                            ? Text(
                                                '번역 결과',
                                                style: TextStyle(fontSize: 15),
                                              )
                                            : Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  if (isSignToKorean &&
                                                      resultKorean != null) ...[
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
                                                    const SizedBox(height: 12),
                                                  ],
                                                  if (!isSignToKorean &&
                                                      initVideoPlayer != null)
                                                    FutureBuilder(
                                                      key: ValueKey(controller),
                                                      future: initVideoPlayer,
                                                      builder: (context, snapshot) {
                                                        if (snapshot.connectionState ==
                                                                ConnectionState
                                                                    .done &&
                                                            controller !=
                                                                null &&
                                                            controller!
                                                                .value
                                                                .isInitialized) {
                                                          return Column(
                                                            children: [
                                                              AspectRatio(
                                                                aspectRatio:
                                                                    controller!
                                                                        .value
                                                                        .aspectRatio,
                                                                child:
                                                                    VideoPlayer(
                                                                      controller!,
                                                                    ),
                                                              ),
                                                              Row(
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  IconButton(
                                                                    icon: Icon(
                                                                      controller!
                                                                              .value
                                                                              .isPlaying
                                                                          ? Icons.pause
                                                                          : Icons.play_arrow,
                                                                    ),
                                                                    onPressed: () {
                                                                      setState(() {
                                                                        controller!.value.isPlaying
                                                                            ? controller!.pause()
                                                                            : controller!.play();
                                                                      });
                                                                    },
                                                                  ),
                                                                  IconButton(
                                                                    icon: const Icon(
                                                                      Icons
                                                                          .stop,
                                                                    ),
                                                                    onPressed: () {
                                                                      controller!
                                                                          .pause();
                                                                      controller!.seekTo(
                                                                        Duration
                                                                            .zero,
                                                                      );
                                                                      setState(
                                                                        () {},
                                                                      );
                                                                    },
                                                                  ),
                                                                ],
                                                              ),
                                                            ],
                                                          );
                                                        } else {
                                                          return const SizedBox(
                                                            height: 180,
                                                            child: Center(
                                                              child: Text(
                                                                "수어 영상 없음",
                                                              ),
                                                            ),
                                                          );
                                                        }
                                                      },
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
                                // 한국어 → 수어
                                final word = inputController.text.trim();
                                if (word.isEmpty) {
                                  Fluttertoast.showToast(msg: '번역할 단어를 입력하세요.');
                                  return;
                                }
                                final videoUrl =
                                    await TranslateApi.translate_word_to_video(
                                      word,
                                    );
                                if (controller != null &&
                                    controller!.value.isInitialized) {
                                  await controller!.pause();
                                  await controller!.dispose();
                                }

                                if (videoUrl != null) {
                                  controller = VideoPlayerController.networkUrl(
                                    Uri.parse(videoUrl),
                                  )..setPlaybackSpeed(1.0);

                                  initVideoPlayer = controller!
                                      .initialize()
                                      .then((_) {
                                        setState(() {
                                          resultKorean = word;
                                        });
                                        controller!.play();
                                      });
                                } else {
                                  Fluttertoast.showToast(
                                    msg: '수어 애니메이션이 없습니다.',
                                  );
                                }
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
