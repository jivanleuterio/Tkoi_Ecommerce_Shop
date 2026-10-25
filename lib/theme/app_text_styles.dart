import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTextStyles {
  static TextTheme get textTheme => const TextTheme(
    displaySmall: TextStyle(
      fontSize: 38,
      height: 1.08,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.2,
      color: AppColors.sumi,
    ),
    headlineLarge: TextStyle(
      fontSize: 30,
      height: 1.15,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.7,
      color: AppColors.sumi,
    ),
    headlineMedium: TextStyle(
      fontSize: 26,
      height: 1.2,
      fontWeight: FontWeight.w800,
      letterSpacing: -0.4,
      color: AppColors.sumi,
    ),
    headlineSmall: TextStyle(
      fontSize: 22,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: AppColors.sumi,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: AppColors.sumi,
    ),
    titleMedium: TextStyle(
      fontSize: 16,
      height: 1.3,
      fontWeight: FontWeight.w700,
      color: AppColors.sumi,
    ),
    bodyLarge: TextStyle(fontSize: 16, height: 1.5, color: AppColors.sumi),
    bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: AppColors.sumi),
    bodySmall: TextStyle(fontSize: 12, height: 1.4, color: AppColors.softGray),
    labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
  );
}
