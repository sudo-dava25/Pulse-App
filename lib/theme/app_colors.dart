import 'package:flutter/material.dart';

/// Palet warna app utama (bukan tema overlay) - senada dengan preview
/// HTML "clean iOS bright" yang sudah disetujui.
class AppColors {
  AppColors._();

  static const bg = Color(0xFFF2F2F7);
  static const card = Color(0xFFFFFFFF);
  static const hairline = Color(0xFFE5E5EA);
  static const text = Color(0xFF1C1C1E);
  static const muted = Color(0xFF8E8E93);

  static const blue = Color(0xFF0A84FF);
  static const blueSoft = Color(0xFFE8F3FF);
  static const orange = Color(0xFFFF9F0A);
  static const orangeSoft = Color(0xFFFFF3E0);
  static const purple = Color(0xFFBF5AF2);
  static const purpleSoft = Color(0xFFF6E9FE);
  static const green = Color(0xFF30D158);
  static const greenSoft = Color(0xFFE6FBEA);
  static const pink = Color(0xFFFF375F);
  static const pinkSoft = Color(0xFFFFE8ED);
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.bg,
    fontFamily: '.SF UI Text', // fallback otomatis ke system font di Android
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: Brightness.light,
      surface: AppColors.bg,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.text),
    ),
  );
}
