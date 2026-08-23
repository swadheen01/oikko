import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Text styles using Hind Siliguri — a clean font with full Bangla + Latin support.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle _base = GoogleFonts.hindSiliguri();

  /// Large hero headline — splash screen, hero balance labels.
  static TextStyle get display => _base.copyWith(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.8,
    height: 1.1,
  );

  /// Small uppercase eyebrow label used above section titles / hero stats
  /// (e.g. "TOTAL BALANCE", "সাম্প্রতিক লেনদেন") for a premium editorial feel.
  static TextStyle get overline => _base.copyWith(
    fontSize: 11.5,
    fontWeight: FontWeight.w700,
    color: AppColors.textSecondary,
    letterSpacing: 1.1,
  );

  static TextStyle get h1 => _base.copyWith(
    fontSize: 30,
    fontWeight: FontWeight.w800,
    color: AppColors.textPrimary,
    letterSpacing: -0.6,
    height: 1.15,
  );

  static TextStyle get h2 => _base.copyWith(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
  );

  static TextStyle get h3 => _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    color: AppColors.textPrimary,
  );

  static TextStyle get bodyLarge => _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle get bodyMedium => _base.copyWith(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static TextStyle get caption => _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get bodySmall => _base.copyWith(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
  );

  static TextStyle get button => _base.copyWith(
    fontSize: 16,
    fontWeight: FontWeight.w600,
    color: AppColors.textOnPrimary,
    letterSpacing: 0.3,
  );

  static TextStyle get amountLarge => _base.copyWith(
    fontSize: 34,
    fontWeight: FontWeight.w800,
    color: AppColors.textOnPrimary,
    letterSpacing: -0.6,
    fontFeatures: const [FontFeature.tabularFigures()],
  );

  /// Mid-size amount used in list rows / cards where a number needs to stand
  /// out but isn't the hero figure — keeps digits aligned via tabular figures.
  static TextStyle get amountMedium => _base.copyWith(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
}
