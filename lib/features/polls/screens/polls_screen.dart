import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/admin_session.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/poll.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';
import 'poll_create_screen.dart';

class PollsScreen extends StatefulWidget {
  final String? currentUserUid;

  /// When true (the admin's Poll tab), a "Create new poll" button is shown
  /// above the list. Admin stop/delete controls appear on each card
  /// independently, driven by [AdminSession.isAdmin].
  final bool showCreateButton;

  const PollsScreen({
    super.key,
    this.currentUserUid,
    this.showCreateButton = false,
  });

  @override
  State<PollsScreen> createState() => _PollsScreenState();
}

class _PollsScreenState extends State<PollsScreen> {
  final firestoreService = FirestoreService();
  // Cached once (see HomeScreen): a per-build stream makes StreamBuilder flash
  // back to empty and resets scroll on every rebuild.
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _pollsStream =
      firestoreService.watchAllPolls();

  String? get currentUserUid => widget.currentUserUid;
  bool get showCreateButton => widget.showCreateButton;

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.polls, style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.md),
            if (showCreateButton) ...[
              GradientButton(
                label: LocaleService.isEnglish ? 'Create new poll' : 'নতুন পোল তৈরি করুন',
                icon: Icons.add_rounded,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PollCreateScreen()),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
            ],
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _pollsStream,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(
                      child: CircularProgressIndicator(
                        color: AppColors.primary,
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                    return Center(
                      child: Text(
                        LocaleService.isEnglish ? 'No active polls' : 'সক্রিয় কোনো পোল নেই',
                        style: AppTextStyles.bodyMedium,
                      ),
                    );
                  }

                  final polls = snapshot.data!.docs.map(Poll.fromDoc).toList();

                  return ListView.separated(
                    itemCount: polls.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.md),
                    itemBuilder: (context, index) {
                      final poll = polls[index];
                      final hasVoted =
                          currentUserUid != null &&
                          poll.hasVoted(currentUserUid!);
                      final totalVotes = poll.totalVotes();
                      // Once the duration set at creation has passed, voting
                      // closes: no vote button, only the result remains.
                      final isClosed = poll.closesAt != null &&
                          poll.closesAt!.isBefore(DateTime.now());

                      // Each option gets its own hue from the accent family,
                      // so a poll reads as a set of distinct choices rather
                      // than a stack of identical blue bars.
                      final optionColors = [
                        AppColors.primary,
                        AppColors.accentViolet,
                        AppColors.accentTeal,
                        AppColors.accentAmber,
                        AppColors.accentRose,
                        AppColors.accentCyan,
                      ];
                      final leaderIndex = poll.options.isEmpty
                          ? -1
                          : List.generate(poll.options.length, (i) => i).reduce(
                              (a, b) =>
                                  (poll.votes[b.toString()] ?? 0) >
                                          (poll.votes[a.toString()] ?? 0)
                                      ? b
                                      : a,
                            );

                      return PremiumCard(
                        padding: EdgeInsets.zero,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppGradients.accentWash(AppColors.accentViolet),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppDimensions.md),
                            child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(9),
                                  decoration: BoxDecoration(
                                    gradient: AppGradients.button,
                                    borderRadius:
                                        BorderRadius.circular(AppDimensions.radiusSm),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.accentViolet
                                            .withValues(alpha: 0.45),
                                        blurRadius: 12,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: const Icon(Icons.how_to_vote_rounded,
                                      size: 17, color: Colors.white),
                                ),
                                const SizedBox(width: AppDimensions.sm),
                                Expanded(
                                  child: Text(poll.question, style: AppTextStyles.h3),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Text(
                                  LocaleService.isEnglish
                                      ? '$totalVotes vote${totalVotes == 1 ? '' : 's'}'
                                      : '$totalVotes টি ভোট',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.sm),
                                if (isClosed)
                                  _StatusPill(
                                    icon: Icons.lock_rounded,
                                    label: LocaleService.isEnglish ? 'Closed' : 'শেষ',
                                    color: AppColors.textSecondary,
                                  )
                                else if (poll.closesAt != null)
                                  _StatusPill(
                                    icon: Icons.timer_outlined,
                                    label: _closesInLabel(poll.closesAt!),
                                    color: AppColors.primary,
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.md),
                            ...poll.options.asMap().entries.map((e) {
                              final index = e.key;
                              final option = e.value;
                              final votes = poll.votes[index.toString()] ?? 0;
                              final percentage = totalVotes > 0
                                  ? (votes / totalVotes * 100).toStringAsFixed(
                                      1,
                                    )
                                  : '0.0';
                              final color = optionColors[index % optionColors.length];
                              final isLeader = totalVotes > 0 && index == leaderIndex;

                              return Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppDimensions.sm,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Text(
                                            option,
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              fontWeight: isLeader
                                                  ? FontWeight.w700
                                                  : FontWeight.w400,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          '$percentage%',
                                          style: AppTextStyles.caption.copyWith(
                                            color: color,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 5),
                                    // A gradient fill on a tinted track, not
                                    // a flat bar — the poll is the most
                                    // "alive" element on the screen.
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(
                                        AppDimensions.radiusPill,
                                      ),
                                      child: Stack(
                                        children: [
                                          Container(
                                            height: 10,
                                            color: color.withValues(alpha: 0.14),
                                          ),
                                          AnimatedFractionallySizedBox(
                                            duration:
                                                const Duration(milliseconds: 450),
                                            curve: Curves.easeOutCubic,
                                            widthFactor: totalVotes > 0
                                                ? (votes / totalVotes).clamp(0.0, 1.0)
                                                : 0.0,
                                            child: Container(
                                              height: 10,
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    color.withValues(alpha: 0.75),
                                                    color,
                                                  ],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: color.withValues(alpha: 0.5),
                                                    blurRadius: 8,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: AppDimensions.md),
                            if (!hasVoted && currentUserUid != null && !isClosed)
                              GradientButton(
                                label: LocaleService.isEnglish ? 'Vote' : 'ভোট দিন',
                                icon: Icons.how_to_vote_rounded,
                                onPressed: () => _showVoteOptions(
                                  context,
                                  poll,
                                  firestoreService,
                                ),
                              ),
                            if (isClosed && !hasVoted)
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.lock_rounded, size: 15, color: AppColors.textSecondary),
                                    const SizedBox(width: 6),
                                    Text(
                                      LocaleService.isEnglish
                                          ? 'Voting has ended'
                                          : 'ভোট গ্রহণ শেষ হয়েছে',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            if (hasVoted)
                              Center(
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.check_circle_rounded, size: 15, color: AppColors.success),
                                    const SizedBox(width: 6),
                                    Text(
                                      LocaleService.isEnglish ? 'You already voted' : 'আপনি ইতিমধ্যে ভোট দিয়েছেন',
                                      style: AppTextStyles.caption.copyWith(
                                        color: AppColors.success,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ValueListenableBuilder<bool>(
                              valueListenable: AdminSession.isAdmin,
                              builder: (context, isAdmin, _) {
                                if (!isAdmin) return const SizedBox.shrink();
                                return Padding(
                                  padding: const EdgeInsets.only(top: AppDimensions.sm),
                                  child: Row(
                                    children: [
                                      if (!isClosed)
                                        Expanded(
                                          child: _AdminPollAction(
                                            icon: Icons.stop_circle_rounded,
                                            label: LocaleService.isEnglish ? 'Stop' : 'বন্ধ করুন',
                                            color: AppColors.warning,
                                            onTap: () => _confirmStop(
                                              context, poll, firestoreService,
                                            ),
                                          ),
                                        ),
                                      if (!isClosed) const SizedBox(width: AppDimensions.sm),
                                      Expanded(
                                        child: _AdminPollAction(
                                          icon: Icons.delete_rounded,
                                          label: LocaleService.isEnglish ? 'Delete' : 'মুছুন',
                                          color: AppColors.danger,
                                          onTap: () => _confirmDelete(
                                            context, poll, firestoreService,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Short "closes in …" label for a still-open poll's remaining time.
  static String _closesInLabel(DateTime closesAt) {
    final left = closesAt.difference(DateTime.now());
    final isEn = LocaleService.isEnglish;
    if (left.inDays >= 1) {
      final d = left.inDays;
      return isEn ? '${d}d left' : '$d দিন বাকি';
    }
    if (left.inHours >= 1) {
      final h = left.inHours;
      return isEn ? '${h}h left' : '$h ঘণ্টা বাকি';
    }
    final m = left.inMinutes < 1 ? 1 : left.inMinutes;
    return isEn ? '${m}m left' : '$m মিনিট বাকি';
  }

  Future<void> _confirmStop(
    BuildContext context,
    Poll poll,
    FirestoreService firestoreService,
  ) async {
    final isEn = LocaleService.isEnglish;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Stop voting?' : 'ভোট বন্ধ করবেন?'),
        content: Text(isEn
            ? 'Voting closes now. The result stays visible, but no one can vote anymore.'
            : 'এখনই ভোট বন্ধ হয়ে যাবে। ফলাফল দেখা যাবে, তবে কেউ আর ভোট দিতে পারবে না।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isEn ? 'Cancel' : 'বাতিল'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(isEn ? 'Stop' : 'বন্ধ করুন'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await firestoreService.closePoll(poll.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEn ? 'Could not stop the poll' : 'পোল বন্ধ করা যায়নি')),
        );
      }
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    Poll poll,
    FirestoreService firestoreService,
  ) async {
    final isEn = LocaleService.isEnglish;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Delete poll?' : 'পোল মুছবেন?'),
        content: Text(isEn
            ? 'The poll and its result will be permanently removed. This cannot be undone.'
            : 'পোল এবং এর ফলাফল স্থায়ীভাবে মুছে যাবে। এটি আর ফেরানো যাবে না।'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(isEn ? 'Cancel' : 'বাতিল'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(isEn ? 'Delete' : 'মুছুন'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await firestoreService.deletePoll(poll.id);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(isEn ? 'Could not delete the poll' : 'পোল মুছা যায়নি')),
        );
      }
    }
  }

  void _showVoteOptions(
    BuildContext context,
    Poll poll,
    FirestoreService firestoreService,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.lg, AppDimensions.md, AppDimensions.lg, AppDimensions.xl,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppDimensions.radiusXl)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: AppDimensions.md),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
              ),
            ),
            Text(
              LocaleService.isEnglish ? 'Choose your vote' : 'আপনার ভোট নির্বাচন করুন',
              style: AppTextStyles.h3,
            ),
            const SizedBox(height: AppDimensions.md),
            ...poll.options.asMap().entries.map((e) {
              final index = e.key;
              final option = e.value;

              return Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                child: Material(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    onTap: () async {
                      await firestoreService.votePoll(
                        pollId: poll.id,
                        optionIndex: index,
                        voterId: currentUserUid ?? '',
                      );
                      if (context.mounted) {
                        Navigator.of(context).pop();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.md, vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(option, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                          ),
                          Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

/// Compact outlined admin button on a poll card (Stop / Delete).
class _AdminPollAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _AdminPollAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.10),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded status chip on a poll card — "Closed", or the remaining
/// time while voting is still open.
class _StatusPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatusPill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
