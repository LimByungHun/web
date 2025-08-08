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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CourseModel>().loadReviewableStep5Words();
    });
  }

  @override
  Widget build(BuildContext context) {
    final courseModel = context.watch<CourseModel>();

    final reviewableWords = courseModel.reviewableStep5Words;

    final previewEntries = reviewableWords.entries.take(5).toList();

    return TablerCard(
      title: '복습하기',
      actions: reviewableWords.length > 5
          ? [
              PopupMenuButton<String>(
                icon: Icon(Icons.more_horiz, color: TablerColors.textSecondary),
                onSelected: (value) {
                  switch (value) {
                    case 'all':
                      GoRouter.of(context).push(
                        '/review_all',
                        extra: {
                          'courseWordsMap': reviewableWords,
                          'title': '복습할 수 있는 코스',
                        },
                      );
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'all',
                    child: Row(
                      children: [
                        Icon(Icons.list, size: 18, color: TablerColors.info),
                        SizedBox(width: 8),
                        Text('전체 보기'),
                      ],
                    ),
                  ),
                ],
              ),
            ]
          : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: 100),
        child: reviewableWords.isEmpty
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
                      '더 많은 코스를 완료해보세요',
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
                  // 각 코스별 복습 퀴즈
                  ...previewEntries.map(
                    (entry) => buildReviewItem(
                      context: context,
                      courseName: entry.key,
                      words: entry.value,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget buildReviewItem({
    required BuildContext context,
    required String courseName,
    required List<Map<String, dynamic>> words,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: 8),
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: TablerColors.primary.withOpacity(0.3)),
          borderRadius: BorderRadius.circular(6),
          color: TablerColors.primary.withOpacity(0.05),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: TablerColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(Icons.quiz, color: TablerColors.primary, size: 16),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$courseName 복습',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: TablerColors.textPrimary,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    '${words.length}문제',
                    style: TextStyle(
                      fontSize: 12,
                      color: TablerColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TablerButton(
              text: '복습하기',
              small: true,
              type: TablerButtonType.primary,
              onPressed: () => GoRouter.of(context).push(
                '/review',
                extra: {'words': words, 'title': '$courseName 복습 퀴즈'},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
