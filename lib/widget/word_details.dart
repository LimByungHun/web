import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class WordDetails extends StatelessWidget {
  final String word;
  final String pos;
  final String definition;
  final VoidCallback onClose;
  final VideoPlayerController? controller;
  final Future<void>? initVideoPlayer;

  const WordDetails({
    super.key,
    required this.word,
    required this.pos,
    required this.definition,
    required this.onClose,
    this.controller,
    this.initVideoPlayer,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          border: Border.all(),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  word,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: onClose),
              ],
            ),
            const SizedBox(height: 8),
            if (controller != null && initVideoPlayer != null)
              FutureBuilder(
                future: initVideoPlayer,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.done &&
                      controller!.value.isInitialized) {
                    return AspectRatio(
                      aspectRatio: controller!.value.aspectRatio,
                      child: VideoPlayer(controller!),
                    );
                  } else {
                    return SizedBox(
                      height: 120,
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                },
              ),
            const SizedBox(height: 8),
            const Text('수화 설명 출력 예정'),
          ],
        ),
      ),
    );
  }
}
