import 'package:flutter/material.dart';
import '../core/locale/locale_service.dart';
import '../core/theme/app_text_styles.dart';

/// Reusable language toggle button used on splash and login screens.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LocaleService.notifier,
      builder: (context, value, _) {
        final isEn = value == Language.en;
        return GestureDetector(
          onTap: () => LocaleService.toggle(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.25)),
            ),
            child: Text(
              isEn ? 'EN' : 'বাংলা',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white,
                fontSize: 12,
              ),
            ),
          ),
        );
      },
    );
  }
}
