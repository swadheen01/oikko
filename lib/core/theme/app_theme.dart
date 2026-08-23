import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';
import 'theme_service.dart';

/// Global ThemeData for Oikko — premium, soft-shadowed, never flat.
class AppTheme {
  AppTheme._();

  /// Named `light` for historical reasons — it now follows
  /// `ThemeService`, so it returns the dark palette when dark mode is on.
  /// Brightness has to be set explicitly: it's what makes framework-drawn
  /// surfaces (dialogs, popup menus, pickers, switches) pick readable
  /// defaults instead of dark text on a dark sheet.
  static ThemeData get light {
    final isDark = ThemeService.isDark;

    return ThemeData(
      useMaterial3: true,
      brightness: isDark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.surface,
      dialogTheme: DialogThemeData(backgroundColor: AppColors.surface),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.surface,
        textStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimary),
      ),
      colorScheme: ColorScheme.fromSeed(
        brightness: isDark ? Brightness.dark : Brightness.light,
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.danger,
      ),

      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: AppColors.textOnPrimary),
        titleTextStyle: AppTextStyles.h3.copyWith(color: AppColors.textOnPrimary),
      ),

      textTheme: TextTheme(
        headlineLarge: AppTextStyles.h1,
        headlineMedium: AppTextStyles.h2,
        headlineSmall: AppTextStyles.h3,
        bodyLarge: AppTextStyles.bodyLarge,
        bodyMedium: AppTextStyles.bodyMedium,
        labelSmall: AppTextStyles.caption,
      ),

      // Elevated (primary) buttons — flat color fallback;
      // for gradient buttons we use a custom GradientButton widget instead.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnPrimary,
          elevation: 4,
          shadowColor: AppColors.shadow,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          textStyle: AppTextStyles.button,
        ),
      ),

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceMuted,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 18),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Colors.transparent),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary, width: 1.8),
        ),
        hintStyle: AppTextStyles.bodyMedium,
      ),

      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shadowColor: AppColors.shadowAmbient,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: AppColors.glassBorder),
        ),
        margin: EdgeInsets.zero,
      ),

      dividerTheme: DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }
}
