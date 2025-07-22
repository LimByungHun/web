import 'package:flutter/material.dart';
import 'package:sign_web/widget/quiz_widget.dart';

class AlllistWidget extends StatelessWidget {
  final String title;
  final Map<String, List<Map<String, dynamic>>> courseWordsMap;

  const AlllistWidget({
    super.key,
    required this.title,
    required this.courseWordsMap,
  });

  @override
  Widget build(BuildContext context) {
    final courseNames = courseWordsMap.keys.toList();

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: courseNames.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final name = courseNames[index];
          final words = courseWordsMap[name]!;

          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.deepPurple,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => GenericQuizWidget(
                          words: words,
                          completeOnFinish: false,
                          showAppBar: true,
                        ),
                      ),
                    );
                  },
                  child: const Text('복습하기', style: TextStyle(fontSize: 13)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
