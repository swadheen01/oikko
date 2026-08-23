import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/link_request.dart';
import '../screens/find_profile_screen.dart';

/// The "connect your Member ID to see your payments" prompt.
///
/// Shown on the home screen and on the finance tab for as long as the
/// account isn't attached to a member record. Deliberately persistent: it's
/// the only route from a signed-in-but-unlinked account to its payment
/// history, so hiding it would strand the user.
///
/// A pending request doesn't lock the prompt forever. If an admin hasn't
/// acted within a day the request is treated as stale and the connect
/// action comes back, so a missed or rejected-by-silence request can't
/// leave someone permanently stuck waiting.
class SyncPaymentCard extends StatelessWidget {
  /// How long a pending request stays "in progress" before the user is
  /// allowed to submit another one.
  static const Duration retryAfter = Duration(days: 1);

  final String currentPhone;

  /// Slightly denser layout for the home screen, where this sits above the
  /// directory rather than being the whole page.
  final bool compact;

  const SyncPaymentCard({
    super.key,
    this.currentPhone = '',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().watchMyPendingLinkRequest(uid),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final request = docs.isEmpty ? null : LinkRequest.fromDoc(docs.first);

        // A request with no server timestamp yet (write still in flight)
        // counts as fresh rather than stale.
        final requestedAt = request?.requestedAt;
        final isWaiting = request != null &&
            (requestedAt == null ||
                DateTime.now().difference(requestedAt) < retryAfter);

        return _Card(
          uid: uid,
          currentPhone: currentPhone,
          compact: compact,
          isWaiting: isWaiting,
          canRetry: request != null && !isWaiting,
        );
      },
    );
  }
}

class _Card extends StatelessWidget {
  final String uid;
  final String currentPhone;
  final bool compact;
  final bool isWaiting;
  final bool canRetry;

  const _Card({
    required this.uid,
    required this.currentPhone,
    required this.compact,
    required this.isWaiting,
    required this.canRetry,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;
    final accent = isWaiting ? AppColors.warning : AppColors.primary;

    final String title;
    final String body;
    if (isWaiting) {
      title = isEn ? 'Waiting for admin approval' : 'অ্যাডমিনের অনুমোদনের অপেক্ষায়';
      body = isEn
          ? 'Your request has been sent. Once an admin approves it, your payment history appears here automatically. If nothing happens within a day, you can send it again.'
          : 'আপনার অনুরোধ পাঠানো হয়েছে। অ্যাডমিন অনুমোদন করলেই আপনার পেমেন্টের হিসাব এখানে দেখা যাবে। একদিনেও কিছু না হলে আবার পাঠাতে পারবেন।';
    } else if (canRetry) {
      title = isEn ? 'Still not approved' : 'এখনো অনুমোদন হয়নি';
      body = isEn
          ? 'Your earlier request hasn\'t been approved yet. You can send it again, or check the Member ID with your admin.'
          : 'আপনার আগের অনুরোধটি এখনো অনুমোদন হয়নি। আবার পাঠাতে পারেন, অথবা অ্যাডমিনের কাছে সদস্য আইডিটি মিলিয়ে নিন।';
    } else {
      title = isEn ? 'Sync your payment info' : 'পেমেন্ট তথ্য সিঙ্ক করুন';
      body = isEn
          ? 'Enter the Member ID your admin gave you to connect this account. Your dues and payment history will then show up under Finance.'
          : 'অ্যাডমিনের দেওয়া সদস্য আইডি দিয়ে এই একাউন্টটি যুক্ত করুন। এরপর আপনার চাঁদা ও পেমেন্টের হিসাব "হিসাব" ট্যাবে দেখা যাবে।';
    }

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? AppDimensions.md : AppDimensions.lg),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: accent.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                isWaiting ? Icons.hourglass_top_rounded : Icons.sync_rounded,
                color: accent,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(body, style: AppTextStyles.bodyMedium),
                  ],
                ),
              ),
            ],
          ),
          // Hidden only while a request is genuinely still in progress.
          if (!isWaiting) ...[
            const SizedBox(height: AppDimensions.md),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => FindProfileScreen(
                      currentUserUid: uid,
                      currentPhone: currentPhone,
                    ),
                  ),
                ),
                icon: const Icon(Icons.link_rounded, size: 18),
                label: Text(
                  canRetry ? (LocaleService.isEnglish ? 'Try again' : 'আবার চেষ্টা করুন')
                           : AppStrings.connectWithId,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
