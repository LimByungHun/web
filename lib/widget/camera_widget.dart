import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraWidget extends StatefulWidget {
  final void Function(XFile file)? onFinish;
  final void Function(List<Uint8List> frames)? onFramesAvailable;
  final bool continuousMode; // true: 연속 프레임 전송, false: 5초 녹화

  const CameraWidget({
    super.key,
    this.onFinish,
    this.onFramesAvailable,
    this.continuousMode = false,
  });

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  CameraController? controller;
  bool isInitialized = false;
  List<Uint8List> frameBuffer = [];
  Timer? captureTimer;
  Timer? recordingTimer;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
    // 웹이 아닌 경우에만 권한 요청
    if (!kIsWeb) {
      final cameraStatus = await Permission.camera.request();
      final micStatus = await Permission.microphone.request();

      if (!cameraStatus.isGranted || !micStatus.isGranted) {
        Fluttertoast.showToast(
          msg: '카메라 또는 마이크 권한이 거부되었습니다.',
          gravity: ToastGravity.BOTTOM,
          backgroundColor: Colors.red,
          textColor: Colors.white,
        );
        return;
      }
    }

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        Fluttertoast.showToast(msg: "사용 가능한 카메라가 없습니다.");
        return;
      }

      // 프론트 카메라 우선 선택
      final frontCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        frontCamera,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: kIsWeb
            ? ImageFormatGroup.jpeg
            : ImageFormatGroup.yuv420,
      );

      await controller!.initialize();

      if (!mounted) return;

      setState(() => isInitialized = true);

      if (widget.continuousMode) {
        // 연속 모드: 프레임을 계속 전송
        startContinuousCapture();
      } else {
        // 일반 모드: 5초 녹화 후 종료
        if (kIsWeb) {
          // 웹에서는 프레임 캡처 방식 사용
          startWebRecording();
        } else {
          // 모바일에서는 비디오 녹화
          await controller!.prepareForVideoRecording();
          await controller!.startVideoRecording();

          recordingTimer = Timer(Duration(seconds: 5), () async {
            if (controller != null && controller!.value.isRecordingVideo) {
              final file = await controller!.stopVideoRecording();
              if (!kIsWeb) {
                final size = await File(file.path).length();
                print("영상 저장됨: ${file.path}, 크기: $size bytes");
              }
              widget.onFinish?.call(file);
            }
          });
        }
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "카메라 오류: $e");
    }
  }

  void startContinuousCapture() {
    if (kIsWeb) {
      // 웹: 주기적으로 사진 찍기
      captureTimer = Timer.periodic(Duration(milliseconds: 200), (timer) async {
        if (controller != null && controller!.value.isInitialized && mounted) {
          try {
            final XFile image = await controller!.takePicture();
            final bytes = await image.readAsBytes();
            frameBuffer.add(bytes);

            // 10개의 프레임이 모이면 콜백 호출
            if (frameBuffer.length >= 10) {
              widget.onFramesAvailable?.call(List.from(frameBuffer));
              frameBuffer.clear();
            }
          } catch (e) {
            print("프레임 캡처 오류: $e");
          }
        }
      });
    } else {
      // 모바일: 이미지 스트림 사용 (기존 코드와 유사)
      controller!.startImageStream((image) {
        // YUV to JPEG 변환 로직 필요
        // 여기서는 간단히 처리
      });
    }
  }

  void startWebRecording() {
    // 웹에서 5초간 프레임 수집
    captureTimer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
      if (controller != null && controller!.value.isInitialized) {
        try {
          final XFile image = await controller!.takePicture();
          final bytes = await image.readAsBytes();
          frameBuffer.add(bytes);
        } catch (e) {
          print("프레임 캡처 오류: $e");
        }
      }
    });

    // 5초 후 종료
    recordingTimer = Timer(Duration(seconds: 5), () {
      captureTimer?.cancel();
      // 수집된 프레임들을 하나의 "파일"로 간주하여 콜백 호출
      if (frameBuffer.isNotEmpty && widget.onFramesAvailable != null) {
        widget.onFramesAvailable!(List.from(frameBuffer));
        frameBuffer.clear();
      }
    });
  }

  @override
  void dispose() {
    captureTimer?.cancel();
    recordingTimer?.cancel();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return isInitialized && controller != null
        ? ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CameraPreview(controller!),
          )
        : const Center(child: CircularProgressIndicator());
  }
}
