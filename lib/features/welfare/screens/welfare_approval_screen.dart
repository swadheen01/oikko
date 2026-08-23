import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/welfare_request.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

class WelfareApprovalScreen extends StatelessWidget {
  const WelfareApprovalScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              LocaleService.isEnglish ? 'Review welfare requests' : 'কল্যাণ অনুরোধ পর্যালোচনা',
              style: AppTextStyles.h1,
            ),
            const SizedBox(height: AppDimensions.lg),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: firestoreService.watchWelfareRequests(),
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
                        LocaleService.isEnglish ? 'No requests yet' : 'কোনো অনুরোধ নেই',
                        style: AppTextStyles.bodyMedium,
                      ),
                    );
                  }

                  final requests = snapshot.data!.docs
                      .map(WelfareRequest.fromDoc)
                      .where((r) => r.status == RequestStatus.pending)
                      .toList();

                  if (requests.isEmpty) {
                    return Center(
                      child: Text(
                        LocaleService.isEnglish
                            ? 'All requests have been reviewed'
                            : 'সকল অনুরোধ পর্যালোচনা করা হয়েছে',
                        style: AppTextStyles.bodyMedium,
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.md),
                    itemBuilder: (context, index) {
                      final request = requests[index];

                      return PremiumCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(request.reason, style: AppTextStyles.h3),
                            const SizedBox(height: AppDimensions.sm),
                            Text(
                              Formatters.currency(request.amountRequested),
                              style: AppTextStyles.amountMedium.copyWith(
                                color: AppColors.primary,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.md),
                            Row(
                              children: [
                                Expanded(
                                  child: _ActionButton(
                                    label: LocaleService.isEnglish ? 'Approve' : 'অনুমোদন',
                                    icon: Icons.check_rounded,
                                    color: AppColors.success,
                                    onTap: () async {
                                      await firestoreService
                                          .updateWelfareRequest(
                                            requestId: request.id,
                                            status: RequestStatus.approved.name,
                                            reviewedBy: FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.uid,
                                          );
                                      unawaited(NotificationService().sendToMember(
                                        memberId: request.memberId,
                                        title: LocaleService.isEnglish
                                            ? 'Welfare request approved'
                                            : 'কল্যাণ অনুরোধ অনুমোদিত হয়েছে',
                                        body: request.reason,
                                      ));
                                    },
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.md),
                                Expanded(
                                  child: _ActionButton(
                                    label: LocaleService.isEnglish ? 'Reject' : 'প্রত্যাখ্যান',
                                    icon: Icons.close_rounded,
                                    color: AppColors.danger,
                                    onTap: () async {
                                      await firestoreService
                                          .updateWelfareRequest(
                                            requestId: request.id,
                                            status: RequestStatus.rejected.name,
                                            reviewedBy: FirebaseAuth
                                                .instance
                                                .currentUser
                                                ?.uid,
                                          );
                                      unawaited(NotificationService().sendToMember(
                                        memberId: request.memberId,
                                        title: LocaleService.isEnglish
                                            ? 'Welfare request rejected'
                                            : 'কল্যাণ অনুরোধ প্রত্যাখ্যাত হয়েছে',
                                        body: request.reason,
                                      ));
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
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

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
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(color: color, fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
