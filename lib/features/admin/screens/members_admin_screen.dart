import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/member_pdf_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/designation_rank.dart';
import '../../../models/member.dart';
import '../../directory/widgets/school_filter_field.dart';
import '../../finance/screens/add_payment_screen.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';
import '../../../widgets/status_badge.dart';
import 'add_member_screen.dart';
import 'edit_member_screen.dart';

/// Admin-only: the full member roster — search, shareable Member IDs,
/// export, and delete. Replaces the earlier IDs-only screen, which listed
/// only members that already had a `memberCode` and so silently hid every
/// self-registered member from the admin entirely.
class MembersAdminScreen extends StatefulWidget {
  const MembersAdminScreen({super.key});

  @override
  State<MembersAdminScreen> createState() => _MembersAdminScreenState();
}

class _MembersAdminScreenState extends State<MembersAdminScreen> {
  final _firestoreService = FirestoreService();
  // Cached once (see HomeScreen): a per-build stream makes StreamBuilder flash
  // back to empty and resets scroll on every rebuild.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream =
      _firestoreService.watchAllMembers();
  final _searchController = TextEditingController();
  String _query = '';
  String? _schoolFilter;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Member> _filter(List<Member> members) {
    final q = _query.trim().toLowerCase();
    var result = q.isEmpty
        ? [...members]
        : members
            .where((m) =>
                m.name.toLowerCase().contains(q) ||
                m.nameEnglish.toLowerCase().contains(q) ||
                m.schoolName.toLowerCase().contains(q) ||
                m.memberCode.toLowerCase().contains(q))
            .toList();

    if (_schoolFilter != null) {
      result = result.where((m) => m.schoolName.trim() == _schoolFilter).toList();
    }

    // Seniority order (head teacher, assistant head, senior, assistant),
    // not the alphabetical order the Firestore query returns.
    result.sort((a, b) => DesignationRank.compare(
          a.designation, a.name, b.designation, b.name,
        ));
    return result;
  }

  /// School -> member count, for the picker.
  static Map<String, int> _schoolCounts(List<Member> members) {
    final counts = <String, int>{};
    for (final m in members) {
      final s = m.schoolName.trim();
      if (s.isEmpty) continue;
      counts[s] = (counts[s] ?? 0) + 1;
    }
    return counts;
  }

  Future<void> _confirmRoleChange(Member member) async {
    final makeAdmin = !member.isAdmin;

    if (makeAdmin && (member.authUid == null || member.authUid!.isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocaleService.isEnglish
                ? '${member.name} must connect their Member ID to a login before they can be made an admin.'
                : '${member.name} কে অ্যাডমিন করার আগে তাকে সদস্য আইডি দিয়ে একাউন্ট সংযুক্ত করতে হবে।',
          ),
          backgroundColor: AppColors.warning,
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          makeAdmin
              ? (LocaleService.isEnglish ? 'Make admin?' : 'অ্যাডমিন করবেন?')
              : (LocaleService.isEnglish ? 'Remove admin?' : 'অ্যাডমিন সরাবেন?'),
          style: AppTextStyles.h3,
        ),
        content: Text(
          makeAdmin
              ? (LocaleService.isEnglish
                  ? '${member.name} will get full admin power — equal to every other admin: publish notices, log payments, approve requests, delete members, permanently clear all finance/notice records, and promote or remove any other admin (including you).'
                  : '${member.name} সম্পূর্ণ অ্যাডমিন ক্ষমতা পাবেন — অন্য সব অ্যাডমিনের সমান: নোটিশ প্রকাশ, পেমেন্ট যোগ, অনুরোধ অনুমোদন, সদস্য মুছে ফেলা, সব হিসাব/নোটিশ স্থায়ীভাবে মুছে ফেলা, এবং যেকোনো অ্যাডমিনকে (আপনাকেও) সরানো বা নতুন অ্যাডমিন করা।')
              : (LocaleService.isEnglish
                  ? '${member.name} will lose all admin access and go back to being a regular member.'
                  : '${member.name} সব অ্যাডমিন অধিকার হারাবেন এবং সাধারণ সদস্য হয়ে যাবেন।'),
          style: AppTextStyles.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(LocaleService.isEnglish ? 'Cancel' : 'বাতিল'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: makeAdmin ? AppColors.accentViolet : AppColors.danger,
            ),
            child: Text(
              makeAdmin
                  ? (LocaleService.isEnglish ? 'Make admin' : 'অ্যাডমিন করুন')
                  : (LocaleService.isEnglish ? 'Remove' : 'সরান'),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestoreService.setMemberAdmin(
        memberId: member.id,
        authUid: member.authUid,
        makeAdmin: makeAdmin,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            makeAdmin
                ? (LocaleService.isEnglish
                    ? '${member.name} is now an admin'
                    : '${member.name} এখন অ্যাডমিন')
                : (LocaleService.isEnglish
                    ? '${member.name} is no longer an admin'
                    : '${member.name} আর অ্যাডমিন নন'),
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${LocaleService.isEnglish ? 'Could not change role' : 'ভূমিকা পরিবর্তন করা যায়নি'}: $e'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  Future<void> _sharePdf(BuildContext context, List<Member> members) async {
    final isEn = LocaleService.isEnglish;
    try {
      await MemberPdfService.shareMemberList(members);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${isEn ? 'Could not create PDF' : 'পিডিএফ তৈরি করা যায়নি'}: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  void _copyList(List<Member> members, {required bool asExcel}) {
    // Tab-separated pastes straight into separate Excel/Sheets columns and
    // survives names containing commas; CSV is kept for anything that
    // expects a .csv-style paste (messages, plain text).
    final sep = asExcel ? '\t' : ',';
    final buffer = StringBuffer('Name${sep}School${sep}Member ID${sep}Connected\n');
    for (final m in members) {
      final name = m.name.replaceAll(sep, ' ');
      final school = m.schoolName.replaceAll(sep, ' ');
      final code = m.memberCode.isEmpty ? '-' : m.memberCode;
      final connected = m.isClaimed ? 'Yes' : 'No';
      buffer.writeln('$name$sep$school$sep$code$sep$connected');
    }
    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          asExcel
              ? (LocaleService.isEnglish
                  ? 'Copied — paste directly into an Excel/Sheets cell'
                  : 'কপি করা হয়েছে — সরাসরি এক্সেল/শীটের ঘরে পেস্ট করুন')
              : (LocaleService.isEnglish
                  ? 'CSV copied — paste into Sheets, Excel, or a message'
                  : 'CSV কপি করা হয়েছে — শীট, এক্সেল বা মেসেজে পেস্ট করুন'),
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  Future<void> _confirmDelete(Member member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          LocaleService.isEnglish ? 'Delete member?' : 'সদস্য মুছে ফেলবেন?',
          style: AppTextStyles.h3,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleService.isEnglish
                  ? '"${member.name}" and all of their payment records will be permanently deleted. This cannot be undone.'
                  : '"${member.name}" এবং তার সব পেমেন্ট রেকর্ড স্থায়ীভাবে মুছে যাবে। এটি ফেরানো যাবে না।',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.sm),
            // The payment count is the number that actually matters here —
            // deleting a member with a long payment history is a very
            // different decision from deleting an empty placeholder record.
            FutureBuilder<int>(
              future: _firestoreService.countMemberTransactions(member.id),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return Text(
                    LocaleService.isEnglish ? 'Checking payment records…' : 'পেমেন্ট রেকর্ড দেখা হচ্ছে…',
                    style: AppTextStyles.caption,
                  );
                }
                final count = snapshot.data!;
                return Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  decoration: BoxDecoration(
                    color: (count > 0 ? AppColors.danger : AppColors.textSecondary).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  ),
                  child: Text(
                    LocaleService.isEnglish
                        ? '$count payment record${count == 1 ? '' : 's'} will also be deleted'
                        : '$count টি পেমেন্ট রেকর্ডও মুছে যাবে',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: count > 0 ? AppColors.danger : AppColors.textSecondary,
                    ),
                  ),
                );
              },
            ),
            if (member.isClaimed) ...[
              const SizedBox(height: AppDimensions.sm),
              Text(
                LocaleService.isEnglish
                    ? 'This member is connected to a login. That account will not be deleted, but it will lose access to this profile.'
                    : 'এই সদস্য একটি একাউন্টের সাথে যুক্ত। একাউন্টটি মুছবে না, তবে এই প্রোফাইলে আর প্রবেশ করতে পারবে না।',
                style: AppTextStyles.caption.copyWith(color: AppColors.warning),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(LocaleService.isEnglish ? 'Cancel' : 'বাতিল'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(LocaleService.isEnglish ? 'Delete' : 'মুছে ফেলুন'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _firestoreService.deleteMemberAndData(member.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocaleService.isEnglish ? '${member.name} deleted' : '${member.name} মুছে ফেলা হয়েছে',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${LocaleService.isEnglish ? 'Delete failed' : 'মুছে ফেলা যায়নি'}: $e'),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 6),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _membersStream,
          builder: (context, snapshot) {
            final all = (snapshot.data?.docs ?? []).map(Member.fromDoc).toList();
            final filtered = _filter(all);
            final waiting = snapshot.connectionState == ConnectionState.waiting;

            // Whole screen is one scroll view: the title, action buttons,
            // school filter and search sit in a header sliver that scrolls
            // up and out of the way, so the member list gets the full height
            // to scroll through instead of a cramped fixed panel.
            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg, AppDimensions.lg, AppDimensions.lg, 0,
                  ),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (Navigator.of(context).canPop()) ...[
                              IconButton(
                                onPressed: () => Navigator.of(context).pop(),
                                icon: const Icon(Icons.arrow_back_rounded),
                                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                              ),
                              const SizedBox(width: AppDimensions.sm),
                            ],
                            Expanded(
                              child: Text(
                                LocaleService.isEnglish ? 'Members' : 'সদস্য তালিকা',
                                style: AppTextStyles.h2,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.md),
                        // The global "+" speed-dial is hidden on this tab, so
                        // the actions it offers live here instead.
                        Row(
                          children: [
                            Expanded(
                              child: _HeaderAction(
                                icon: Icons.person_add_rounded,
                                label: AppStrings.addMember,
                                color: AppColors.accentViolet,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AddMemberScreen()),
                                ),
                              ),
                            ),
                            const SizedBox(width: AppDimensions.sm),
                            Expanded(
                              child: _HeaderAction(
                                icon: Icons.payments_rounded,
                                label: AppStrings.addPayment,
                                color: AppColors.accentTeal,
                                onTap: () => Navigator.of(context).push(
                                  MaterialPageRoute(builder: (_) => const AddPaymentScreen()),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.md),
                        SchoolFilterField(
                          counts: _schoolCounts(all),
                          selected: _schoolFilter,
                          onChanged: (s) => setState(() => _schoolFilter = s),
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        TextField(
                          controller: _searchController,
                          onChanged: (value) => setState(() => _query = value),
                          decoration: InputDecoration(
                            hintText: LocaleService.isEnglish
                                ? 'Search by name, school or ID'
                                : 'নাম, বিদ্যালয় বা আইডি দিয়ে খুঁজুন',
                            prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                          ),
                        ),
                        const SizedBox(height: AppDimensions.md),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              LocaleService.isEnglish
                                  ? '${filtered.length} member${filtered.length == 1 ? '' : 's'}'
                                  : '${filtered.length} জন সদস্য',
                              style: AppTextStyles.bodyMedium,
                            ),
                            Wrap(
                              spacing: 4,
                              children: [
                                TextButton.icon(
                                  onPressed: filtered.isEmpty
                                      ? null
                                      : () => _copyList(filtered, asExcel: false),
                                  icon: const Icon(Icons.ios_share_rounded, size: 16),
                                  label: Text(LocaleService.isEnglish ? 'CSV' : 'CSV'),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                ),
                                TextButton.icon(
                                  onPressed: filtered.isEmpty
                                      ? null
                                      : () => _copyList(filtered, asExcel: true),
                                  icon: const Icon(Icons.table_chart_rounded, size: 16),
                                  label: Text(LocaleService.isEnglish ? 'Excel' : 'এক্সেল'),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.accentTeal),
                                ),
                                TextButton.icon(
                                  onPressed: filtered.isEmpty
                                      ? null
                                      : () => _sharePdf(context, filtered),
                                  icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                  label: Text(LocaleService.isEnglish ? 'PDF' : 'পিডিএফ'),
                                  style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.sm),
                      ],
                    ),
                  ),
                ),

                if (snapshot.hasError)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.xl),
                      child: Center(
                        child: Text(
                          '${LocaleService.isEnglish ? 'Could not load members' : 'সদস্য তালিকা লোড হয়নি'}\n${snapshot.error}',
                          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  )
                else if (waiting && all.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.xl),
                      child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
                    ),
                  )
                else if (filtered.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.xl),
                      child: Center(
                        child: Text(
                          LocaleService.isEnglish ? 'No members found' : 'কোনো সদস্য পাওয়া যায়নি',
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
                          child: _MemberRow(
                            member: filtered[index],
                            onDelete: () => _confirmDelete(filtered[index]),
                            onToggleAdmin: () => _confirmRoleChange(filtered[index]),
                            onEdit: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => EditMemberScreen(member: filtered[index]),
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
      ),
    );
  }
}

/// Compact coloured action button used in place of the hidden speed-dial.
class _HeaderAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _HeaderAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 17, color: color),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MemberRow extends StatelessWidget {
  final Member member;
  final VoidCallback onDelete;
  final VoidCallback onToggleAdmin;
  final VoidCallback onEdit;

  const _MemberRow({
    required this.member,
    required this.onDelete,
    required this.onToggleAdmin,
    required this.onEdit,
  });

  void _copyCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: member.memberCode));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.idCopied), backgroundColor: AppColors.success),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasCode = member.memberCode.isNotEmpty;

    return PremiumCard(
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: member.photoUrl.isNotEmpty ? NetworkImage(member.photoUrl) : null,
            child: member.photoUrl.isEmpty
                ? Text(
                    member.name.isNotEmpty ? member.name.characters.first : '?',
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.name,
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                ),
                if (member.schoolName.isNotEmpty)
                  Text(member.schoolName, style: AppTextStyles.caption),
                if (member.designation.isNotEmpty)
                  Text(member.designation, style: AppTextStyles.caption),
                const SizedBox(height: 6),
                Wrap(
                  spacing: AppDimensions.sm,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Text(
                      hasCode
                          ? member.memberCode
                          : (LocaleService.isEnglish ? 'No ID' : 'আইডি নেই'),
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w800,
                        letterSpacing: hasCode ? 1.2 : 0,
                        color: hasCode ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                    StatusBadge(
                      label: member.isClaimed
                          ? (LocaleService.isEnglish ? 'Connected' : 'সংযুক্ত')
                          : (LocaleService.isEnglish ? 'Not connected' : 'সংযুক্ত হয়নি'),
                      color: member.isClaimed ? AppColors.success : AppColors.warning,
                    ),
                    if (member.isAdmin)
                      StatusBadge(label: AppStrings.admin, color: AppColors.accentViolet),
                  ],
                ),
              ],
            ),
          ),
          // A menu rather than a row of icons: three actions (copy ID,
          // change role, delete) don't fit beside the member details, and
          // burying delete one tap deeper is no bad thing.
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
            color: AppColors.surface,
            onSelected: (value) {
              switch (value) {
                case 'edit':
                  onEdit();
                case 'copy':
                  _copyCode(context);
                case 'role':
                  onToggleAdmin();
                case 'delete':
                  onDelete();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'edit',
                child: Row(
                  children: [
                    Icon(Icons.edit_rounded, size: 18, color: AppColors.primary),
                    const SizedBox(width: AppDimensions.sm),
                    Text(LocaleService.isEnglish ? 'Edit info' : 'তথ্য সংশোধন'),
                  ],
                ),
              ),
              if (hasCode)
                PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: AppDimensions.sm),
                      Text(AppStrings.copyId),
                    ],
                  ),
                ),
              PopupMenuItem(
                value: 'role',
                child: Row(
                  children: [
                    Icon(
                      member.isAdmin
                          ? Icons.person_remove_rounded
                          : Icons.admin_panel_settings_rounded,
                      size: 18,
                      color: member.isAdmin ? AppColors.danger : AppColors.accentViolet,
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Text(
                      member.isAdmin
                          ? (LocaleService.isEnglish ? 'Remove admin' : 'অ্যাডমিন সরান')
                          : (LocaleService.isEnglish ? 'Make admin' : 'অ্যাডমিন করুন'),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.danger),
                    const SizedBox(width: AppDimensions.sm),
                    Text(LocaleService.isEnglish ? 'Delete member' : 'সদস্য মুছুন'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
