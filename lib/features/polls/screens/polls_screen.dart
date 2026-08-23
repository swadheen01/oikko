import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/poll.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

class PollsScreen extends StatelessWidget {
  final String? currentUserUid;

  const PollsScreen({super.key, this.currentUserUid});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.polls, style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: firestoreService.watchAllPolls(),
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
                            Text(
                              LocaleService.isEnglish
                                  ? '$totalVotes vote${totalVotes == 1 ? '' : 's'}'
                                  : '$totalVotes টি ভোট',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w700,
                              ),
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
                            if (!hasVoted && currentUserUid != null)
                              GradientButton(
                                label: LocaleService.isEnglish ? 'Vote' : 'ভোট দিন',
                                icon: Icons.how_to_vote_rounded,
                                onPressed: () => _showVoteOptions(
                                  context,
                                  poll,
                                  firestoreService,
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
