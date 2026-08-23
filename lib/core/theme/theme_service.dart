import 'package:flutter/foundation.dart';

enum AppThemeMode { light, dark }

/// Holds the light/dark choice. Mirrors LocaleService: a single
/// ValueNotifier the app root listens to, so flipping it rebuilds
/// everything without a state-management package.
///
/// AppColors and AppGradients read `isDark` directly, which is why their
/// members are getters rather than compile-time constants.
class ThemeService {
  ThemeService._();

  static final ValueNotifier<AppThemeMode> notifier =
      ValueNotifier(AppThemeMode.light);

  static AppThemeMode get current => notifier.value;

  static bool get isDark => notifier.value == AppThemeMode.dark;

  static void toggle() {
    notifier.value = isDark ? AppThemeMode.light : AppThemeMode.dark;
  }

  static void set(AppThemeMode mode) => notifier.value = mode;
}
