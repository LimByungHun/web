import 'package:flutter/material.dart';

class Neumorphism extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final Offset offset;
  final Color backgroundColor;
  final EdgeInsetsGeometry padding;
  final double? height;
  final double? width;

  const Neumorphism({
    super.key,
    required this.child,
    this.borderRadius = 20.0,
    this.blur = 10.0,
    this.offset = const Offset(6, 6),
    this.backgroundColor = const Color.fromARGB(255, 254, 241, 255),
    this.padding = const EdgeInsets.all(16),
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: Colors.white.withAlpha(200),
            offset: -offset,
            blurRadius: blur,
          ),
          BoxShadow(
            color: Colors.black.withAlpha(25),
            offset: offset,
            blurRadius: blur,
          ),
        ],
      ),
      child: child,
    );
  }
}
