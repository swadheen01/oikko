import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/phone_utils.dart';
import '../../admin/screens/edit_member_screen.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../models/member.dart';
import '../../../widgets/premium_card.dart';

class MemberProfileScreen extends StatefulWidget {
  final Member member;
  const MemberProfileScreen({super.key, required this.member});

  @override
  State<MemberProfileScreen> createState() => _MemberProfileScreenState();
}

class _MemberProfileScreenState extends State<MemberProfileScreen> {
  /// Whether the *viewer* is an admin — controls the edit action. Checked
  /// against the `admins/{uid}` marker the security rules actually enforce,
  /// so the button never appears for someone whose edit would be rejected.
  bool _isAdmin = false;

  @override
  void initState() {
    super.initState();
    _checkAdmin();
  }

  Future<void> _checkAdmin() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final isAdmin = await FirestoreService().hasAdminMarker(uid);
    if (mounted) setState(() => _isAdmin = isAdmin);
  }

  /// Formats a stored ISO date (yyyy-MM-dd) as "d Mon yyyy". Returns '' for
  /// an empty value (so the info card hides the row) and the raw string if it
  /// isn't a parseable ISO date.
  static String _fmtDate(String iso) {
    if (iso.trim().isEmpty) return '';
    final d = DateTime.tryParse(iso.trim());
    if (d == null) return iso.trim();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${d.day} ${months[d.month - 1]} ${d.year}';
  }

  Future<void> _launch(String url) async {
    final uri = Uri.parse(url);
    // externalApplication so a wa.me link hands off to the WhatsApp app
    // rather than opening in an in-app browser view.
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (await canLaunchUrl(uri)) await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watches the document rather than using the Member passed in, so an
    // edit made from here is reflected the moment it saves — otherwise the
    // page would still show the old name until it was reopened.
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirestoreService()
          .collection(FirestorePaths.members)
          .doc(widget.member.id)
          .snapshots(),
      builder: (context, snapshot) {
        final member = (snapshot.hasData && snapshot.data!.exists)
            ? Member.fromDoc(snapshot.data!)
            : widget.member;
        return _buildBody(context, member);
      },
    );
  }

  Widget _buildBody(BuildContext context, Member member) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.primary,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              if (_isAdmin)
                IconButton(
                  tooltip: LocaleService.isEnglish ? 'Edit info' : 'তথ্য সংশোধন',
                  icon: const Icon(Icons.edit_rounded, color: Colors.white),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EditMemberScreen(member: member),
                    ),
                  ),
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: AppGradients.heroCard),
                child: SafeArea(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: AppDimensions.avatarLg / 2,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        backgroundImage: member.photoUrl.isNotEmpty ? NetworkImage(member.photoUrl) : null,
                        child: member.photoUrl.isEmpty
                            ? Text(
                                member.name.isNotEmpty ? member.name.characters.first : '?',
                                style: AppTextStyles.h1.copyWith(color: Colors.white, fontSize: 36),
                              )
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Text(member.name, style: AppTextStyles.h2.copyWith(color: Colors.white)),
                      const SizedBox(height: 2),
                      Text(
                        member.designation,
                        style: AppTextStyles.bodyMedium.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(AppDimensions.lg),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick contact row. Numbers are stored in local form
                // (01712…); WhatsApp needs the full international number, so
                // every link goes through PhoneUtils rather than using the
                // raw string. A number that can't be normalised (a few in
                // the imported roster are the wrong length) disables these
                // instead of opening a chat with the wrong person.
                Builder(builder: (context) {
                  final wa = PhoneUtils.whatsAppUrl(member.phone);
                  final tel = PhoneUtils.telUrl(member.phone);
                  final sms = PhoneUtils.smsUrl(member.phone);

                  return Row(
                    children: [
                      Expanded(
                        child: _ContactButton(
                          icon: Icons.call_rounded,
                          label: LocaleService.isEnglish ? 'Call' : 'কল',
                          color: AppColors.success,
                          onTap: tel == null ? null : () => _launch(tel),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: _ContactButton(
                          icon: Icons.sms_rounded,
                          label: LocaleService.isEnglish ? 'SMS' : 'এসএমএস',
                          color: AppColors.primary,
                          onTap: sms == null ? null : () => _launch(sms),
                        ),
                      ),
                      const SizedBox(width: AppDimensions.sm),
                      Expanded(
                        child: _ContactButton(
                          icon: Icons.chat_rounded,
                          label: LocaleService.isEnglish ? 'WhatsApp' : 'হোয়াটসঅ্যাপ',
                          color: const Color(0xFF25D366),
                          onTap: wa == null ? null : () => _launch(wa),
                        ),
                      ),
                    ],
                  );
                }),
                const SizedBox(height: AppDimensions.lg),

                // When a blood group is on file, surface it prominently with
                // a one-tap call — this is the payoff of the Blood donors
                // finder: you land on the donor and can reach them at once.
                if (member.bloodGroup.trim().isNotEmpty) ...[
                  Builder(builder: (context) {
                    final tel = PhoneUtils.telUrl(member.phone);
                    return _BloodBanner(
                      group: member.bloodGroup.trim(),
                      onCall: tel == null ? null : () => _launch(tel),
                    );
                  }),
                  const SizedBox(height: AppDimensions.lg),
                ],

                _InfoCard(items: [
                  _InfoRow(
                    icon: Icons.school_rounded,
                    label: LocaleService.isEnglish ? 'School' : 'বিদ্যালয়',
                    value: member.schoolName,
                  ),
                  _InfoRow(
                    icon: Icons.badge_rounded,
                    label: LocaleService.isEnglish ? 'Designation' : 'পদবী',
                    value: member.designation,
                  ),
                  _InfoRow(
                    icon: Icons.workspace_premium_rounded,
                    label: LocaleService.isEnglish ? 'Qualification' : 'যোগ্যতা',
                    value: member.qualification,
                  ),
                  _InfoRow(
                    icon: Icons.bloodtype_rounded,
                    label: LocaleService.isEnglish ? 'Blood group' : 'রক্তের গ্রুপ',
                    value: member.bloodGroup,
                    accent: AppColors.danger,
                  ),
                  _InfoRow(
                    icon: Icons.phone_rounded,
                    label: LocaleService.isEnglish ? 'Phone' : 'ফোন',
                    value: member.phone,
                  ),
                  _InfoRow(
                    icon: Icons.email_rounded,
                    label: LocaleService.isEnglish ? 'Email' : 'ইমেইল',
                    value: member.email,
                  ),
                  _InfoRow(
                    icon: Icons.tag_rounded,
                    label: LocaleService.isEnglish ? 'Index number' : 'ইনডেক্স নম্বর',
                    value: member.indexNumber,
                  ),
                  _InfoRow(
                    icon: Icons.event_available_rounded,
                    label: LocaleService.isEnglish ? 'Joining date' : 'যোগদানের তারিখ',
                    value: _fmtDate(member.joiningDate),
                  ),
                  _InfoRow(
                    icon: Icons.event_note_rounded,
                    label: LocaleService.isEnglish ? 'MPO date' : 'এমপিও তারিখ',
                    value: _fmtDate(member.mpoDate),
                  ),
                ]),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  /// Null when the member's number can't be dialled/messaged — the button
  /// greys out instead of silently doing nothing when tapped.
  final VoidCallback? onTap;

  const _ContactButton({required this.icon, required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final shade = enabled ? color : AppColors.textSecondary;

    return Material(
      color: shade.withValues(alpha: enabled ? 0.1 : 0.06),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: shade.withValues(alpha: enabled ? 1 : 0.5)),
              const SizedBox(height: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: shade.withValues(alpha: enabled ? 1 : 0.6),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Prominent blood-group panel with a one-tap call, shown at the top of a
/// member's profile whenever a group is on file.
class _BloodBanner extends StatelessWidget {
  final String group;
  final VoidCallback? onCall;

  const _BloodBanner({required this.group, required this.onCall});

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.md),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.danger,
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              boxShadow: [
                BoxShadow(
                  color: AppColors.danger.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              group,
              style: AppTextStyles.h3.copyWith(color: Colors.white, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.bloodtype_rounded, size: 15, color: AppColors.danger),
                    const SizedBox(width: 4),
                    Text(
                      isEn ? 'Blood group' : 'রক্তের গ্রুপ',
                      style: AppTextStyles.overline.copyWith(color: AppColors.danger),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  isEn ? 'Can donate $group blood' : '$group রক্ত দিতে পারেন',
                  style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          // Direct call to arrange donation. Disabled (greyed) when the
          // stored number can't be dialled, matching the contact row above.
          Material(
            color: onCall == null
                ? AppColors.textSecondary.withValues(alpha: 0.12)
                : AppColors.danger,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              onTap: onCall,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.call_rounded,
                      size: 16,
                      color: onCall == null ? AppColors.textSecondary : Colors.white,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isEn ? 'Call' : 'কল',
                      style: AppTextStyles.caption.copyWith(
                        color: onCall == null ? AppColors.textSecondary : Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> items;
  const _InfoCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.sm),
      child: Column(
        children: items
            .where((item) => item.value.isNotEmpty)
            .map((item) => item)
            .toList(),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  /// Overrides the default blue tint for the leading icon — used to mark the
  /// blood-group row in red so it reads as blood.
  final Color? accent;

  const _InfoRow({required this.icon, required this.label, required this.value, this.accent});

  @override
  Widget build(BuildContext context) {
    final tint = accent ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.md, vertical: AppDimensions.sm),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
            ),
            child: Icon(icon, color: tint, size: AppDimensions.iconSm),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.overline),
                Text(value, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
