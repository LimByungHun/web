import 'package:flutter/material.dart';
import 'package:web/screen/study_screen.dart';

class CourcedataWidget extends StatelessWidget {
  final String courseName;
  final List<String> items;
  const CourcedataWidget({
    super.key,
    required this.courseName,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // 1) PageView 로 항목별 영상/이미지
        Expanded(
          child: PageView.builder(
            itemCount: items.length,
            itemBuilder: (_, i) {
              final item = items[i];
              return Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item, style: TextStyle(fontSize: 64)),
                  SizedBox(height: 24),
                  Image.asset(
                    'assets/signs/$item.gif',
                    width: 200,
                    height: 200,
                  ),
                  SizedBox(height: 16),
                  Text('$item 수어 표현', style: TextStyle(fontSize: 20)),
                ],
              );
            },
          ),
        ),

        // 2) 퀴즈 버튼 (간단 예시)
        Padding(
          padding: const EdgeInsets.all(16),
          child: ElevatedButton(
            onPressed: () {
              // PageView를 통한 학습 이후 퀴즈로 넘어가려면
              // StudyScreen의 nextStep() 호출
              (context.findAncestorStateOfType<StudyScreenState>())?.context;
            },
            child: Text('다음 단계'),
          ),
        ),
      ],
    );
  }
}
