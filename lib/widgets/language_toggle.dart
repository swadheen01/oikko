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
          behavior: HitTestBehavior.opaque,
          onTap: () => LocaleService.toggle(),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.translate_rounded, color: Colors.white, size: 14),
                const SizedBox(width: 5),
                Text(
                  isEn ? 'বাংলা' : 'EN',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
