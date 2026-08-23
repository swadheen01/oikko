import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

/// Static "About the association" page — the full version of the
/// condensed card shown on the home screen. Content sourced from the
/// planning doc (README section 1: association name, location, contact).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    // externalApplication so links open in the browser / native app rather
    // than a stripped-down in-app view. Launch is attempted regardless of
    // canLaunchUrl(), which reports false on some devices even when a
    // handler exists.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;

    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              ),
              const SizedBox(height: AppDimensions.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.lg),
                decoration: BoxDecoration(
                  gradient: AppGradients.heroCard,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  border: Border.all(color: AppColors.glassBorderOnDark),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppLogo(size: 40, withGlassBackground: true),
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      isEn
                          ? 'Baniyachong Upazila Teachers Association'
                          : 'বানিয়াচং উপজেলা শিক্ষক সমিতি',
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isEn ? 'Habiganj, Bangladesh' : 'হবিগঞ্জ, বাংলাদেশ',
                      style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'About us' : 'আমাদের সম্পর্কে',
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      isEn
                          ? 'Oikko (ঐক্য) brings together the teachers of Baniyachong Upazila under '
                              'one platform — a shared member directory, dues and welfare-fund tracking, '
                              'notices, and community voting, all in one place.'
                          : 'ঐক্য অ্যাপের মাধ্যমে বানিয়াচং উপজেলার সকল শিক্ষক একটি প্ল্যাটফর্মে যুক্ত হয়েছেন — '
                              'সদস্য তালিকা, চাঁদা ও কল্যাণ তহবিলের হিসাব, নোটিশ এবং সিদ্ধান্ত গ্রহণের ভোটিং, সবকিছু একসাথে।',
                      style: AppTextStyles.bodyLarge,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isEn ? 'Contact' : 'যোগাযোগ',
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    _ContactRow(
                      icon: Icons.person_rounded,
                      label: isEn ? 'General Secretary' : 'সাধারণ সম্পাদক',
                      value: 'Mohammad Mofazzal Hossain',
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    _ContactRow(
                      icon: Icons.school_rounded,
                      label: isEn ? 'Assistant Teacher' : 'সহকারী শিক্ষক',
                      value: 'Baniyachong Adarsha High School',
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    InkWell(
                      borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                      onTap: () => _launch('tel:01722917918'),
                      child: const _ContactRow(
                        icon: Icons.call_rounded,
                        label: 'Phone',
                        value: '01722 917 918',
                      ),
                    ),
                  ],
                ),
              ),
              // Developer credit lives on its own page (DeveloperScreen,
              // reachable from the drawer) — this page is about the
              // association, not who built the app.
              const SizedBox(height: AppDimensions.lg),
            ],
          ),
        ),
      ),
    );
  }
}


class _ContactRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Icon(icon, color: AppColors.primary, size: AppDimensions.iconSm),
        ),
        const SizedBox(width: AppDimensions.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: AppTextStyles.overline),
              Text(value, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}
