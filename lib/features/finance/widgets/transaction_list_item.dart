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

  /// Action on tapping this transaction item. In the admin overview, tapping
  /// opens that member's full payment statement. If null, tapping displays a
  /// detail sheet.
  final VoidCallback? onTap;

  const TransactionListItem({
    super.key,
    required this.transaction,
    this.memberName,
    this.onDelete,
    this.onTap,
  });

  bool get _isCredit =>
      transaction.type == TransactionType.income ||
      transaction.type == TransactionType.duePayment;

  String get _typeLabel {
    final isEn = LocaleService.isEnglish;
    if (transaction.donorName != null && transaction.donorName!.isNotEmpty) {
      return isEn ? 'Donation' : 'অনুদান';
    }
    if (transaction.category != null && transaction.category!.isNotEmpty) {
      return transaction.category!;
    }
    switch (transaction.type) {
      case TransactionType.income:
        return isEn ? 'Income' : 'আয়';
      case TransactionType.expense:
        return isEn ? 'Expense' : 'ব্যয়';
      case TransactionType.withdrawal:
        return isEn ? 'Withdrawal' : 'টাকা উত্তোলন';
      case TransactionType.duePayment:
        return isEn ? 'Dues' : 'চাঁদা জমা';
    }
  }

  void _showDetail(BuildContext context) {
    final isEn = LocaleService.isEnglish;
    final color = _isCredit ? AppColors.success : AppColors.danger;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.radiusLg),
        ),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusPill,
                      ),
                    ),
                    child: Text(
                      _typeLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${_isCredit ? '+' : '-'} ${Formatters.currency(transaction.amount)}',
                    style: AppTextStyles.amountLarge.copyWith(
                      color: color,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              const Divider(),
              const SizedBox(height: AppDimensions.sm),
              if (transaction.donorName != null && transaction.donorName!.isNotEmpty) ...[
                _detailRow(
                  icon: Icons.volunteer_activism_rounded,
                  label: isEn ? 'Donor' : 'দাতার নাম',
                  value: transaction.donorName!,
                ),
                const SizedBox(height: AppDimensions.sm),
              ],
              if (memberName != null && memberName!.isNotEmpty) ...[
                _detailRow(
                  icon: Icons.person_rounded,
                  label: isEn ? 'Member' : 'সদস্য',
                  value: memberName!,
                ),
                const SizedBox(height: AppDimensions.sm),
              ],
              if (transaction.schoolName != null && transaction.schoolName!.isNotEmpty) ...[
                _detailRow(
                  icon: Icons.school_rounded,
                  label: isEn ? 'School' : 'বিদ্যালয়',
                  value: transaction.schoolName!,
                ),
                const SizedBox(height: AppDimensions.sm),
              ],
              if (transaction.category != null && transaction.category!.isNotEmpty) ...[
                _detailRow(
                  icon: Icons.category_rounded,
                  label: isEn ? 'Category' : 'খাত',
                  value: transaction.category!,
                ),
                const SizedBox(height: AppDimensions.sm),
              ],
              _detailRow(
                icon: Icons.calendar_today_rounded,
                label: isEn ? 'Payment date' : 'তারিখ',
                value: Formatters.date(transaction.date),
              ),
              if (transaction.description.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.sm),
                _detailRow(
                  icon: Icons.description_rounded,
                  label: isEn ? 'Details / Remarks' : 'বিবরণ',
                  value: transaction.description,
                ),
              ],
              const SizedBox(height: AppDimensions.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusMd,
                      ),
                    ),
                  ),
                  child: Text(isEn ? 'Close' : 'বন্ধ করুন'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _detailRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: AppColors.primary),
        const SizedBox(width: AppDimensions.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String get _title {
    if (transaction.donorName != null && transaction.donorName!.isNotEmpty) {
      return 'অনুদান: ${transaction.donorName}';
    }
    if (memberName != null && memberName!.isNotEmpty) {
      return memberName!;
    }
    if (transaction.schoolName != null && transaction.schoolName!.isNotEmpty) {
      return transaction.schoolName!;
    }
    if (transaction.description.isNotEmpty) {
      return transaction.description;
    }
    return _typeLabel;
  }

  String? get _subtitle {
    if (transaction.donorName != null && transaction.donorName!.isNotEmpty) {
      return transaction.description.isNotEmpty ? transaction.description : null;
    }
    if (memberName != null && memberName!.isNotEmpty) {
      if (transaction.schoolName != null && transaction.schoolName!.isNotEmpty) {
        return transaction.description.isNotEmpty
            ? '${transaction.schoolName} • ${transaction.description}'
            : transaction.schoolName;
      }
      return transaction.description.isNotEmpty ? transaction.description : null;
    }
    if (transaction.schoolName != null && transaction.schoolName!.isNotEmpty) {
      return transaction.description.isNotEmpty ? transaction.description : null;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final color = _isCredit ? AppColors.success : AppColors.danger;
    final sub = _subtitle;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        onTap: onTap ?? () => _showDetail(context),
        child: PremiumCard(
          radius: AppDimensions.radiusMd,
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  transaction.donorName != null && transaction.donorName!.isNotEmpty
                      ? Icons.volunteer_activism_rounded
                      : (transaction.schoolName != null && transaction.memberId == null
                          ? Icons.school_rounded
                          : (_isCredit ? Icons.add_rounded : Icons.remove_rounded)),
                  color: color,
                ),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (sub != null && sub.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        style: AppTextStyles.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          size: 12,
                          color: AppColors.textSecondary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          Formatters.date(transaction.date),
                          style: AppTextStyles.caption.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _typeLabel,
                            style: AppTextStyles.caption.copyWith(
                              fontSize: 10,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_isCredit ? '+' : '-'} ${Formatters.currency(transaction.amount)}',
                style: AppTextStyles.amountMedium.copyWith(
                  color: color,
                  fontSize: 16,
                ),
              ),
              if (onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  tooltip: LocaleService.isEnglish
                      ? 'Delete record'
                      : 'রেকর্ড মুছুন',
                )
              else if (onTap != null)
                Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
