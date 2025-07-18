import 'package:flutter/material.dart';

class ChoiceWidget extends StatefulWidget {
  final String description;
  final VoidCallback onSelect;
  final VoidCallback onClose;
  const ChoiceWidget({
    super.key,
    required this.description,
    required this.onSelect,
    required this.onClose,
  });

  @override
  State<ChoiceWidget> createState() => ChoiceWidgetState();
}

class ChoiceWidgetState extends State<ChoiceWidget> {
  bool expanded = true;
  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      padding: EdgeInsets.all(12),
      margin: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
      ),
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onClose, // 박스 부분만 닫기
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(widget.description, style: TextStyle(fontSize: 15)),
            ),
          ),
          // 펼쳐졌을 때 내용
          SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              onPressed: widget.onSelect,
              child: Text("학습 시작"),
            ),
          ),
        ],
      ),
    );
  }
}
