import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

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
  bool isDisposed = false;
  List<Uint8List> frameBuffer = [];
  Timer? captureTimer;
  Timer? recordingTimer;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
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
        imageFormatGroup: ImageFormatGroup.jpeg,
      );

      await controller!.initialize();

      if (!mounted) return;

      setState(() => isInitialized = true);

      if (widget.continuousMode) {
        startContinuousCapture();
      } else {
        startWebRecording();
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "카메라 오류: $e");
    }
  }

  void startContinuousCapture() {
    bool isCapturing = false;
    captureTimer = Timer.periodic(Duration(milliseconds: 200), (timer) async {
      if (isDisposed || !mounted) {
        timer.cancel();
        return;
      }

      if (controller != null &&
          controller!.value.isInitialized &&
          mounted &&
          !isCapturing) {
        isCapturing = true;
        try {
          final XFile image = await controller!.takePicture();
          if (!mounted || isDisposed) return;
          final bytes = await image.readAsBytes();
          if (!mounted || isDisposed) return;
          frameBuffer.add(bytes);

          if (frameBuffer.length >= 30) {
            widget.onFramesAvailable?.call(List.from(frameBuffer));
            frameBuffer.clear();
          }
        } catch (e) {
          print("프레임 캡처 오류: $e");
        } finally {
          isCapturing = false;
        }
      }
    });
  }

  void startWebRecording() {
    bool isCapturing = false;
    int frameCount = 0;
    const maxFrames = 50;
    captureTimer = Timer.periodic(Duration(milliseconds: 100), (timer) async {
      if (!mounted || isDisposed || frameCount >= maxFrames) {
        timer.cancel();
        if (!isDisposed && mounted && frameBuffer.isNotEmpty) {
          handleWebRecordingComplete();
        }
        return;
      }
      if (controller != null &&
          controller!.value.isInitialized &&
          !isCapturing) {
        isCapturing = true;
        try {
          final XFile image = await controller!.takePicture();
          if (!mounted || isDisposed) return;
          final bytes = await image.readAsBytes();
          if (!mounted || isDisposed) return;
          frameBuffer.add(bytes);
          frameCount++;
        } catch (e) {
          print("프레임 캡처 오류: $e");
        } finally {
          isCapturing = false;
        }
      }
    });

    recordingTimer = Timer(Duration(seconds: 5), () {
      if (!mounted || isDisposed) return;

      captureTimer?.cancel();
      handleWebRecordingComplete();
    });
  }

  void handleWebRecordingComplete() {
    if (!mounted || isDisposed) return;

    if (frameBuffer.isNotEmpty) {
      if (widget.onFramesAvailable != null) {
        widget.onFramesAvailable!(List.from(frameBuffer));
      } else if (widget.onFinish != null) {
        final combinedData = <int>[];
        for (final frame in frameBuffer) {
          combinedData.addAll(frame);
        }

        final tempFile = XFile.fromData(
          Uint8List.fromList(combinedData),
          mimeType: 'video/mp4',
          name: 'recording_${DateTime.now().millisecondsSinceEpoch}.mp4',
        );
        widget.onFinish!(tempFile);
      }
      frameBuffer.clear();
    }
  }

  @override
  void dispose() {
    isDisposed = true;
    captureTimer?.cancel();
    recordingTimer?.cancel();
    if (controller != null) {
      controller!.dispose();
    }
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
