import 'package:flutter/material.dart';

class ButtonWidget extends StatefulWidget {
  final String text;
  final VoidCallback onTap;
  final bool selected;
  final TextStyle? textStyle;

  const ButtonWidget({
    super.key,
    required this.text,
    required this.onTap,
    required this.selected,
    this.textStyle,
  });

  @override
  State<ButtonWidget> createState() => ButtonWidgetState();
}

class ButtonWidgetState extends State<ButtonWidget> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    final bgColor = widget.selected
        ? Colors.blue.withOpacity(0.1)
        : (hovering ? Colors.grey.withOpacity(0.1) : Colors.transparent);
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: widget.onTap,
        child: Container(
          margin: EdgeInsets.symmetric(vertical: 4),
          padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              if (widget.selected)
                Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Icon(Icons.arrow_right, size: 20, color: Colors.blue),
                ),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 16,
                    color: widget.selected ? Colors.blue : Colors.black,
                    fontWeight: widget.selected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
