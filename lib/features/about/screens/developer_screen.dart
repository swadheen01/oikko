import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/gradient_scaffold.dart';

/// Developer credit, on its own page rather than tacked onto the bottom of
/// the association's About screen — the two are unrelated and the About
/// page is about the association, not who built the app.
class DeveloperScreen extends StatelessWidget {
  const DeveloperScreen({super.key});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    // externalApplication so links open in the browser / native app rather
    // than a stripped-down in-app view. Launched regardless of
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
              Text(AppStrings.developer, style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.lg),

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.lg),
                // The app's own hero gradient, not a one-off palette — a
                // separate colour scheme here is what made this read as a
                // detached box rather than part of the page.
                decoration: BoxDecoration(
                  gradient: AppGradients.heroCard,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                  border: Border.all(color: AppColors.glassBorderOnDark),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.secondaryDeep.withValues(alpha: 0.28),
                      blurRadius: 26,
                      offset: const Offset(0, 14),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF14B8A6)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 12,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'S',
                            style: AppTextStyles.h1.copyWith(
                              color: Colors.white,
                              fontSize: 30,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Swadheen Islam Robi',
                                style: AppTextStyles.h2.copyWith(
                                  color: Colors.white,
                                  fontSize: 21,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                isEn ? 'App Developer' : 'অ্যাপ ডেভেলপার',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    const _EduRow(
                      icon: Icons.school_rounded,
                      name: 'Leading University',
                      detail: 'CSE',
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    const _EduRow(
                      icon: Icons.menu_book_rounded,
                      name: 'Baniyachong Adarsha High School',
                      detail: 'SSC-18',
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    Divider(color: Colors.white.withValues(alpha: 0.15), height: 1),
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      isEn ? 'Connect' : 'যোগাযোগ করুন',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Row(
                      children: [
                        _SocialButton(
                          icon: Icons.code_rounded,
                          label: 'GitHub',
                          colors: const [Color(0xFF24292E), Color(0xFF4A5568)],
                          onTap: () => _launch('https://github.com/swadheen01'),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        _SocialButton(
                          icon: Icons.business_center_rounded,
                          label: 'LinkedIn',
                          colors: const [Color(0xFF0A66C2), Color(0xFF378FE9)],
                          onTap: () => _launch('https://www.linkedin.com/in/swadheen01/'),
                        ),
                        const SizedBox(width: AppDimensions.md),
                        _SocialButton(
                          icon: Icons.thumb_up_rounded,
                          label: 'Facebook',
                          colors: const [Color(0xFF1877F2), Color(0xFF42A5F5)],
                          onTap: () => _launch('https://www.facebook.com/sherlock.sir1/'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
            ],
          ),
        ),
      ),
    );
  }
}

class _EduRow extends StatelessWidget {
  final IconData icon;
  final String name;
  final String detail;

  const _EduRow({required this.icon, required this.name, required this.detail});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
          ),
          child: Icon(icon, color: Colors.white, size: AppDimensions.iconSm),
        ),
        const SizedBox(width: AppDimensions.md),
        Expanded(
          // Institution name bold, the qualification alongside it in a
          // lighter weight, so the two read as one line rather than two
          // competing headings.
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: name,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                TextSpan(
                  text: '  ($detail)',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final List<Color> colors;
  final VoidCallback onTap;

  const _SocialButton({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          boxShadow: [
            BoxShadow(
              color: colors.last.withValues(alpha: 0.45),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Column(
                children: [
                  Icon(icon, color: Colors.white, size: 22),
                  const SizedBox(height: 6),
                  Text(
                    label,
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
