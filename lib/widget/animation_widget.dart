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

  void reset() {
    timer?.cancel();
    if (mounted) {
      setState(() => frameIndex = 0);
      startAnimation();
    }
  }

  void startAnimation() {
    if (widget.frames.isEmpty) return;

    final interval = Duration(milliseconds: (1000 ~/ widget.fps));
    timer = Timer.periodic(interval, (_) {
      if (!mounted) {
        timer?.cancel();
        return;
      }

      if (frameIndex < widget.frames.length - 1) {
        setState(() => frameIndex++);
      } else {
        timer?.cancel();
      }
    });
  }

  @override
  void initState() {
    super.initState();
    frameIndex = 0;

    // 프레임이 있을 때만 애니메이션 시작
    if (widget.frames.isNotEmpty) {
      startAnimation();
    }
  }

  @override
  void didUpdateWidget(AnimationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // 프레임이 변경되었을 때 안전하게 처리
    if (widget.frames != oldWidget.frames) {
      timer?.cancel();
      if (widget.frames.isNotEmpty) {
        frameIndex = 0;
        startAnimation();
      }
    }
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 프레임이 없거나 인덱스가 범위를 벗어나면 로딩 표시
    if (widget.frames.isEmpty ||
        frameIndex >= widget.frames.length ||
        frameIndex < 0) {
      return Container(
        color: Colors.black,
        child: Center(
          child: Text('프레임 로딩 중...', style: TextStyle(color: Colors.white70)),
        ),
      );
    }

    try {
      return Image.memory(
        widget.frames[frameIndex],
        gaplessPlayback: true,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            color: Colors.black,
            child: Center(
              child: Text('프레임 오류', style: TextStyle(color: Colors.white70)),
            ),
          );
        },
      );
    } catch (e) {
      print("애니메이션 렌더링 오류: $e");
      return Container(
        color: Colors.black,
        child: Center(
          child: Text('애니메이션 오류', style: TextStyle(color: Colors.white70)),
        ),
      );
    }
  }
}
