import 'package:flutter/material.dart';

class AppColors {
  // Primary colors
  static const Color primary = Color(0xFF1D61E7);
  static const Color primaryDark = Color(0xFF1243A6);
  static const Color primaryLight = Color(0xFFEFF4FF);
  
  // Backgrounds
  static const Color background = Color(0xFFF4F6F9);
  static const Color surface = Colors.white;
  static const Color cardBorder = Color(0xFFE2E8F0);

  // Text
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status colors & backgrounds
  static const Color openBg = Color(0xFFE0F2FE);
  static const Color openText = Color(0xFF0284C7);

  static const Color inProgressBg = Color(0xFFDBEAFE);
  static const Color inProgressText = Color(0xFF2563EB);

  static const Color doneBg = Color(0xFFDCFCE7);
  static const Color doneText = Color(0xFF16A34A);

  static const Color closedBg = Color(0xFFF1F5F9);
  static const Color closedText = Color(0xFF64748B);

  static const Color pendingBg = Color(0xFFFEF3C7);
  static const Color pendingText = Color(0xFFD97706);

  static const Color assignedBg = Color(0xFFE0E7FF);
  static const Color assignedText = Color(0xFF4338CA);

  // Priority colors & backgrounds
  static const Color priorityLowBg = Color(0xFFDCFCE7);
  static const Color priorityLowText = Color(0xFF16A34A);

  static const Color priorityMediumBg = Color(0xFFFFEDD5);
  static const Color priorityMediumText = Color(0xFFEA580C);

  static const Color priorityHighBg = Color(0xFFFEE2E2);
  static const Color priorityHighText = Color(0xFFDC2626);

  static const Color priorityCriticalBg = Color(0xFFF3E8FF);
  static const Color priorityCriticalText = Color(0xFF9333EA);

  // Team chart colors
  static const Color teamWeb = Color(0xFF2563EB);
  static const Color teamMobile = Color(0xFF38BDF8);
  static const Color teamBackend = Color(0xFFF97316);
  static const Color teamInfra = Color(0xFFA855F7);
  static const Color teamOther = Color(0xFF64748B);
}

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      splashFactory: InkRipple.splashFactory,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        surface: AppColors.surface,
        background: AppColors.background,
      ),
      fontFamily: 'SF Pro Display', // Default fallback font
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.cardBorder, width: 1),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
