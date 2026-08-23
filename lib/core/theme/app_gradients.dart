import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'theme_service.dart';

/// Reusable premium gradients for the Oikko app.
/// Used on: app bars, primary buttons, dashboard header cards, profile banners.
///
/// Like AppColors these are getters, not consts — they switch on
/// `ThemeService.isDark`, so they can't appear inside a `const` expression.
class AppGradients {
  AppGradients._();

  static bool get _dark => ThemeService.isDark;

  /// Main brand gradient — used on headers, app bar, splash.
  /// Anchored by a deep ink-sky stop so it reads rich rather than pastel.
  static LinearGradient get primary => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _dark
            ? const [
                Color(0xFF0EA5E9),
                Color(0xFF0369A1),
                Color(0xFF0C2A43),
                Color(0xFF0A1626),
              ]
            : const [
                Color(0xFF38BDF8),
                Color(0xFF0EA5E9),
                Color(0xFF075985),
                Color(0xFF0C4A6E),
              ],
        stops: const [0.0, 0.4, 0.75, 1.0],
      );

  /// Softer gradient for cards / containers (subtle, premium)
  static LinearGradient get softCard => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _dark
            ? const [Color(0xFF1B2942), Color(0xFF132034)]
            : const [Color(0xFFFFFFFF), Color(0xFFE2F1FF)],
      );

  /// Gradient for primary buttons — sky → blue → violet. Kept vivid and
  /// slightly diagonal so buttons don't read as a flat single-hue fill.
  static LinearGradient get button => LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          AppColors.primary,
          const Color(0xFF3B82F6),
          AppColors.accentViolet,
        ],
        stops: const [0.0, 0.55, 1.0],
      );

  /// Dashboard hero / balance-card gradient — sky blue → indigo.
  /// Deepened at both ends so white text/numerals sit on real contrast.
  static LinearGradient get heroCard => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _dark
            ? const [Color(0xFF0C7CB8), Color(0xFF0B3F6B), Color(0xFF312E81)]
            : const [Color(0xFF0EA5E9), Color(0xFF0369A1), Color(0xFF4338CA)],
        stops: const [0.0, 0.55, 1.0],
      );

  /// Faint diagonal sheen laid over hero/gradient cards for a glass highlight —
  /// draw as an overlay Container on top of heroCard/primary, never standalone.
  static LinearGradient get glassSheen => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _dark
            ? const [Color(0x1FFFFFFF), Color(0x00FFFFFF), Color(0x00FFFFFF)]
            : const [Color(0x40FFFFFF), Color(0x0DFFFFFF), Color(0x00FFFFFF)],
        stops: const [0.0, 0.5, 1.0],
      );

  /// Top-edge highlight for glass panels: a bright hairline fading out
  /// downward, the way light catches the lip of a frosted pane. Overlay it
  /// on a card whose fill is already translucent.
  static LinearGradient get glassEdge => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: _dark
            ? const [Color(0x24FFFFFF), Color(0x00FFFFFF)]
            : const [Color(0x59FFFFFF), Color(0x00FFFFFF)],
        stops: const [0.0, 0.45],
      );

  /// Full-screen background. The light version is deliberately blue rather
  /// than near-white — the app read as "very white" when this was almost
  /// paper-coloured, and every glass surface above it depends on having
  /// real colour behind to tint.
  static LinearGradient get screenBackground => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: _dark
            ? const [
                Color(0xFF0A1524),
                Color(0xFF070D18),
                Color(0xFF0B1A2E),
              ]
            : const [
                Color(0xFFCFE6FB),
                Color(0xFFE8F3FE),
                Color(0xFFDDEDFC),
              ],
        stops: const [0.0, 0.45, 1.0],
      );

  /// A faint accent tint laid **over** a glass card, never instead of its
  /// fill. Deliberately mostly transparent: an opaque wash turns the card
  /// into a solid coloured box that reads as separate from the page, which
  /// is the opposite of the glass effect it sits on. The accent should
  /// only whisper which kind of item this is — the icon chip and badge do
  /// the actual signalling.
  static LinearGradient accentWash(Color accent) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          accent.withValues(alpha: ThemeService.isDark ? 0.20 : 0.16),
          accent.withValues(alpha: 0.0),
          AppColors.primary.withValues(alpha: ThemeService.isDark ? 0.12 : 0.09),
        ],
        stops: const [0.0, 0.55, 1.0],
      );
}
