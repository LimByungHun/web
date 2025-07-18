import 'package:flutter/material.dart';

class Indexbar extends StatelessWidget {
  final List<String> initials;
  final void Function(String) onTap;
  const Indexbar({super.key, required this.initials, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      decoration: BoxDecoration(
        border: Border(left: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: initials.map((char) {
          return IndexBarItem(char: char, onTap: () => onTap(char));
        }).toList(),
      ),
    );
  }
}

class IndexBarItem extends StatefulWidget {
  final String char;
  final VoidCallback onTap;

  const IndexBarItem({super.key, required this.char, required this.onTap});

  @override
  State<IndexBarItem> createState() => IndexBarItemState();
}

class IndexBarItemState extends State<IndexBarItem> {
  bool hovering = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => hovering = true),
      onExit: (_) => setState(() => hovering = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Container(
          width: double.infinity,
          padding: EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: hovering ? Colors.grey.shade200 : Colors.transparent,
          ),
          alignment: Alignment.center,
          child: Text(
            widget.char,
            style: TextStyle(
              fontSize: 12,
              fontWeight: hovering ? FontWeight.bold : FontWeight.normal,
              color: Colors.black54,
            ),
          ),
        ),
      ),
    );
  }
}
