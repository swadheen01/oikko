import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_gradients.dart';
import 'core/theme/app_text_styles.dart';
import 'core/theme/theme_service.dart';
import 'core/constants/app_strings.dart';
import 'core/constants/supabase_config.dart';
import 'core/utils/app_snackbar.dart';
import 'features/auth/auth_wrapper.dart';
import 'features/auth/screens/splash_screen.dart';
import 'firebase_options.dart';
import 'core/locale/locale_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  // Used only for Storage (profile photos) — see supabase_config.dart.
  await Supabase.initialize(url: SupabaseConfig.url, publishableKey: SupabaseConfig.anonKey);
  runApp(const OikkoApp());
}

class OikkoApp extends StatelessWidget {
  const OikkoApp({super.key});

  Future<FirebaseApp?> _initFirebase() async {
    try {
      return Firebase.app();
    } catch (_) {
      // Timeout or initialization error — return null and allow app to continue.
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    // Nested listeners: language and theme each rebuild the whole app, and
    // AppColors/AppGradients read ThemeService at paint time, so the theme
    // listener has to sit above everything that draws.
    return ValueListenableBuilder(
      valueListenable: ThemeService.notifier,
      builder: (context, _, __) => ValueListenableBuilder(
      valueListenable: LocaleService.notifier,
      builder: (context, value, _) {
        return MaterialApp(
          title: AppStrings.appName,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          // Owned by MaterialApp so login/logout confirmations outlive the
          // screen that triggered them — see AppSnackbar.
          scaffoldMessengerKey: AppSnackbar.key,
          // Overlays a brief loading screen while switching language, so the
          // whole UI visibly re-renders into the new language at once.
          builder: (context, child) =>
              _LocaleSwitchOverlay(child: child ?? const SizedBox.shrink()),
          home: _StartupGate(initFirebase: _initFirebase),
        );
      },
      ),
    );
  }
}

/// Guarantees the branded splash is shown on every cold start for at least a
/// short beat — otherwise, with Firebase init resolving almost instantly and
/// a cached login, the splash flashes by and the app appears to open with no
/// splash at all. Reveals [AuthWrapper] once BOTH Firebase has initialised
/// AND the minimum splash time has elapsed.
class _StartupGate extends StatefulWidget {
  final Future<FirebaseApp?> Function() initFirebase;
  const _StartupGate({required this.initFirebase});

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  static const _minSplash = Duration(milliseconds: 1600);

  late final Future<FirebaseApp?> _init = widget.initFirebase();
  bool _minElapsed = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(_minSplash, () {
      if (mounted) setState(() => _minElapsed = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp?>(
      future: _init,
      builder: (context, snapshot) {
        final ready =
            snapshot.connectionState == ConnectionState.done && _minElapsed;
        if (!ready) return const SplashScreen();

        final available = snapshot.hasData && snapshot.data != null;
        return AuthWrapper(firebaseAvailable: available);
      },
    );
  }
}

/// Shows a short full-screen loader whenever the app language changes, so the
/// switch reads as a deliberate, whole-app change rather than a piecemeal
/// flicker. Wraps the whole navigator via MaterialApp.builder, so it covers
/// every screen and every pushed route.
class _LocaleSwitchOverlay extends StatefulWidget {
  final Widget child;
  const _LocaleSwitchOverlay({required this.child});

  @override
  State<_LocaleSwitchOverlay> createState() => _LocaleSwitchOverlayState();
}

class _LocaleSwitchOverlayState extends State<_LocaleSwitchOverlay> {
  bool _switching = false;
  Language _last = LocaleService.current;

  @override
  void initState() {
    super.initState();
    LocaleService.notifier.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    LocaleService.notifier.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    if (_last == LocaleService.current) return;
    _last = LocaleService.current;
    setState(() => _switching = true);
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) setState(() => _switching = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_switching)
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(gradient: AppGradients.screenBackground),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.6,
                        valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      LocaleService.isEnglish ? 'Switching language…' : 'ভাষা পরিবর্তন হচ্ছে…',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
