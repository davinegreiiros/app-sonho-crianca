import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.accent,
        brightness: Brightness.light,
        primary: AppColors.accent,
        secondary: AppColors.accent2,
        surface: AppColors.bg,
      ),
    );
    final serif = GoogleFonts.sourceSerif4TextTheme(base.textTheme);
    return base.copyWith(
      textTheme: serif.apply(
        bodyColor: AppColors.text,
        displayColor: AppColors.text,
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
  }
}
