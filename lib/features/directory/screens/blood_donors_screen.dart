import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/designation_rank.dart';
import '../../../models/member.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../widgets/member_card.dart';
import 'member_profile_screen.dart';

/// Blood-group finder, reached from the drawer. Pick a blood group and the
/// members who have it are listed (name, school, blood badge, profile on
/// tap) — so a donor can be found fast in an emergency.
class BloodDonorsScreen extends StatefulWidget {
  const BloodDonorsScreen({super.key});

  @override
  State<BloodDonorsScreen> createState() => _BloodDonorsScreenState();
}

class _BloodDonorsScreenState extends State<BloodDonorsScreen> {
  final _firestoreService = FirestoreService();
  // Cached once (see HomeScreen): a per-build stream makes StreamBuilder flash
  // back to empty and resets scroll on every rebuild.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream =
      _firestoreService.watchAllMembers();
  String? _group;

  static const _groups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  List<Member> _matches(List<Member> members) {
    final result = members
        .where((m) => m.isApproved && m.bloodGroup.trim() == _group)
        .toList();
    result.sort((a, b) => DesignationRank.compare(
          a.designation, a.name, b.designation, b.name,
        ));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;

    return GradientScaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _membersStream,
        builder: (context, snapshot) {
          final all = (snapshot.data?.docs ?? []).map(Member.fromDoc).toList();
          final matches = _group == null ? <Member>[] : _matches(all);

          // Count of donors per group, for the chips.
          final counts = <String, int>{};
          for (final m in all) {
            if (!m.isApproved) continue;
            final g = m.bloodGroup.trim();
            if (g.isEmpty) continue;
            counts[g] = (counts[g] ?? 0) + 1;
          }

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.lg, AppDimensions.lg, AppDimensions.lg, AppDimensions.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      if (Navigator.of(context).canPop()) ...[
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                        ),
                        const SizedBox(width: AppDimensions.sm),
                      ],
                      Icon(Icons.bloodtype_rounded, color: AppColors.danger, size: 26),
                      const SizedBox(width: AppDimensions.sm),
                      Text(
                        isEn ? 'Blood donors' : 'রক্তদাতা',
                        style: AppTextStyles.h1,
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.lg, 0, AppDimensions.lg, AppDimensions.md,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(
                    isEn
                        ? 'Choose a blood group to see who can donate.'
                        : 'কোন রক্তের গ্রুপ দরকার তা বেছে নিন, কারা রক্ত দিতে পারবেন দেখুন।',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
                sliver: SliverToBoxAdapter(
                  child: Wrap(
                    spacing: AppDimensions.sm,
                    runSpacing: AppDimensions.sm,
                    children: _groups.map((g) {
                      final selected = _group == g;
                      final count = counts[g] ?? 0;
                      return _BloodChip(
                        group: g,
                        count: count,
                        selected: selected,
                        onTap: () => setState(
                          () => _group = selected ? null : g,
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.md)),

              if (_group == null)
                SliverToBoxAdapter(
                  child: _Hint(
                    icon: Icons.touch_app_rounded,
                    text: isEn
                        ? 'Tap a blood group above.'
                        : 'উপরে একটি রক্তের গ্রুপে চাপ দিন।',
                  ),
                )
              else if (matches.isEmpty)
                SliverToBoxAdapter(
                  child: _Hint(
                    icon: Icons.person_off_rounded,
                    text: isEn
                        ? 'No members with blood group $_group yet.'
                        : '$_group গ্রুপের কোনো সদস্য পাওয়া যায়নি।',
                  ),
                )
              else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg, 0, AppDimensions.lg, AppDimensions.sm,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      isEn
                          ? '${matches.length} donor${matches.length == 1 ? '' : 's'} with $_group'
                          : '$_group গ্রুপের ${matches.length} জন সদস্য',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg, 0, AppDimensions.lg, AppDimensions.xl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                        child: MemberCard(
                          member: matches[index],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MemberProfileScreen(member: matches[index]),
                            ),
                          ),
                        ),
                      ),
                      childCount: matches.length,
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// A blood-group pill with its donor count. Red so it clearly reads as blood.
class _BloodChip extends StatelessWidget {
  final String group;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _BloodChip({
    required this.group,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? AppColors.danger : AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          border: Border.all(
            color: selected ? AppColors.danger : AppColors.danger.withValues(alpha: 0.4),
          ),
          boxShadow: selected
              ? [BoxShadow(color: AppColors.danger.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bloodtype_rounded,
              size: 16,
              color: selected ? Colors.white : AppColors.danger,
            ),
            const SizedBox(width: 5),
            Text(
              group,
              style: AppTextStyles.bodyMedium.copyWith(
                color: selected ? Colors.white : AppColors.danger,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
              decoration: BoxDecoration(
                color: selected ? Colors.white.withValues(alpha: 0.25) : AppColors.danger.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
              child: Text(
                '$count',
                style: AppTextStyles.caption.copyWith(
                  color: selected ? Colors.white : AppColors.danger,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Hint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.xl),
      child: Column(
        children: [
          Icon(icon, size: 40, color: AppColors.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(height: AppDimensions.sm),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}
