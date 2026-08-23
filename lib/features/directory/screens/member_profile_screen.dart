import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../models/member.dart';
import '../../../widgets/premium_card.dart';

class MemberProfileScreen extends StatelessWidget {
  final Member member;
  const MemberProfileScreen({super.key, required this.member});

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: AppGradients.heroCard),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: AppDimensions.avatarLg / 2,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        backgroundImage: member.photoUrl.isNotEmpty ? NetworkImage(member.photoUrl) : null,
                        child: member.photoUrl.isEmpty
                            ? Text(
                                member.name.isNotEmpty ? member.name.characters.first : '?',
                                style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 36),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(member.name, style: AppTextStyles.h2.copyWith(color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                        member.designation,
                        style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick contact row
                Row(
                  children: [
                    Expanded(
                      child: _ContactButton(
                        icon: Icons.call_rounded,
                        label: LocaleService.isEnglish ? 'Call' : 'কল',
                        color: AppColors.success,
                        onTap: () => _launch('tel:${member.phone}'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: _ContactButton(
                        icon: Icons.sms_rounded,
                        label: LocaleService.isEnglish ? 'SMS' : 'এসএমএস',
                        color: AppColors.primary,
                        onTap: () => _launch('sms:${member.phone}'),
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: _ContactButton(
                        icon: Icons.chat_rounded,
                        label: LocaleService.isEnglish ? 'WhatsApp' : 'হোয়াটসঅ্যাপ',
                        color: const Color(0xFF25D366),
                        onTap: () => _launch('https://wa.me/${member.phone.replaceAll('+', '')}'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.lg),

                _InfoCard(items: [
                  _InfoRow(
                    icon: Icons.school_rounded,
                    label: LocaleService.isEnglish ? 'School' : 'বিদ্যালয়',
                    value: member.schoolName,
                  ),
                  _InfoRow(
                    icon: Icons.badge_rounded,
                    label: LocaleService.isEnglish ? 'Designation' : 'পদবী',
                    value: member.designation,
                  ),
                  _InfoRow(
                    icon: Icons.workspace_premium_rounded,
                    label: LocaleService.isEnglish ? 'Qualification' : 'যোগ্যতা',
                    value: member.qualification,
                  ),
                  _InfoRow(
                    icon: Icons.bloodtype_rounded,
                    label: LocaleService.isEnglish ? 'Blood group' : 'রক্তের গ্রুপ',
                    value: member.bloodGroup,
                  ),
                  _InfoRow(
                    icon: Icons.phone_rounded,
                    label: LocaleService.isEnglish ? 'Phone' : 'ফোন',
                    value: member.phone,
                  ),
                  _InfoRow(
                    icon: Icons.email_rounded,
                    label: LocaleService.isEnglish ? 'Email' : 'ইমেইল',
                    value: member.email,
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ContactButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color),
              const SizedBox(height: 4),
              Text(label, style: AppTextStyles.caption.copyWith(color: color, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Column(
        children: items
            .where((item) => item.value.isNotEmpty)
            .map((item) => item)
            .toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      child: Row(
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
      ),
    );
  }
}
