import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transaction.dart';
import '../../../widgets/premium_card.dart';

class TransactionListItem extends StatelessWidget {
  final AppTransaction transaction;

  /// Who this payment belongs to. Passed only by the admin view, where the
  /// list mixes every member together and the amount alone doesn't say who
  /// paid it. Null on a member's own statement (all rows are theirs).
  final String? memberName;

  /// Admin-only. Totals are a plain sum of this collection, so removing a
  /// row is how a mistyped amount gets corrected.
  final VoidCallback? onDelete;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.memberName,
    this.onDelete,
  });

  bool get _isCredit =>
      transaction.type == TransactionType.income || transaction.type == TransactionType.duePayment;

  String get _typeLabel {
    switch (transaction.type) {
      case TransactionType.income:
        return 'আয়';
      case TransactionType.expense:
        return 'ব্যয়';
      case TransactionType.duePayment:
        return 'চাঁদা জমা';
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _isCredit ? AppColors.success : AppColors.danger;

    return PremiumCard(
      radius: AppDimensions.radiusMd,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: Icon(
              _isCredit ? Icons.add_rounded : Icons.remove_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: AppDimensions.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // In the admin view the payer's name is the primary thing
                // to read; the reason becomes the secondary line.
                Text(
                  (memberName != null && memberName!.isNotEmpty)
                      ? memberName!
                      : (transaction.description.isNotEmpty
                          ? transaction.description
                          : _typeLabel),
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (memberName != null &&
                    memberName!.isNotEmpty &&
                    transaction.description.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    transaction.description,
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 2),
                Text(Formatters.date(transaction.date), style: AppTextStyles.caption),
              ],
            ),
          ),
          Text(
            '${_isCredit ? '+' : '-'} ${Formatters.currency(transaction.amount)}',
            style: AppTextStyles.amountMedium.copyWith(color: color, fontSize: 16),
          ),
          if (onDelete != null)
            IconButton(
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: AppColors.textSecondary),
              tooltip: LocaleService.isEnglish ? 'Delete record' : 'রেকর্ড মুছুন',
            ),
        ],
      ),
    );
  }
}
