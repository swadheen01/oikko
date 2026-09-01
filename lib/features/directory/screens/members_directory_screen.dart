import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/admin_session.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/designation_rank.dart';
import '../../../models/member.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../widgets/member_card.dart';
import '../widgets/school_filter_field.dart';
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
  // Cached once (see HomeScreen): a per-build stream makes StreamBuilder flash
  // back to empty and resets scroll on every rebuild.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream =
      _firestoreService.watchAllMembers();
  final _searchController = TextEditingController();
  String _query = '';
  String? _bloodGroupFilter;
  String? _schoolFilter;

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
      final matchesSchool = _schoolFilter == null || m.schoolName.trim() == _schoolFilter;
      return matchesQuery && matchesBlood && matchesSchool && m.isApproved;
    }).toList();

    // By seniority (head teacher first), not the alphabetical order the
    // Firestore query returns.
    result.sort((a, b) => DesignationRank.compare(
          a.designation, a.name, b.designation, b.name,
        ));
    return result;
  }

  /// School -> approved-member count, for the picker.
  static Map<String, int> _schoolCounts(List<Member> members) {
    final counts = <String, int>{};
    for (final m in members) {
      if (!m.isApproved) continue;
      final s = m.schoolName.trim();
      if (s.isEmpty) continue;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  List<Widget> _schoolSlivers(BuildContext context, List<Member> members) {
    final groups = DesignationRank.groupBySchool<Member>(
      members,
      school: (m) => m.schoolName,
      designation: (m) => m.designation,
      name: (m) => m.name,
      noSchool: LocaleService.isEnglish ? 'Other' : 'অন্যান্য',
    );

    return [
      for (final entry in groups) ...[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.lg, AppDimensions.md, AppDimensions.lg, AppDimensions.sm,
          ),
          sliver: SliverToBoxAdapter(
            child: _SchoolHeader(school: entry.key, count: entry.value.length),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                child: MemberCard(
                  member: entry.value[index],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => MemberProfileScreen(member: entry.value[index]),
                    ),
                  ),
                ),
              ),
              childCount: entry.value.length,
            ),
          ),
        ),
      ],
      const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.xl)),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _membersStream,
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

          // Exclude the super admin's stray member doc (it isn't a real
          // teacher) so counts here match the home page.
          final all = (snapshot.data?.docs ?? [])
              .map(Member.fromDoc)
              .where((m) => !AdminSession.isSuperAdminEmail(m.email))
              .toList();
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
                  child: SchoolFilterField(
                    // Counts come from the whole roster, not the filtered
                    // list, so the sheet still shows every school once one
                    // is already picked.
                    counts: _schoolCounts(all),
                    // Real member total, so the "All schools" tile counts
                    // members with no school assigned too.
                    total: all.where((m) => m.isApproved).length,
                    selected: _schoolFilter,
                    onChanged: (s) => setState(() => _schoolFilter = s),
                  ),
                ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.sm)),
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
                              iconColor: AppColors.danger,
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
                // Grouped by school rather than one flat list: with 400+
                // members across 27 schools, a single alphabetical run is
                // unusable — you look for "who teaches at X", not for a
                // position in a 400-row list.
                ..._schoolSlivers(context, filtered),
            ],
          );
        },
      ),
    );
  }
}

/// Section heading for one school, with its staff count.
class _SchoolHeader extends StatelessWidget {
  final String school;
  final int count;

  const _SchoolHeader({required this.school, required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.md, vertical: 10,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withValues(alpha: 0.18),
            AppColors.primary.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border(
          left: BorderSide(color: AppColors.primary, width: 3),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.school_rounded, size: 16, color: AppColors.primary),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Text(
              school,
              style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: AppDimensions.sm),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            ),
            child: Text(
              '$count',
              style: AppTextStyles.caption.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  /// Tint for the leading icon when unselected — gives the blood-group
  /// chips a red droplet so they read as "blood" at a glance.
  final Color? iconColor;

  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
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
            Icon(icon, size: 14, color: isSelected ? AppColors.textOnPrimary : (iconColor ?? AppColors.textSecondary)),
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
