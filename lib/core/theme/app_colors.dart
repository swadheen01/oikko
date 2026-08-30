import 'package:flutter/material.dart';
import 'theme_service.dart';

/// Oikko App Color Palette — Sky Blue Premium Theme, light and dark.
///
/// Depth model: every elevated surface (cards, sheets, hero panels) pairs
/// a hairline `glassBorder` with a two-layer shadow (`shadowAmbient` wide
/// + soft, `shadowContact` tight + close) instead of a single flat shadow.
/// This is what gives the app its "lifted glass" premium feel — apply it
/// consistently via `PremiumCard` rather than ad hoc BoxDecorations.
///
/// Every member is a **getter, not a const**, because they switch on
/// `ThemeService.isDark` at read time. That means they can't be used in a
/// `const` expression — write `BoxDecoration(color: AppColors.surface)`,
/// never `const BoxDecoration(...)`, or the colour freezes to whichever
/// theme was active at compile time.
class AppColors {
  AppColors._();

  static bool get _dark => ThemeService.isDark;

  static Color _pick(Color light, Color dark) => _dark ? dark : light;

  // Primary sky-blue family. Blues lift slightly in dark mode so they stay
  // vivid against a near-black ground instead of muddying into it.
  static Color get primary => _pick(const Color(0xFF0EA5E9), const Color(0xFF38BDF8));
  static Color get primaryDark => _pick(const Color(0xFF0369A1), const Color(0xFF0EA5E9));
  static Color get primaryDeep => _pick(const Color(0xFF0C4A6E), const Color(0xFF075985));
  static Color get primaryLight => _pick(const Color(0xFF7DD3FC), const Color(0xFFBAE6FD));
  static Color get accent => _pick(const Color(0xFF38BDF8), const Color(0xFF7DD3FC));

  // Secondary complementary tone (soft indigo, for depth in gradients)
  static Color get secondary => _pick(const Color(0xFF6366F1), const Color(0xFF818CF8));
  static Color get secondaryDeep => _pick(const Color(0xFF4338CA), const Color(0xFF4F46E5));
  static Color get secondaryLight => _pick(const Color(0xFFA5B4FC), const Color(0xFFC7D2FE));

  // Premium accent — warm amber, used sparingly for highlights/badges.
  static Color get premiumAccent => _pick(const Color(0xFFF0B429), const Color(0xFFFBBF24));

  // Colorful accent family — per-section tab tints (nav icons, drawer
  // entries) and background glow blobs, so the app reads as "premium
  // sky-blue with color" rather than flat mono-blue/white.
  static Color get accentViolet => _pick(const Color(0xFF8B5CF6), const Color(0xFFA78BFA));
  static Color get accentRose => _pick(const Color(0xFFF43F5E), const Color(0xFFFB7185));
  static Color get accentTeal => _pick(const Color(0xFF14B8A6), const Color(0xFF2DD4BF));
  static Color get accentAmber => _pick(const Color(0xFFF59E0B), const Color(0xFFFBBF24));
  static Color get accentCyan => _pick(const Color(0xFF06B6D4), const Color(0xFF22D3EE));

  // Neutral surface tones. The light values carry a real blue tint rather
  // than near-white, so screens read as tinted glass instead of paper.
  static Color get background => _pick(const Color(0xFFE6F1FC), const Color(0xFF070D18));
  static Color get surface => _pick(const Color(0xFFF8FCFF), const Color(0xFF101A2B));
  static Color get surfaceMuted => _pick(const Color(0xFFDFEDFB), const Color(0xFF17233A));
  static Color get surfaceElevated => _pick(const Color(0xFFFFFFFF), const Color(0xFF1B2942));

  /// Translucent card fill — the actual "glass" in the glass look. Sits
  /// over the screen gradient so the blue behind it shows through, which is
  /// what a flat opaque white can never do.
  ///
  /// Kept fairly opaque on purpose: at lower alpha the gradient bleeds
  /// through enough to wash out body text, and Kalpurush's thin strokes
  /// show that far more than a heavier face would.
  static Color get glassFill => _pick(const Color(0xF0FFFFFF), const Color(0xD11B2942));

  /// Slightly stronger glass for surfaces that need more separation
  /// (top bars, bottom nav) while still letting the gradient behind
  /// them tint through.
  static Color get glassChrome => _pick(const Color(0xF2F4FAFF), const Color(0xF20D1526));

  // Text. Darker than a typical slate pair: Kalpurush has only one weight,
  // so every "bold" in the app renders at regular — contrast has to carry
  // the emphasis that weight normally would. `textSecondary` is kept
  // deliberately strong (not a light grey): it backs most body text and
  // captions, and Kalpurush's thin strokes fade fast at low contrast.
  static Color get textPrimary => _pick(const Color(0xFF030609), const Color(0xFFF6FAFE));
  static Color get textSecondary => _pick(const Color(0xFF1F2C3E), const Color(0xFFC3D2E6));
  static Color get textOnPrimary => const Color(0xFFFFFFFF);

  // Status colors — lifted in dark mode for contrast against the dark ground.
  static Color get success => _pick(const Color(0xFF16A34A), const Color(0xFF4ADE80));
  static Color get warning => _pick(const Color(0xFFD97706), const Color(0xFFFBBF24));
  static Color get danger => _pick(const Color(0xFFDC2626), const Color(0xFFF87171));
  static Color get pending => _pick(const Color(0xFFD97706), const Color(0xFFFBBF24));

  // Borders / dividers
  static Color get border => _pick(const Color(0xFFCFE2F6), const Color(0xFF24344F));
  /// Hairline edge-light on elevated cards — brighter in dark mode, where a
  /// light rim is what separates one glass panel from the next.
  static Color get glassBorder => _pick(const Color(0x2E0EA5E9), const Color(0x3D7DD3FC));
  static Color get glassBorderOnDark => const Color(0x33FFFFFF);

  // Shadows — layered: a wide soft ambient glow + a tight contact shadow.
  static Color get shadow => _pick(const Color(0x1A0EA5E9), const Color(0x33000000));
  static Color get shadowAmbient => _pick(const Color(0x1F0C4A6E), const Color(0x59000000));
  static Color get shadowContact => _pick(const Color(0x210369A1), const Color(0x40000000));
}
