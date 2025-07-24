import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';

class AnimationWidget extends StatefulWidget {
  final List<Uint8List> frames;
  final double fps;

  const AnimationWidget({super.key, required this.frames, this.fps = 10.0});

  @override
  State<AnimationWidget> createState() => AnimationWidgetState();
}

class AnimationWidgetState extends State<AnimationWidget> {
  late int frameIndex;
  Timer? timer;

  /// 외부에서 다시 재생할 수 있도록 공개된 reset 메서드
  void reset() {
    timer?.cancel();
    setState(() => frameIndex = 0);
    startAnimation();
  }

  void startAnimation() {
    final interval = Duration(milliseconds: (1000 ~/ widget.fps));
    timer = Timer.periodic(interval, (_) {
      if (frameIndex < widget.frames.length - 1) {
        setState(() => frameIndex++);
      } else {
        timer?.cancel(); // 자동 종료
      }
    });
  }

  @override
  void initState() {
    super.initState();
    frameIndex = 0;
    startAnimation();
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Image.memory(
      widget.frames[frameIndex],
      gaplessPlayback: true,
      fit: BoxFit.contain,
    );
  }
}
