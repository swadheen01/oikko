import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/welfare_request.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';
import '../../../widgets/status_badge.dart';

class WelfareListScreen extends StatelessWidget {
  final String? userMemberId;

  const WelfareListScreen({super.key, this.userMemberId});

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return GradientScaffold(
      body: Padding(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.welfare, style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.lg),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: userMemberId != null
                    ? firestoreService.watchUserWelfareRequests(userMemberId!)
                    : firestoreService.watchWelfareRequests(),
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
                      .toList();

                  return ListView.separated(
                    itemCount: requests.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(height: AppDimensions.md),
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      final statusColor = _getStatusColor(request.status);

                      return PremiumCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    request.reason,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTextStyles.h3,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.sm),
                                StatusBadge(
                                  label: _getStatusLabel(request.status),
                                  color: statusColor,
                                ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            Text(
                              Formatters.currency(request.amountRequested),
                              style: AppTextStyles.amountMedium.copyWith(
                                color: AppColors.primary,
                                fontSize: 20,
                              ),
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

  String _getStatusLabel(RequestStatus status) {
    if (LocaleService.isEnglish) {
      switch (status) {
        case RequestStatus.pending:
          return 'Pending';
        case RequestStatus.approved:
          return 'Approved';
        case RequestStatus.rejected:
          return 'Rejected';
      }
    }
    switch (status) {
      case RequestStatus.pending:
        return 'অপেক্ষমাণ';
      case RequestStatus.approved:
        return 'অনুমোদিত';
      case RequestStatus.rejected:
        return 'প্রত্যাখ্যাত';
    }
  }

  Color _getStatusColor(RequestStatus status) {
    switch (status) {
      case RequestStatus.pending:
        return AppColors.warning;
      case RequestStatus.approved:
        return AppColors.success;
      case RequestStatus.rejected:
        return AppColors.danger;
    }
  }
}
