import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/designation_rank.dart';
import '../../../models/member.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../widgets/member_card.dart';
import 'member_profile_screen.dart';

/// The member-facing roster: every approved member, searchable and
/// filterable by blood group. Read-only — payment amounts are never shown
/// here, only the shared profile fields (name, school, designation, phone,
/// blood group), matching the privacy split in the security rules.
///
/// The admin equivalent is MembersAdminScreen, which adds Member IDs,
/// export and delete on top of the same list.
class MembersDirectoryScreen extends StatefulWidget {
  const MembersDirectoryScreen({super.key});

  @override
  State<MembersDirectoryScreen> createState() => _MembersDirectoryScreenState();
}

class _MembersDirectoryScreenState extends State<MembersDirectoryScreen> {
  final _firestoreService = FirestoreService();
  final _searchController = TextEditingController();
  String _query = '';
  String? _bloodGroupFilter;

  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Member> _filter(List<Member> members) {
    final q = _query.trim().toLowerCase();
    final result = members.where((m) {
      final matchesQuery = q.isEmpty ||
          m.name.toLowerCase().contains(q) ||
          m.nameEnglish.toLowerCase().contains(q) ||
          m.schoolName.toLowerCase().contains(q);
      final matchesBlood = _bloodGroupFilter == null || m.bloodGroup == _bloodGroupFilter;
      return matchesQuery && matchesBlood && m.isApproved;
    }).toList();

    // By seniority (head teacher first), not the alphabetical order the
    // Firestore query returns.
    result.sort((a, b) => DesignationRank.compare(
          a.designation, a.name, b.designation, b.name,
        ));
    return result;
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _firestoreService.watchAllMembers(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: Text(
                  '${AppStrings.errorGeneric}\n${snapshot.error}',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger),
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final all = (snapshot.data?.docs ?? []).map(Member.fromDoc).toList();
          final filtered = _filter(all);

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.lg, AppDimensions.lg, AppDimensions.lg, AppDimensions.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Row(
                    children: [
                      Text(AppStrings.allMembers, style: AppTextStyles.h1),
                      const Spacer(),
                      Text(
                        LocaleService.isEnglish
                            ? '${filtered.length}'
                            : '${filtered.length} জন',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
                sliver: SliverToBoxAdapter(
                  child: TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: LocaleService.isEnglish
                          ? 'Search by name or school'
                          : 'নাম বা বিদ্যালয় দিয়ে খুঁজুন',
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                    ),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.sm)),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
                    children: [
                      _FilterChip(
                        label: LocaleService.isEnglish ? 'All' : 'সবাই',
                        icon: Icons.groups_rounded,
                        isSelected: _bloodGroupFilter == null,
                        onTap: () => setState(() => _bloodGroupFilter = null),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      ..._bloodGroups.map((bg) => Padding(
                            padding: const EdgeInsets.only(right: AppDimensions.sm),
                            child: _FilterChip(
                              label: bg,
                              icon: Icons.bloodtype_rounded,
                              isSelected: _bloodGroupFilter == bg,
                              onTap: () => setState(() => _bloodGroupFilter = bg),
                            ),
                          )),
                    ],
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.sm)),
              if (snapshot.connectionState == ConnectionState.waiting)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(AppDimensions.xl),
                    child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                  ),
                )
              else if (filtered.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.xl),
                    child: Center(
                      child: Text(
                        LocaleService.isEnglish ? 'No results found' : 'কোনো ফলাফল পাওয়া যায়নি',
                        style: AppTextStyles.bodyMedium,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg, 0, AppDimensions.lg, AppDimensions.xl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                        child: MemberCard(
                          member: filtered[index],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => MemberProfileScreen(member: filtered[index]),
                            ),
                          ),
                        ),
                      ),
                      childCount: filtered.length,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
          border: Border.all(color: isSelected ? AppColors.primary : AppColors.border),
          boxShadow: isSelected
              ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 4))]
              : [],
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                color: isSelected ? AppColors.textOnPrimary : AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
