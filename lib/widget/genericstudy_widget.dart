import 'package:flutter/material.dart';

import 'package:video_player/video_player.dart';
import 'package:sign_web/screen/study_screen.dart';
import 'package:sign_web/service/study_api.dart';
import 'package:sign_web/widget/camera_widget.dart';

class GenericStudyWidget extends StatefulWidget {
  final List<String> items;
  final int sid;
  final int step;
  final VoidCallback? onReview;
  const GenericStudyWidget({
    super.key,
    required this.items,
    required this.sid,
    required this.step,
    this.onReview,
  });

  @override
  State<GenericStudyWidget> createState() => GenericStudyWidgetState();
}

class GenericStudyWidgetState extends State<GenericStudyWidget> {
  late PageController pageCtrl;
  int pageIndex = 0;
  VideoPlayerController? videoplayer;
  bool showCamera = false;

  @override
  void initState() {
    super.initState();
    pageCtrl = PageController(initialPage: 0);
    // initVideo();
  }

  void initVideo() {
    final item = widget.items[pageIndex];

    videoplayer?.dispose();
    videoplayer =
        VideoPlayerController.networkUrl(
            Uri.parse(
              'http://10.101.170.168/video/${Uri.encodeComponent(item)}.mp4',
            ),
          )
          ..setLooping(true)
          ..setPlaybackSpeed(1.0);
  }

  Future<void> onNext() async {
    if (pageIndex < widget.items.length - 1) {
      pageCtrl.nextPage(
        duration: Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      try {
        await StudyApi.completeStudy(sid: widget.sid, step: widget.step);
        print("학습 완료 저장 성공");
      } catch (e) {
        print("학습 완료 저장 실패: $e");
      }

      final screenState = context.findAncestorStateOfType<StudyScreenState>();
      if (screenState != null) {
        screenState.nextStep();
      } else {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  @override
  void dispose() {
    videoplayer?.dispose();
    pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isWide = screenWidth > 900;
    final usableHeight = screenHeight - 350;
    final maxChildWidth = (screenWidth - 64) / 2;
    final adjustedSize = usableHeight.clamp(150.0, maxChildWidth);
    final item = widget.items[pageIndex];

    Widget videoWidget = SizedBox(
      width: adjustedSize,
      height: adjustedSize,
      child: videoplayer != null && videoplayer!.value.isInitialized
          ? FittedBox(
              fit: BoxFit.contain,
              child: SizedBox(
                width: adjustedSize,
                height: adjustedSize,
                child: VideoPlayer(videoplayer!),
              ),
            )
          : const Center(child: CircularProgressIndicator()),
    );

    Widget cameraControlWidget = Column(
      children: [
        IconButton(
          icon: const Icon(Icons.videocam, size: 36),
          onPressed: () => setState(() => showCamera = true),
        ),
        if (showCamera)
          SizedBox(
            width: adjustedSize,
            height: adjustedSize,
            child: CameraWidget(
              onFinish: (file) {
                debugPrint("녹화된 경로: ${file.path}");
                setState(() => showCamera = false);
              },
            ),
          )
        else
          const Text('카메라를 실행하려면 아이콘을 누르세요', style: TextStyle(fontSize: 12)),
      ],
    );

    return Column(
      children: [
        Expanded(
          child: PageView.builder(
            controller: pageCtrl,
            itemCount: widget.items.length,
            onPageChanged: (idx) {
              setState(() => pageIndex = idx);
              initVideo();
            },
            itemBuilder: (_, i) {
              return SingleChildScrollView(
                child: IntrinsicHeight(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 16,
                      horizontal: 16,
                    ),
                    child: Column(
                      children: [
                        Text(
                          item,
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (isWide)
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1200),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Flexible(child: videoWidget),
                                const SizedBox(width: 24),
                                Flexible(child: cameraControlWidget),
                              ],
                            ),
                          )
                        else
                          Column(
                            children: [
                              videoWidget,
                              const SizedBox(height: 5),
                              cameraControlWidget,
                            ],
                          ),
                        const SizedBox(height: 10),
                        Text(
                          '$item 수어 표현 방법 적어야함',
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: onNext,
            child: Text(pageIndex < widget.items.length - 1 ? '다음' : '학습 완료'),
          ),
        ),
        if (widget.onReview != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: widget.onReview,
                    child: const Text("복습하기"),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
