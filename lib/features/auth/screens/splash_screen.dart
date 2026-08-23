import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../widgets/app_logo.dart';

/// Shown briefly on app launch — sets the premium first impression
/// with the brand gradient before AuthWrapper decides where to route.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.primary),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const AppLogo(size: 88, withGlassBackground: true),
                    const SizedBox(height: 20),
                    Text(
                      AppStrings.appName,
                      style: AppTextStyles.h1.copyWith(
                        color: AppColors.textOnPrimary,
                        fontSize: 32,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      AppStrings.appTagline,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 40),
                    const SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    ),
                  ],
                ),
              ),

              // (language toggle removed from splash — kept on other screens)
            ],
          ),
        ),
      ),
    );
  }
}

// Legacy local toggle removed; using reusable `LanguageToggle` widget instead.
