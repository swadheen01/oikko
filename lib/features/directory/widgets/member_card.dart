import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../models/member.dart';
import '../../../widgets/premium_card.dart';

class MemberCard extends StatelessWidget {
  final Member member;
  final VoidCallback onTap;

  const MemberCard({super.key, required this.member, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      onTap: onTap,
      child: Row(
        children: [
          _Avatar(name: member.name, photoUrl: member.photoUrl),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.name, style: AppTextStyles.h3),
                const SizedBox(height: 2),
                Text(
                  member.schoolName.isNotEmpty ? member.schoolName : member.designation,
                  style: AppTextStyles.bodyMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (member.bloodGroup.isNotEmpty) _BloodBadge(group: member.bloodGroup),
          const SizedBox(width: 4),
          Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String photoUrl;

  const _Avatar({required this.name, required this.photoUrl});

  // A getter, not a static const: the colours change with the theme, so
  // caching this once would freeze it to whichever theme loaded first.
  static LinearGradient get _avatarGradient => LinearGradient(
        colors: [AppColors.primary, AppColors.secondary],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      );

  @override
  Widget build(BuildContext context) {
    if (photoUrl.isNotEmpty) {
      return CircleAvatar(radius: AppDimensions.avatarSm / 2, backgroundImage: NetworkImage(photoUrl));
    }
    final initial = name.isNotEmpty ? name.characters.first : '?';
    return Container(
      width: AppDimensions.avatarSm,
      height: AppDimensions.avatarSm,
      decoration: BoxDecoration(gradient: _avatarGradient, shape: BoxShape.circle),
      alignment: Alignment.center,
      child: Text(
        initial,
        style: AppTextStyles.h3.copyWith(color: AppColors.textOnPrimary),
      ),
    );
  }
}

class _BloodBadge extends StatelessWidget {
  final String group;
  const _BloodBadge({required this.group});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
      ),
      child: Text(
        group,
        style: AppTextStyles.caption.copyWith(color: AppColors.danger, fontWeight: FontWeight.w700),
      ),
    );
  }
}
