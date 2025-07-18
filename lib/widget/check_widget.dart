import 'package:flutter/material.dart';

class Check extends StatelessWidget {
  final String title;
  final String content;
  final String cancelText;
  final String confirmText;
  final VoidCallback onConfirm;

  const Check({
    super.key,
    required this.title,
    required this.content,
    this.cancelText = '취소',
    this.confirmText = '확인',
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(cancelText),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          child: Text(confirmText),
        ),
      ],
    );
  }
}
