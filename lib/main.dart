import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
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
          home: FutureBuilder<FirebaseApp?>(
            future: _initFirebase(),
            builder: (context, snapshot) {
              // While initializing, show the app's branded SplashScreen
              if (snapshot.connectionState != ConnectionState.done) {
                return const SplashScreen();
              }

              // Firebase initialized (or failed/timed out) — proceed to auth flow.
              final available = snapshot.hasData && snapshot.data != null;
              return AuthWrapper(firebaseAvailable: available);
            },
          ),
        );
      },
      ),
    );
  }
}
