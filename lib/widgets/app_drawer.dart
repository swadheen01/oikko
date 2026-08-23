import 'package:flutter/material.dart';
import '../core/constants/app_dimensions.dart';
import '../core/constants/app_strings.dart';
import '../core/locale/locale_service.dart';
import '../core/services/auth_service.dart';
import '../core/theme/app_colors.dart';
import '../core/theme/app_gradients.dart';
import '../core/theme/app_text_styles.dart';
import '../core/utils/app_snackbar.dart';
import '../core/theme/theme_service.dart';
import '../features/about/screens/about_screen.dart';
import '../features/about/screens/developer_screen.dart';
import '../features/profile/screens/edit_profile_screen.dart';
import '../models/member.dart';

/// One entry in the drawer's primary navigation list — mirrors a bottom-nav
/// tab, each with its own accent color for the "colorful, not just blue"
/// Facebook-style menu look.
class DrawerNavItem {
  final IconData icon;
  final String label;
  final Color color;
  final int badgeCount;

  const DrawerNavItem({
    required this.icon,
    required this.label,
    required this.color,
    this.badgeCount = 0,
  });
}

/// A drawer entry that opens a pushed route rather than switching tabs —
/// for pages that don't have a bottom-nav tab of their own (e.g. the admin
/// member roster).
class DrawerActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final WidgetBuilder builder;

  const DrawerActionItem({
    required this.icon,
    required this.label,
    required this.color,
    required this.builder,
  });
}

/// The app-wide "hamburger" menu — every page is reachable from here
/// (mirrors the bottom-nav tabs) plus account settings and logout, always
/// available via the top-bar menu button on every screen.
class AppDrawer extends StatelessWidget {
  final Member? member;
  final List<DrawerNavItem> navItems;
  final List<DrawerActionItem> actionItems;
  final int currentIndex;
  final ValueChanged<int>? onSelectTab;

  const AppDrawer({
    super.key,
    this.member,
    this.navItems = const [],
    this.actionItems = const [],
    this.currentIndex = -1,
    this.onSelectTab,
  });

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _Header(member: member),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
                children: [
                  // Only tabs that carry something the bottom bar can't
                  // show — currently a pending-count badge. Mirroring every
                  // tab here just pushed the entries that are *only*
                  // reachable from this menu (Developer, About, settings)
                  // below the fold for no benefit.
                  for (int i = 0; i < navItems.length; i++)
                    if (navItems[i].badgeCount > 0)
                      _DrawerTile(
                        icon: navItems[i].icon,
                        label: navItems[i].label,
                        color: navItems[i].color,
                        badgeCount: navItems[i].badgeCount,
                        selected: i == currentIndex,
                        onTap: () {
                          Navigator.of(context).pop();
                          onSelectTab?.call(i);
                        },
                      ),
                  for (final action in actionItems)
                    _DrawerTile(
                      icon: action.icon,
                      label: action.label,
                      color: action.color,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(MaterialPageRoute(builder: action.builder));
                      },
                    ),
                  if (member != null)
                    _DrawerTile(
                      icon: Icons.edit_rounded,
                      label: AppStrings.editProfile,
                      color: AppColors.accentViolet,
                      onTap: () {
                        Navigator.of(context).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => EditProfileScreen(member: member!)),
                        );
                      },
                    ),
                  _DrawerTile(
                    icon: Icons.info_rounded,
                    label: AppStrings.about,
                    color: AppColors.accentCyan,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const AboutScreen()),
                      );
                    },
                  ),
                  _DrawerTile(
                    icon: Icons.code_rounded,
                    label: AppStrings.developer,
                    color: AppColors.accentTeal,
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const DeveloperScreen()),
                      );
                    },
                  ),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: AppDimensions.sm),
                    child: Divider(color: AppColors.border),
                  ),
                  const _LanguageTile(),
                  const _ThemeTile(),
                  _DrawerTile(
                    icon: Icons.logout_rounded,
                    label: AppStrings.logout,
                    color: AppColors.danger,
                    onTap: () async {
                      Navigator.of(context).pop();
                      await AuthService().signOut();
                      AppSnackbar.success(
                        LocaleService.isEnglish ? 'Logged out' : 'লগ আউট হয়েছে',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final Member? member;
  const _Header({required this.member});

  @override
  Widget build(BuildContext context) {
    final name = member?.name ?? '';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.lg, AppDimensions.lg, AppDimensions.lg, AppDimensions.lg,
      ),
      decoration: BoxDecoration(gradient: AppGradients.primary),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: Colors.white.withValues(alpha: 0.2),
            backgroundImage: (member?.photoUrl.isNotEmpty ?? false)
                ? NetworkImage(member!.photoUrl)
                : null,
            child: (member?.photoUrl.isEmpty ?? true)
                ? Text(
                    name.isNotEmpty ? name.characters.first : '?',
                    style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 28),
                  )
                : null,
          ),
          const SizedBox(height: AppDimensions.sm),
          Text(
            name.isNotEmpty ? name : AppStrings.appName,
            style: AppTextStyles.h3.copyWith(color: Colors.white),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (member != null && member!.schoolName.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              member!.schoolName,
              style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ] else if (member != null) ...[
            const SizedBox(height: 2),
            Text(
              AppStrings.admin,
              style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.85)),
            ),
          ],
        ],
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool selected;
  final int badgeCount;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.selected = false,
    this.badgeCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      selected: selected,
      selectedTileColor: color.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.radiusMd)),
      contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: 2),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        ),
        alignment: Alignment.center,
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(
        label,
        style: AppTextStyles.bodyLarge.copyWith(
          color: selected ? color : AppColors.textPrimary,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
        ),
      ),
      trailing: badgeCount > 0
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.danger,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
              child: Text(
                badgeCount > 99 ? '99+' : '$badgeCount',
                style: AppTextStyles.caption.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}

/// Light/dark switch. Uses a real Switch rather than a tap-to-cycle tile so
/// the current mode is readable at a glance without tapping it.
class _ThemeTile extends StatelessWidget {
  const _ThemeTile();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: ThemeService.notifier,
      builder: (context, mode, _) {
        final isDark = mode == AppThemeMode.dark;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.lg, vertical: 2,
          ),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accentViolet.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(
              isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              color: AppColors.accentViolet,
              size: 20,
            ),
          ),
          title: Text(
            isDark
                ? (LocaleService.isEnglish ? 'Dark mode' : 'ডার্ক মোড')
                : (LocaleService.isEnglish ? 'Light mode' : 'লাইট মোড'),
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          trailing: Switch(
            value: isDark,
            activeThumbColor: AppColors.accentViolet,
            onChanged: (_) => ThemeService.toggle(),
          ),
          onTap: ThemeService.toggle,
        );
      },
    );
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: LocaleService.notifier,
      builder: (context, value, _) {
        final isEn = value == Language.en;
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg, vertical: 2),
          leading: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.accentTeal.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            alignment: Alignment.center,
            child: Icon(Icons.translate_rounded, color: AppColors.accentTeal, size: 20),
          ),
          title: Text(
            AppStrings.language,
            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
            ),
            child: Text(
              isEn ? 'EN' : 'বাংলা',
              style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
            ),
          ),
          onTap: () => LocaleService.toggle(),
        );
      },
    );
  }
}
