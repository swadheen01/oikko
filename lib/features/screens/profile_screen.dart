import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_gradients.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/locale/locale_service.dart';
import '../../core/services/auth_service.dart';
import '../../models/member.dart';
import '../../widgets/gradient_button.dart';
import '../../widgets/premium_card.dart';
import '../profile/screens/edit_profile_screen.dart';

/// The signed-in member's own profile. Shows the Bengali name as the
/// primary heading with the English name in smaller text beneath it.
class ProfileScreen extends StatelessWidget {
  final Member member;
  const ProfileScreen({super.key, required this.member});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            automaticallyImplyLeading: false,
            backgroundColor: AppColors.primary,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: AppGradients.heroCard),
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 50,
                        backgroundColor: AppColors.surface,
                        backgroundImage: member.photoUrl.isNotEmpty
                            ? NetworkImage(member.photoUrl)
                            : null,
                        child: member.photoUrl.isEmpty
                            ? Text(
                                member.name.isNotEmpty
                                    ? member.name[0].toUpperCase()
                                    : '?',
                                style: AppTextStyles.h1.copyWith(
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      ),
                      const SizedBox(height: AppDimensions.md),
                      Text(
                        member.name,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.h2.copyWith(
                          color: AppColors.surface,
                        ),
                      ),
                      if (member.nameEnglish.isNotEmpty)
                        Text(
                          member.nameEnglish,
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.surface,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        LocaleService.isEnglish
                            ? 'Profile information'
                            : 'প্রোফাইল তথ্য',
                        style: AppTextStyles.h3,
                      ),
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => EditProfileScreen(member: member),
                          ),
                        ),
                        icon: const Icon(Icons.edit_rounded, size: 16),
                        label: Text(AppStrings.editProfile),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  ..._infoTiles(member).expand((tile) sync* {
                    yield tile;
                    yield const SizedBox(height: AppDimensions.md);
                  }),
                  const SizedBox(height: AppDimensions.lg),
                  SizedBox(
                    width: double.infinity,
                    child: GradientButton(
                      label: LocaleService.isEnglish ? 'Log out' : 'লগ আউট',
                      onPressed: () => AuthService().signOut(),
                      icon: Icons.logout_rounded,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _infoTiles(Member member) {
    final entries = <_ProfileInfoTile>[
      _ProfileInfoTile(
        label: LocaleService.isEnglish ? 'Designation' : 'পদবী',
        value: member.designation,
        icon: Icons.badge_rounded,
      ),
      _ProfileInfoTile(
        label: LocaleService.isEnglish ? 'School' : 'স্কুল',
        value: member.schoolName,
        icon: Icons.school_rounded,
      ),
      _ProfileInfoTile(
        label: LocaleService.isEnglish ? 'Qualification' : 'শিক্ষাগত যোগ্যতা',
        value: member.qualification,
        icon: Icons.workspace_premium_rounded,
      ),
      _ProfileInfoTile(
        label: LocaleService.isEnglish ? 'Blood group' : 'রক্তের গ্রুপ',
        value: member.bloodGroup,
        icon: Icons.bloodtype_rounded,
      ),
      _ProfileInfoTile(
        label: LocaleService.isEnglish ? 'Phone' : 'ফোন',
        value: member.phone,
        icon: Icons.phone_rounded,
      ),
      _ProfileInfoTile(
        label: LocaleService.isEnglish ? 'Email' : 'ইমেইল',
        value: member.email,
        icon: Icons.email_rounded,
      ),
    ];
    return entries.where((tile) => tile.value.isNotEmpty).toList();
  }
}

class _ProfileInfoTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ProfileInfoTile({
    required this.label,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: AppDimensions.iconSm,
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.overline),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
