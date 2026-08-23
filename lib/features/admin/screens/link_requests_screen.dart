import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/link_request.dart';
import '../../../models/member.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

/// Admin-only: approve or reject "connect my account to this member"
/// requests — the other half of the member-ID linking flow started on
/// FindProfileScreen. Closes the previously-unconsumed
/// `watchPendingLinkRequests()` gap.
class LinkRequestsScreen extends StatelessWidget {
  const LinkRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.linkRequests, style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: firestoreService.watchPendingLinkRequests(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return Center(child: CircularProgressIndicator(color: AppColors.primary));
                  }

                  final requests = (snapshot.data?.docs ?? []).map(LinkRequest.fromDoc).toList();

                  if (requests.isEmpty) {
                    return Center(
                      child: Text(AppStrings.allRequestsReviewed, style: AppTextStyles.bodyMedium),
                    );
                  }

                  return ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.md),
                    itemBuilder: (context, index) => _LinkRequestCard(
                      request: requests[index],
                      firestoreService: firestoreService,
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LinkRequestCard extends StatelessWidget {
  final LinkRequest request;
  final FirestoreService firestoreService;

  const _LinkRequestCard({required this.request, required this.firestoreService});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: firestoreService.collection(FirestorePaths.members).doc(request.memberId).get(),
      builder: (context, snapshot) {
        final member = snapshot.hasData && snapshot.data!.exists
            ? Member.fromDoc(snapshot.data!)
            : null;

        return PremiumCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                    backgroundImage: (member?.photoUrl.isNotEmpty ?? false) ? NetworkImage(member!.photoUrl) : null,
                    child: (member?.photoUrl.isEmpty ?? true)
                        ? Text(
                            member != null && member.name.isNotEmpty ? member.name.characters.first : '?',
                            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.primary, fontWeight: FontWeight.w700),
                          )
                        : null,
                  ),
                  const SizedBox(width: AppDimensions.sm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member?.name ?? (LocaleService.isEnglish ? 'Unknown member' : 'অজানা সদস্য'),
                          style: AppTextStyles.h3,
                        ),
                        if (member?.schoolName.isNotEmpty ?? false)
                          Text(member!.schoolName, style: AppTextStyles.caption),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.sm),
              // Who is asking to claim this member record — the whole point
              // of the review. Falls back to the raw uid so the card is
              // never completely anonymous (older requests predate the
              // requestedEmail field).
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      LocaleService.isEnglish ? 'Requested by' : 'অনুরোধকারী',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      request.requestedEmail.isNotEmpty
                          ? request.requestedEmail
                          : (LocaleService.isEnglish
                              ? 'Account ${request.requestedByUid}'
                              : 'একাউন্ট ${request.requestedByUid}'),
                      style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (request.requestedPhone.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${AppStrings.requestedPhone}: ${request.requestedPhone}',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Expanded(
                    child: _ActionButton(
                      label: AppStrings.approve,
                      icon: Icons.check_rounded,
                      color: AppColors.success,
                      onTap: () async {
                        try {
                          await firestoreService.approveLinkRequest(
                            requestId: request.id,
                            memberId: request.memberId,
                            requestedByUid: request.requestedByUid,
                            reviewedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${LocaleService.isEnglish ? 'Approve failed' : 'অনুমোদন ব্যর্থ হয়েছে'}: $e')),
                            );
                          }
                          return;
                        }
                        // Best-effort: the requester's device may not be
                        // subscribed to this member's topic yet (that only
                        // happens once *this* member doc is the one they're
                        // linked to) — if they haven't reopened the app
                        // since requesting, this simply reaches no one,
                        // which is harmless.
                        try {
                          await NotificationService().sendToMember(
                            memberId: request.memberId,
                            title: LocaleService.isEnglish
                                ? 'Account connected'
                                : 'একাউন্ট সংযুক্ত হয়েছে',
                            body: LocaleService.isEnglish
                                ? 'Your payment history is now synced.'
                                : 'আপনার পেমেন্ট তথ্য এখন সিঙ্ক হয়েছে।',
                          );
                        } catch (_) {
                          // Non-fatal — the link itself already succeeded.
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: AppDimensions.md),
                  Expanded(
                    child: _ActionButton(
                      label: AppStrings.reject,
                      icon: Icons.close_rounded,
                      color: AppColors.danger,
                      onTap: () async {
                        try {
                          await firestoreService.rejectLinkRequest(
                            requestId: request.id,
                            reviewedBy: FirebaseAuth.instance.currentUser?.uid ?? '',
                          );
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('${LocaleService.isEnglish ? 'Reject failed' : 'প্রত্যাখ্যান ব্যর্থ হয়েছে'}: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: AppTextStyles.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
