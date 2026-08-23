import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/locale/locale_service.dart';
import '../../../models/notice.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';
import '../../../widgets/status_badge.dart';
import 'notice_detail_screen.dart';

class NoticesScreen extends StatelessWidget {
  /// Admins get per-notice delete plus a "clear all" — the notice board is
  /// append-only otherwise, so old or mistaken posts would pile up forever.
  final bool isAdmin;

  const NoticesScreen({super.key, this.isAdmin = false});

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String message,
    required String confirmLabel,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(title, style: AppTextStyles.h3),
        content: Text(message, style: AppTextStyles.bodyMedium),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(LocaleService.isEnglish ? 'Cancel' : 'বাতিল'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result == true;
  }

  Future<void> _deleteOne(
    BuildContext context,
    FirestoreService service,
    Notice notice,
  ) async {
    final isEn = LocaleService.isEnglish;
    final ok = await _confirm(
      context,
      title: isEn ? 'Delete this notice?' : 'এই নোটিশটি মুছবেন?',
      message: isEn
          ? '"${notice.title}" will be removed for everyone. This cannot be undone.'
          : '"${notice.title}" সবার কাছ থেকে মুছে যাবে। এটি ফেরানো যাবে না।',
      confirmLabel: isEn ? 'Delete' : 'মুছুন',
    );
    if (!ok || !context.mounted) return;
    try {
      await service.deleteNotice(notice.id);
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.errorGeneric}: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  Future<void> _deleteAll(BuildContext context, FirestoreService service) async {
    final isEn = LocaleService.isEnglish;
    final ok = await _confirm(
      context,
      title: isEn ? 'Clear all notices?' : 'সব নোটিশ মুছবেন?',
      message: isEn
          ? 'Every notice and meeting will be permanently deleted for all members. Scheduled meeting reminders will stop too. This cannot be undone.'
          : 'সব নোটিশ ও সভা সব সদস্যের কাছ থেকে স্থায়ীভাবে মুছে যাবে। সভার রিমাইন্ডারও বন্ধ হয়ে যাবে। এটি ফেরানো যাবে না।',
      confirmLabel: isEn ? 'Delete everything' : 'সব মুছুন',
    );
    if (!ok || !context.mounted) return;
    try {
      final n = await service.deleteAllNotices();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? '$n notices deleted' : '$n টি নোটিশ মুছে ফেলা হয়েছে'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.errorGeneric}: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(AppStrings.notices, style: AppTextStyles.h1),
                ),
                if (isAdmin)
                  TextButton.icon(
                    onPressed: () => _deleteAll(context, firestoreService),
                    icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                    label: Text(AppStrings.clearAll),
                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                  ),
              ],
            ),
            const SizedBox(height: AppDimensions.lg),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: firestoreService.watchAllNotices(),
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
                        AppStrings.noNotices,
                        style: AppTextStyles.bodyMedium,
                      ),
                    );
                  }

                  final notices = snapshot.data!.docs
                      .map(Notice.fromDoc)
                      .toList();

                  return ListView.separated(
                    itemCount: notices.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.md),
                    itemBuilder: (context, index) {
                      final notice = notices[index];
                      // Meetings, dated events and plain notices each get
                      // their own accent so the list reads at a glance
                      // instead of as one uniform stack of cards.
                      final accent = notice.isMeeting
                          ? AppColors.accentViolet
                          : (notice.isEvent ? AppColors.accentTeal : AppColors.primary);
                      final icon = notice.isMeeting
                          ? Icons.groups_rounded
                          : (notice.isEvent
                              ? Icons.event_rounded
                              : Icons.campaign_rounded);

                      return PremiumCard(
                        padding: EdgeInsets.zero,
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => NoticeDetailScreen(notice: notice),
                          ),
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppGradients.accentWash(accent),
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
                                        gradient: LinearGradient(
                                          colors: [accent, accent.withValues(alpha: 0.65)],
                                        ),
                                        borderRadius: BorderRadius.circular(
                                          AppDimensions.radiusSm,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: accent.withValues(alpha: 0.45),
                                            blurRadius: 12,
                                            offset: const Offset(0, 5),
                                          ),
                                        ],
                                      ),
                                      child: Icon(icon, size: 17, color: Colors.white),
                                    ),
                                    const SizedBox(width: AppDimensions.sm),
                                    Expanded(
                                      child: Text(notice.title, style: AppTextStyles.h3),
                                    ),
                                    if (isAdmin)
                                      IconButton(
                                        onPressed: () => _deleteOne(
                                          context, firestoreService, notice,
                                        ),
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          Icons.close_rounded,
                                          size: 18,
                                          color: AppColors.textSecondary,
                                        ),
                                        tooltip: LocaleService.isEnglish
                                            ? 'Delete notice'
                                            : 'নোটিশ মুছুন',
                                      ),
                                  ],
                                ),
                                if (notice.isMeeting || notice.isEvent) ...[
                                  const SizedBox(height: AppDimensions.sm),
                                  StatusBadge(
                                    label: notice.isMeeting
                                        ? (LocaleService.isEnglish ? 'Meeting' : 'সভা')
                                        : (LocaleService.isEnglish ? 'Event' : 'ইভেন্ট'),
                                    color: accent,
                                  ),
                                ],
                                const SizedBox(height: AppDimensions.sm),
                                Text(
                                  notice.body,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTextStyles.bodyMedium,
                                ),
                                const SizedBox(height: AppDimensions.sm),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    if (notice.eventDate != null)
                                      Row(
                                        children: [
                                          Icon(Icons.schedule_rounded, size: 13, color: accent),
                                          const SizedBox(width: 4),
                                          Text(
                                            _formatDateTime(notice.eventDate!, notice.isMeeting),
                                            style: AppTextStyles.caption.copyWith(
                                              color: accent,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      const SizedBox.shrink(),
                                    if (notice.createdAt != null)
                                      Text(
                                        _formatDate(notice.createdAt!),
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                  ],
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

  /// Meetings show the start time as well as the day — that's the detail
  /// that actually matters for one.
  String _formatDateTime(DateTime date, bool withTime) {
    final d = '${date.day}/${date.month}/${date.year}';
    if (!withTime) return d;
    final h = date.hour.toString().padLeft(2, '0');
    final m = date.minute.toString().padLeft(2, '0');
    return '$d · $h:$m';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return LocaleService.isEnglish ? 'Today' : 'আজ';
    }
    return '${date.day}/${date.month}/${date.year}';
  }
}
