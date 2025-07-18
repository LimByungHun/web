import 'package:flutter/material.dart';

class StetscardWidget extends StatelessWidget {
  final int learnedWords; // 학습한 단어 수
  final int streakDays; // 연속 학습일 수
  final double overallPercent; // 전체 학습 퍼센트

  const StetscardWidget({
    super.key,
    required this.learnedWords,
    required this.streakDays,
    required this.overallPercent,
  });

  @override
  Widget build(BuildContext context) {
    final percent = overallPercent;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.purple.shade50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          // 진행률 원형 차트
          SizedBox(
            width: 72,
            height: 72,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: percent,
                  strokeWidth: 6,
                  backgroundColor: Colors.purple.shade100,
                  valueColor: const AlwaysStoppedAnimation(Colors.purple),
                ),
                Text(
                  '${(percent * 100).round()}%',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // 학습 지표들
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '나의 학습 통계',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                buildStatRow('학습한 단어', '$learnedWords 개'),
                const SizedBox(height: 4),
                buildStatRow('연속 학습', '🔥 $streakDays 일'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget buildStatRow(String label, String value) {
    return Row(
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 14, color: Colors.black54),
        ),
        Text(
          value,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}
