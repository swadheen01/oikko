import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../core/services/firestore_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../core/constants/app_dimensions.dart';
import '../../core/constants/app_strings.dart';
import '../../models/member.dart';
import '../../widgets/app_drawer.dart';
import '../../widgets/app_logo.dart';
import 'screens/home_screen.dart';
import '../directory/screens/members_directory_screen.dart';
import '../finance/screens/finance_dashboard_screen.dart';
import '../screens/profile_screen.dart';
import '../notices/screens/notices_screen.dart';
import '../polls/screens/polls_screen.dart';

/// Bottom-navigation shell tying together the feature screens built so
/// far. Tabs shown depend on role — admin sees an extra "Admin" tab
/// (added once the admin panel is built). Also hosts the persistent top
/// bar (hamburger menu + wordmark + profile shortcut) shown above every
/// tab, and the settings drawer opened from it.
class HomeShell extends StatefulWidget {
  final Member member;

  /// False when this account isn't attached to a member record yet. The
  /// app stays fully usable; only the finance tab has nothing real to show.
  final bool isLinked;

  const HomeShell({super.key, required this.member, this.isLinked = true});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _currentIndex = 0;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _firestoreService = FirestoreService();

  /// Tab indices — used both to route there and to know when to clear that
  /// tab's red badge.
  static const _noticesIndex = 3;
  static const _pollsIndex = 4;

  /// Live feed of this member's private notifications; the count of unread
  /// ones drives the red badge on the Notices tab. Null for accounts with no
  /// member record (nothing to notify).
  late final Stream<QuerySnapshot<Map<String, dynamic>>>? _inboxStream =
      widget.member.id.isEmpty
          ? null
          : _firestoreService.watchMemberNotifications(widget.member.id);

  // Broadcast feeds — a new notice or poll (created after the member last
  // opened that tab) shows a red badge on its tab, the same way the personal
  // inbox does. Cached once (see HomeScreen) so they don't flicker on rebuild.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _noticesStream =
      _firestoreService.watchAllNotices();
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _pollsStream =
      _firestoreService.watchAllPolls();

  // Baseline for "new since last seen". Seeded from the persisted marker so a
  // badge survives an app restart, then bumped to now (and persisted) when the
  // tab is opened. Falls back to app-open time for a member who's never opened
  // it, so old items don't all show as new on first run.
  late DateTime _seenNoticeAt = widget.member.lastSeenNoticeAt ?? DateTime.now();
  late DateTime _seenPollAt = widget.member.lastSeenPollAt ?? DateTime.now();

  int _unreadInbox(QuerySnapshot<Map<String, dynamic>>? snap) =>
      (snap?.docs ?? const []).where((d) => d.data()['read'] != true).length;

  /// Number of docs in [snap] created strictly after [since] — the count of
  /// notices / polls the member hasn't seen yet.
  int _countNewer(QuerySnapshot<Map<String, dynamic>>? snap, DateTime since) {
    return (snap?.docs ?? const []).where((d) {
      final ts = d.data()['createdAt'] as Timestamp?;
      return ts != null && ts.toDate().isAfter(since);
    }).length;
  }

  void _onSelectTab(int index) {
    setState(() {
      _currentIndex = index;
      // Opening the tab clears its badge immediately; the persisted marker
      // below keeps it cleared across restarts.
      if (index == _noticesIndex) _seenNoticeAt = DateTime.now();
      if (index == _pollsIndex) _seenPollAt = DateTime.now();
    });
    if (index == _noticesIndex && widget.member.id.isNotEmpty) {
      _firestoreService.markMemberNotificationsRead(widget.member.id);
      _firestoreService.markNoticesSeen(widget.member.id);
    }
    if (index == _pollsIndex && widget.member.id.isNotEmpty) {
      _firestoreService.markPollsSeen(widget.member.id);
    }
  }

  // A getter (not `late final`) so it always reflects the latest `widget.member`
  // — AuthWrapper streams live Firestore updates into a new Member each time
  // the doc changes (e.g. right after Edit Profile saves), and a cached list
  // would keep showing the stale ProfileScreen instance otherwise.
  // Welfare was removed from the tabs on both shells: the member-facing
  // request page and the admin approval page only made sense as a pair,
  // and the feature wasn't in use. The screens still exist under
  // features/welfare if it's ever brought back.
  List<Widget> get _screens => [
    HomeScreen(member: widget.member, isLinked: widget.isLinked),
    FinanceDashboardScreen(
      memberId: widget.member.id,
      memberName: widget.member.name,
      memberCode: widget.member.memberCode,
      isLinked: widget.isLinked,
    ),
    const MembersDirectoryScreen(),
    NoticesScreen(memberId: widget.member.id),
    PollsScreen(currentUserUid: FirebaseAuth.instance.currentUser?.uid),
    ProfileScreen(member: widget.member),
  ];

  // A getter (not `late final`): the labels come from AppStrings, which
  // switch on the current language. Cached once, they'd keep the language
  // that was active when the shell first built — which is exactly why the
  // tab labels used to stay put after switching language.
  List<_NavItem> get _navItems => [
    _NavItem(icon: Icons.home_rounded, label: AppStrings.home, color: AppColors.primary),
    _NavItem(
      icon: Icons.account_balance_wallet_rounded,
      label: AppStrings.finance,
      color: AppColors.accentTeal,
    ),
    _NavItem(icon: Icons.groups_rounded, label: AppStrings.members, color: AppColors.accentRose),
    _NavItem(icon: Icons.notifications_rounded, label: AppStrings.notices, color: AppColors.accentAmber),
    _NavItem(icon: Icons.poll_rounded, label: AppStrings.polls, color: AppColors.accentViolet),
    _NavItem(icon: Icons.person_rounded, label: AppStrings.profile, color: AppColors.accentCyan),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      drawer: AppDrawer(
        member: widget.member,
        currentIndex: _currentIndex,
        onSelectTab: _onSelectTab,
        navItems: _navItems
            .map((item) => DrawerNavItem(icon: item.icon, label: item.label, color: item.color))
            .toList(),
      ),
      body: Column(
        children: [
          _TopBar(
            member: widget.member,
            onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
            onAvatarTap: () => _onSelectTab(_navItems.length - 1),
          ),
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
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _inboxStream,
              builder: (context, inboxSnap) {
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _noticesStream,
                builder: (context, noticesSnap) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _pollsStream,
                  builder: (context, pollsSnap) {
                // Badge on Notices = unread personal inbox items + new
                // broadcast notices; badge on Polls = new polls. Each is
                // hidden while its own tab is open (it clears on entry).
                final noticesBadge = _currentIndex == _noticesIndex
                    ? 0
                    : _unreadInbox(inboxSnap.data) +
                        _countNewer(noticesSnap.data, _seenNoticeAt);
                final pollsBadge = _currentIndex == _pollsIndex
                    ? 0
                    : _countNewer(pollsSnap.data, _seenPollAt);
                return Row(
              children: List.generate(_navItems.length, (index) {
                final item = _navItems[index];
                final isSelected = index == _currentIndex;
                final badge = index == _noticesIndex
                    ? noticesBadge
                    : (index == _pollsIndex ? pollsBadge : 0);
                return Expanded(
                  child: InkWell(
                    onTap: () => _onSelectTab(index),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
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
                            if (badge > 0)
                              Positioned(
                                top: -4,
                                right: -3,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                  constraints: const BoxConstraints(minWidth: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger,
                                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                                    border: Border.all(color: AppColors.glassChrome, width: 1.5),
                                  ),
                                  child: Text(
                                    badge > 9 ? '9+' : '$badge',
                                    textAlign: TextAlign.center,
                                    style: AppTextStyles.caption.copyWith(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 9,
                                    ),
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
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
                );
                  },
                );
                },
              );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final Member member;
  final VoidCallback onMenuTap;
  final VoidCallback onAvatarTap;

  const _TopBar({required this.member, required this.onMenuTap, required this.onAvatarTap});

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
              Text(AppStrings.appName, style: AppTextStyles.h3),
              const Spacer(),
              GestureDetector(
                onTap: onAvatarTap,
                child: CircleAvatar(
                  radius: 17,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                  backgroundImage: member.photoUrl.isNotEmpty ? NetworkImage(member.photoUrl) : null,
                  child: member.photoUrl.isEmpty
                      ? Text(
                          member.name.isNotEmpty ? member.name.characters.first : '?',
                          style: AppTextStyles.caption.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      : null,
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  final Color color;
  const _NavItem({required this.icon, required this.label, required this.color});
}
