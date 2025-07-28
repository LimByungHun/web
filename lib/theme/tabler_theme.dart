import 'package:flutter/material.dart';

class TablerColors {
  static const primary = Color(0xFF206bc4); // 블루
  static const secondary = Color(0xFF6c757d); // 그레이
  static const success = Color(0xFF2fb344); // 그린
  static const warning = Color(0xFFf76707); // 오렌지
  static const danger = Color(0xFFd63384); // 핑크
  static const info = Color(0xFF17a2b8); // 시안

  // 배경색
  static const background = Color(0xFFf8fafc); // 연한 그레이
  static const cardBackground = Colors.white;
  static const border = Color(0xFFdadcde); // 테두리
  static const textPrimary = Color(0xFF1e293b); // 진한 그레이
  static const textSecondary = Color(0xFF64748b); // 중간 그레이
}

class TablerTheme {
  static ThemeData get lightTheme => ThemeData(
    useMaterial3: true,
    fontFamily: 'Inter', // 웹 전용 폰트
    colorScheme: ColorScheme.fromSeed(
      seedColor: TablerColors.primary,
      brightness: Brightness.light,
      surface: TablerColors.background,
      onSurface: TablerColors.textPrimary,
    ),
    scaffoldBackgroundColor: TablerColors.background,

    // AppBar 테마
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: TablerColors.textPrimary,
      elevation: 1,
      shadowColor: Colors.black.withOpacity(0.05),
      titleTextStyle: TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: TablerColors.textPrimary,
      ),
    ),

    // ElevatedButton 테마
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: TablerColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        textStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ),

    // OutlinedButton 테마
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TablerColors.primary,
        side: BorderSide(color: TablerColors.primary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    ),
  );
}
