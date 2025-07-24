import 'dart:html' as html;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class CameraWidgetWeb extends StatefulWidget {
  final void Function(dynamic blob) onFinish;
  const CameraWidgetWeb({super.key, required this.onFinish});

  @override
  State<CameraWidgetWeb> createState() => _CameraWidgetWebState();
}

class _CameraWidgetWebState extends State<CameraWidgetWeb> {
  late html.VideoElement _videoElement;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
  }

  void _initializeCamera() async {
    _videoElement = html.VideoElement()
      ..autoplay = true
      ..style.width = '100%'
      ..style.height = '100%';

    final mediaStream = await html.window.navigator.mediaDevices?.getUserMedia({
      'video': {'facingMode': 'user'},
      'audio': false,
    });

    _videoElement.srcObject = mediaStream;

    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(
      'webcam',
      (int viewId) => _videoElement,
    );

    setState(() => _initialized = true);

    // 녹화 시뮬레이션 (캡처)
    await Future.delayed(Duration(seconds: 3));
    widget.onFinish(mediaStream); // blob이 아니라 stream 넘김
  }

  @override
  Widget build(BuildContext context) {
    return _initialized
        ? HtmlElementView(viewType: 'webcam')
        : const Center(child: CircularProgressIndicator());
  }
}
