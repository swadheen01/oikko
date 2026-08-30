import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../core/locale/locale_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/member.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_logo.dart';
import '../finance/screens/add_expense_screen.dart';
import '../finance/screens/add_payment_screen.dart';
import '../finance/screens/finance_dashboard_screen.dart';
import '../home/screens/home_screen.dart';
import '../notices/screens/notice_create_screen.dart';
import '../notices/screens/notices_screen.dart';
import '../polls/screens/polls_screen.dart';
import '../screens/profile_screen.dart';
import 'screens/add_member_screen.dart';
import 'screens/link_requests_screen.dart';
import 'screens/members_admin_screen.dart';
import 'widgets/admin_speed_dial_fab.dart';

/// Admin panel shell with tabs for managing notices, welfare requests, and
/// polls, plus a Profile tab (account info + logout — previously missing
/// entirely for admins) and the same hamburger menu / drawer every member
/// screen has.
class AdminShell extends StatefulWidget {
  final Member member;
  const AdminShell({super.key, required this.member});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _firestoreService = FirestoreService();

  // Index into _navItems/_screens that the pending-link-requests badge
  // attaches to.
  static const _linkRequestsIndex = 5;

  // The members roster fills the screen with a scrolling list, so the
  // floating "+" is hidden there — its actions are offered as buttons in
  // that screen's own header instead.
  static const _membersIndex = 2;

  // Getter (not `late final`) so ProfileScreen always reflects the latest
  // `widget.member` — see the same fix/rationale in HomeShell.
  List<Widget> get _screens => [
    HomeScreen(member: widget.member, showSyncBanner: false),
    const FinanceDashboardScreen(isAdmin: true),
    const MembersAdminScreen(),
    const NoticeCreateScreen(),
    // The Poll tab lists every poll (so admins can stop or delete them,
    // and see live results) with a "Create new poll" button up top.
    PollsScreen(
      currentUserUid: FirebaseAuth.instance.currentUser?.uid,
      showCreateButton: true,
    ),
    const LinkRequestsScreen(),
    ProfileScreen(member: widget.member),
  ];

  // A getter (not `late final`) so the labels re-read AppStrings on each
  // build and follow the current language — see the same fix in HomeShell.
  List<_AdminNavItem> get _navItems => [
    _AdminNavItem(
      icon: Icons.home_rounded,
      label: AppStrings.home,
      color: AppColors.primary,
    ),
    _AdminNavItem(
      icon: Icons.account_balance_wallet_rounded,
      label: AppStrings.finance,
      color: AppColors.accentTeal,
    ),
    _AdminNavItem(
      icon: Icons.groups_rounded,
      label: AppStrings.members,
      color: AppColors.accentAmber,
    ),
    _AdminNavItem(
      icon: Icons.notifications_rounded,
      label: LocaleService.isEnglish ? 'Notice' : 'নোটিশ তৈরি',
      color: AppColors.accentAmber,
    ),
    _AdminNavItem(
      icon: Icons.poll_rounded,
      label: LocaleService.isEnglish ? 'Poll' : 'পোল তৈরি',
      color: AppColors.accentViolet,
    ),
    _AdminNavItem(
      icon: Icons.link_rounded,
      label: AppStrings.linkRequests,
      color: AppColors.accentRose,
    ),
    _AdminNavItem(
      icon: Icons.person_rounded,
      label: AppStrings.profile,
      color: AppColors.accentCyan,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestoreService.watchPendingLinkRequests(),
      builder: (context, snapshot) {
        final pendingCount = snapshot.data?.docs.length ?? 0;
        return _buildScaffold(context, pendingCount);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, int pendingCount) {
    return Scaffold(
      key: _scaffoldKey,
      floatingActionButton:
          _currentIndex == _membersIndex ? null : const AdminSpeedDialFab(),
      drawer: AppDrawer(
        member: widget.member,
        currentIndex: _currentIndex,
        onSelectTab: (index) => setState(() => _currentIndex = index),
        navItems: List.generate(_navItems.length, (index) {
          final item = _navItems[index];
          return DrawerNavItem(
            icon: item.icon,
            label: item.label,
            color: item.color,
            badgeCount: index == _linkRequestsIndex ? pendingCount : 0,
          );
        }),
        // Members isn't listed here — it's a tab now, and the drawer
        // already mirrors every tab above.
        // Same order as the "+" speed dial, so the two don't disagree:
        // payments and expenses first, adding a member below them.
        actionItems: [
          DrawerActionItem(
            icon: Icons.payments_rounded,
            label: AppStrings.addPayment,
            color: AppColors.accentTeal,
            builder: (_) => const AddPaymentScreen(),
          ),
          DrawerActionItem(
            icon: Icons.receipt_long_rounded,
            label: AppStrings.addExpense,
            color: AppColors.danger,
            builder: (_) => const AddExpenseScreen(),
          ),
          DrawerActionItem(
            icon: Icons.person_add_rounded,
            label: AppStrings.addMember,
            color: AppColors.accentViolet,
            builder: (_) => const AddMemberScreen(),
          ),
          // The admin's Notice tab only creates them; this is where posted
          // notices can be reviewed and removed.
          DrawerActionItem(
            icon: Icons.campaign_rounded,
            label: AppStrings.notices,
            color: AppColors.accentAmber,
            builder: (_) => NoticesScreen(isAdmin: true, memberId: widget.member.id),
          ),
        ],
      ),
      body: Column(
        children: [
          _AdminTopBar(onMenuTap: () => _scaffoldKey.currentState?.openDrawer()),
          const _AdminPermissionWarning(),
          Expanded(child: IndexedStack(index: _currentIndex, children: _screens)),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: AppColors.glassChrome,
          border: Border(top: BorderSide(color: AppColors.glassBorder)),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowAmbient,
              blurRadius: 24,
              offset: const Offset(0, -8),
            ),
            BoxShadow(
              color: AppColors.shadowContact,
              blurRadius: 4,
              offset: const Offset(0, -1),
            ),
          ],
        ),
        child: SafeArea(
          child: SizedBox(
            height: 64,
            child: Row(
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = index == _currentIndex;
                return Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _currentIndex = index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              // Tight horizontal padding: seven tabs have to
                              // share the width of a phone screen.
                              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                              decoration: BoxDecoration(
                                color: isSelected ? item.color.withValues(alpha: 0.14) : Colors.transparent,
                                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                              ),
                              child: Icon(
                                item.icon,
                                size: 22,
                                color: isSelected
                                    ? item.color
                                    : AppColors.textSecondary,
                              ),
                            ),
                            if (index == _linkRequestsIndex && pendingCount > 0)
                              Positioned(
                                top: -2,
                                right: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                                  child: Text(
                                    pendingCount > 9 ? '9+' : '$pendingCount',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w700),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: Text(
                            item.label,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTextStyles.caption.copyWith(
                              color: isSelected
                                  ? item.color
                                  : AppColors.textSecondary,
                              fontWeight: isSelected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              fontSize: 9,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}

class _AdminTopBar extends StatelessWidget {
  final VoidCallback onMenuTap;
  const _AdminTopBar({required this.onMenuTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.glassChrome,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.glassBorder)),
          ),
          child: Row(
            children: [
              IconButton(
                onPressed: onMenuTap,
                icon: Icon(Icons.menu_rounded, color: AppColors.textPrimary),
                tooltip: AppStrings.menu,
              ),
              const AppLogo(size: 30),
              const SizedBox(width: 8),
              Text('${AppStrings.appName} · ${AppStrings.admin}', style: AppTextStyles.h3),
            ],
          ),
        ),
      ),
    );
  }
}

/// Surfaces the one setup step that silently breaks every admin action —
/// a missing `admins/{uid}` document. Without this, the only symptom is a
/// permission-denied on each feature the admin happens to try, which reads
/// like several unrelated bugs rather than one missing document.
class _AdminPermissionWarning extends StatefulWidget {
  const _AdminPermissionWarning();

  @override
  State<_AdminPermissionWarning> createState() => _AdminPermissionWarningState();
}

class _AdminPermissionWarningState extends State<_AdminPermissionWarning> {
  bool _ok = true;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final present = await FirestoreService().hasAdminMarker(uid);
    if (mounted) setState(() => _ok = present);
  }

  @override
  Widget build(BuildContext context) {
    if (_ok) return const SizedBox.shrink();

    final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Container(
      width: double.infinity,
      color: AppColors.danger.withValues(alpha: 0.12),
      padding: const EdgeInsets.all(AppDimensions.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 20),
          const SizedBox(width: AppDimensions.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  LocaleService.isEnglish
                      ? 'Admin permissions are not set up'
                      : 'অ্যাডমিন অনুমতি সেট করা হয়নি',
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  LocaleService.isEnglish
                      ? 'Publishing notices, adding payments and approving requests will all fail until a document with this ID is created in the "admins" collection in Firebase:'
                      : 'ফায়ারবেসের "admins" কালেকশনে এই আইডি দিয়ে ডকুমেন্ট তৈরি না করা পর্যন্ত নোটিশ, পেমেন্ট ও অনুমোদন কাজ করবে না:',
                  style: AppTextStyles.caption,
                ),
                const SizedBox(height: 4),
                SelectableText(
                  uid,
                  style: AppTextStyles.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
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

class _AdminNavItem {
  final IconData icon;
  final String label;
  final Color color;

  const _AdminNavItem({
    required this.icon,
    required this.label,
    required this.color,
  });
}
