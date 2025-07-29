import 'package:flutter/material.dart';
import 'package:sign_web/theme/tabler_theme.dart';
import 'package:sign_web/widget/tablerui_widget.dart';

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
    return Container(
      margin: EdgeInsets.symmetric(vertical: 8),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: TablerColors.info.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TablerColors.info.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, size: 18, color: TablerColors.info),

              SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.description,
                  style: TextStyle(
                    fontSize: 14,
                    color: TablerColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.close, size: 18),
                onPressed: widget.onClose,
                splashRadius: 18,
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TablerButton(
                text: '취소',
                outline: true,
                small: true,
                onPressed: widget.onClose,
              ),
              TablerButton(
                text: '학습 시작',
                small: true,
                onPressed: widget.onSelect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
