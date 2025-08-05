import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:sign_web/model/course_model.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

class ReviewCard extends StatefulWidget {
  const ReviewCard({super.key});

  @override
  State<ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<ReviewCard> {
  @override
  void initState() {
    super.initState();
    // 컴포넌트 초기화 시 복습 가능한 단어들 로드
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseModel>().loadReviewableStep5Words();
    });
  }

  @override
  Widget build(BuildContext context) {
    final courseModel = context.watch<CourseModel>();

    // 서버에서 가져온 모든 복습 가능한 단어들
    final reviewableWords = courseModel.reviewableStep5Words;

    // 현재 코스가 아닌 다른 코스들만 필터링
    final otherCoursesWords = <String, List<Map<String, dynamic>>>{};
    reviewableWords.forEach((courseName, words) {
      if (courseName != courseModel.selectedCourse) {
        otherCoursesWords[courseName] = words;
      }
    });
    return TablerCard(
      title: '복습하기',
      actions: otherCoursesWords.length > 3
          ? [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: TablerColors.textSecondary),
                onSelected: (value) {
                  switch (value) {
                    case 'current_all':
                      break;
                    case 'other_all':
                      GoRouter.of(context).push(
                        '/review_all',
                        extra: {
                          'courseWordsMap': otherCoursesWords,
                          'title': '다른 코스 도전',
                        },
                      );
                      break;
                    case 'mixed':
                      final mixedWords = _getMixedWords(otherCoursesWords, 20);
                      if (mixedWords.isNotEmpty) {
                        GoRouter.of(context).push(
                          '/review',
                          extra: {'words': mixedWords, 'title': '혼합 도전 퀴즈'},
                        );
                      }
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'other_all',
                    child: Row(
                      children: [
                        Icon(Icons.explore, size: 18, color: TablerColors.info),
                        SizedBox(width: 8),
                        Text('다른 코스 전체보기'),
                      ],
                    ),
                  ),
                  PopupMenuItem(
                    value: 'mixed',
                    child: Row(
                      children: [
                        Icon(
                          Icons.shuffle,
                          size: 18,
                          color: TablerColors.warning,
                        ),
                        SizedBox(width: 8),
                        Text('혼합 도전 퀴즈'),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 100),
        child: otherCoursesWords.isEmpty
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.quiz_outlined,
                      size: 36,
                      color: TablerColors.textSecondary,
                    ),
                    SizedBox(height: 12),
                    Text(
                      '복습할 내용이 없습니다',
                      style: TextStyle(color: TablerColors.textSecondary),
                    ),
                    SizedBox(height: 8),
                    Text(
                      '다른 코스로 도전해보세요',
                      style: TextStyle(
                        fontSize: 12,
                        color: TablerColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 다른 코스 도전만 표시 (현재 코스 제외)
                  if (otherCoursesWords.isNotEmpty) ...[
                    ...otherCoursesWords.entries
                        .take(3)
                        .map(
                          (entry) => _buildReviewItem(
                            context: context,
                            courseName: entry.key,
                            words: entry.value,
                            subtitle: '다른 코스 도전',
                            color: TablerColors.info,
                            icon: Icons.explore,
                          ),
                        ),
                  ],

                  // 혼합 도전 퀴즈 버튼
                  if (otherCoursesWords.isNotEmpty) ...[
                    SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: TablerButton(
                        text: '혼합 도전 퀴즈 (랜덤 20문제)',
                        icon: Icons.shuffle,
                        type: TablerButtonType.warning,
                        outline: true,
                        onPressed: () {
                          final mixedWords = _getMixedWords(
                            otherCoursesWords,
                            20,
                          );
                          if (mixedWords.isNotEmpty) {
                            GoRouter.of(context).push(
                              '/review',
                              extra: {'words': mixedWords, 'title': '혼합 도전 퀴즈'},
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  // 여러 코스의 단어들을 섞어서 랜덤하게 가져오는 메서드
  List<Map<String, dynamic>> _getMixedWords(
    Map<String, List<Map<String, dynamic>>> coursesWords,
    int count,
  ) {
    final allWords = <Map<String, dynamic>>[];

    coursesWords.forEach((courseName, words) {
      for (final word in words) {
        allWords.add({
          ...word,
          'source_course': courseName, // 어느 코스에서 온 단어인지 표시
        });
      }
    });

    allWords.shuffle();
    return allWords.take(count).toList();
  }

  Widget _buildReviewItem({
    required BuildContext context,
    required String courseName,
    required List<Map<String, dynamic>> words,
    required String subtitle,
    required Color color,
    required IconData icon,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: color.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
          color: color.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseName,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: TablerColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '$subtitle · ${words.length}문제',
                    style: TextStyle(
                      fontSize: 12,
                      color: TablerColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TablerButton(
              text: '시작',
              small: true,
              type: color == TablerColors.success
                  ? TablerButtonType.success
                  : TablerButtonType.danger,
              onPressed: () => GoRouter.of(context).push(
                '/review',
                extra: {
                  'words': words,
                  'title':
                      '$courseName ${subtitle == '완료한 학습' ? '복습' : '도전'} 퀴즈',
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
