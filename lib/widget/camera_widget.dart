import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:permission_handler/permission_handler.dart';

class CameraWidget extends StatefulWidget {
  final void Function(XFile file) onFinish;

  const CameraWidget({super.key, required this.onFinish});

  @override
  State<CameraWidget> createState() => _CameraWidgetState();
}

class _CameraWidgetState extends State<CameraWidget> {
  CameraController? controller;
  bool isInitialized = false;

  @override
  void initState() {
    super.initState();
    initCamera();
  }

  Future<void> initCamera() async {
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

    final cameras = await availableCameras();
    final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front,
      orElse: () => cameras.first,
    );

    controller = CameraController(
      frontCamera,
      ResolutionPreset.medium,
      enableAudio: false,
    );

    try {
      await controller!.initialize();
      await controller!.prepareForVideoRecording();
      await controller!.startVideoRecording();

      setState(() => isInitialized = true);

      await Future.delayed(Duration(seconds: 5));

      if (controller != null && controller!.value.isRecordingVideo) {
        final file = await controller!.stopVideoRecording();
        final size = await File(file.path).length();
        print("영상 저장됨: ${file.path}, 크기: $size bytes");

        widget.onFinish(file);
      }
    } catch (e) {
      Fluttertoast.showToast(msg: "카메라 오류: \$e");
    }
  }

  @override
  void dispose() {
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
