import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';
import 'committee_screen.dart';

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
                      AppStrings.associationShortName,
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      isEn ? 'Baniyachong Upazila Branch, Habiganj' : 'বানিয়াচং উপজেলা শাখা, হবিগঞ্জ',
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontWeight: FontWeight.w600,
                      ),
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
                      isEn ? 'Office bearers' : 'কার্যনির্বাহী পরিষদ',
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    // Live from Firestore so admin edits show here too; falls
                    // back to the built-in defaults when nothing's overridden.
                    StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: watchCommittee(),
                      builder: (context, snapshot) {
                        final members = mergeCommittee(snapshot.data);
                        return Column(
                          children: [
                            CommitteeMemberTile(member: members[0]),
                            const SizedBox(height: AppDimensions.md),
                            CommitteeMemberTile(member: members[1]),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: AppDimensions.md),
                    // Opens the whole elected committee (these two plus the
                    // rest) with photos.
                    _FullListButton(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CommitteeScreen()),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    Text(
                      isEn ? 'Contact' : 'যোগাযোগ',
                      style: AppTextStyles.h3,
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    _ContactRow(
                      icon: Icons.person_rounded,
                      label: isEn ? 'General Secretary' : 'সাধারণ সম্পাদক',
                      value: isEn ? 'Mohammad Mofazzal Hossain' : 'মোহাম্মদ মোফাজ্জল হোসেন',
                      subtitle: isEn ? 'Baniyachong Adarsha High School' : 'বানিয়াচং আদর্শ উচ্চ বিদ্যালয়',
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


/// "See the full committee list" button on the About page.
class _FullListButton extends StatelessWidget {
  final VoidCallback onTap;
  const _FullListButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;
    return Material(
      color: AppColors.primary.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md, vertical: 13,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.groups_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: AppDimensions.sm),
              Text(
                isEn ? 'Full committee list' : 'সম্পূর্ণ তালিকা',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 16, color: AppColors.primary),
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

  /// Optional small line under the name — used for the office bearer's school.
  final String? subtitle;

  const _ContactRow({
    required this.icon,
    required this.label,
    required this.value,
    this.subtitle,
  });

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
              if (subtitle != null && subtitle!.isNotEmpty)
                Text(
                  subtitle!,
                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
