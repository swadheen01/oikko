import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/designation_rank.dart';
import '../../../models/member.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../about/screens/about_screen.dart';
import '../../account_linking/widgets/sync_payment_card.dart';
import '../../directory/widgets/member_card.dart';
import '../../directory/screens/member_profile_screen.dart';

/// The app's landing page (first tab): a condensed "about the association"
/// card, a "sync payment info" banner (only shown until the member's
/// account is connected to an admin-issued Member ID), followed by the
/// searchable/filterable member directory. This is what a member sees
/// immediately after logging in.
class HomeScreen extends StatefulWidget {
  final Member member;

  /// Admins manage Member IDs rather than needing one themselves, so the
  /// "connect your Member ID to sync payments" prompt is meaningless in
  /// the admin panel even though their own record has no memberCode.
  final bool showSyncBanner;

  /// Whether this account is attached to a member record. Unlinked users
  /// browse the app normally; the sync prompt stays visible for them until
  /// an admin approves the link.
  final bool isLinked;

  const HomeScreen({
    super.key,
    required this.member,
    this.showSyncBanner = true,
    this.isLinked = true,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    final result = members.where((m) {
      final matchesQuery = _query.isEmpty ||
          m.name.toLowerCase().contains(_query.toLowerCase()) ||
          m.schoolName.toLowerCase().contains(_query.toLowerCase());
      final matchesBlood = _bloodGroupFilter == null || m.bloodGroup == _bloodGroupFilter;
      return matchesQuery && matchesBlood && m.isApproved;
    }).toList();

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
          final members = (snapshot.data?.docs ?? []).map(Member.fromDoc).toList();
          final approvedCount = members.where((m) => m.isApproved).length;
          final filtered = _filter(members);

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.lg, AppDimensions.lg, AppDimensions.lg, 0,
                ),
                sliver: SliverToBoxAdapter(
                  child: _AboutCard(memberCount: approvedCount),
                ),
              ),
              // Stays put until the account is actually linked — it's the
              // only route from an unlinked account to its payment history.
              if (widget.showSyncBanner &&
                  (!widget.isLinked || widget.member.memberCode.isEmpty))
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg, AppDimensions.lg, AppDimensions.lg, 0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: SyncPaymentCard(
                      currentPhone: widget.member.phone,
                      compact: true,
                    ),
                  ),
                ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.lg, AppDimensions.lg, AppDimensions.lg, AppDimensions.sm,
                ),
                sliver: SliverToBoxAdapter(
                  child: Text(AppStrings.allMembers, style: AppTextStyles.h2),
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
              SliverToBoxAdapter(child: const SizedBox(height: AppDimensions.sm)),
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
              SliverToBoxAdapter(child: const SizedBox(height: AppDimensions.sm)),

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

class _AboutCard extends StatelessWidget {
  final int memberCount;
  const _AboutCard({required this.memberCount});

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.lg),
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.glassSheen,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.groups_rounded, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    AppStrings.about.toUpperCase(),
                    style: AppTextStyles.overline.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                isEn ? 'Baniyachong Upazila Teachers Association' : 'বানিয়াচং উপজেলা শিক্ষক সমিতি',
                style: AppTextStyles.h2.copyWith(color: Colors.white),
              ),
              const SizedBox(height: 6),
              Text(
                isEn
                    ? 'A shared platform for members — directory, dues, welfare fund, and notices.'
                    : 'সদস্যদের জন্য একটি অভিন্ন প্ল্যাটফর্ম — তালিকা, চাঁদা, কল্যাণ তহবিল ও নোটিশ।',
                style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.88)),
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Icon(Icons.people_alt_rounded, size: 16, color: Colors.white.withValues(alpha: 0.85)),
                  const SizedBox(width: 6),
                  Text(
                    isEn ? '$memberCount members' : '$memberCount জন সদস্য',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AboutScreen()),
                    ),
                    child: Row(
                      children: [
                        Text(
                          AppStrings.seeDetails,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(Icons.arrow_forward_rounded, size: 16, color: Colors.white),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
