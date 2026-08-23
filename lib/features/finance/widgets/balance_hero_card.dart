import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/utils/formatters.dart';

/// The premium gradient hero card showing total balance — the visual
/// centerpiece of the finance dashboard.
class BalanceHeroCard extends StatelessWidget {
  final double balance;
  final double income;
  final double expense;
  /// Overrides the "TOTAL FUND" eyebrow label — e.g. "TOTAL COLLECTED" on
  /// the admin dashboard, where this card sums all members' dues rather
  /// than a single member's own statement.
  final String? label;

  /// Member view: show a single centred figure — what this member has paid
  /// in — and drop the income/expense split. Association-wide totals aren't
  /// theirs and only make the number ambiguous ("is that mine or ours?").
  final bool personal;

  const BalanceHeroCard({
    super.key,
    required this.balance,
    required this.income,
    required this.expense,
    this.label,
    this.personal = false,
  });

  /// Member view: one centred figure, with wording that says plainly whose
  /// money it is and where it came from.
  Widget _personalBody() {
    final isEn = LocaleService.isEnglish;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.verified_rounded,
              color: Colors.white.withValues(alpha: 0.9),
              size: 18,
            ),
            const SizedBox(width: 8),
            Text(
              isEn ? 'TOTAL YOU HAVE PAID' : 'আপনি মোট যত টাকা দিয়েছেন',
              style: AppTextStyles.overline.copyWith(
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          Formatters.currency(income),
          style: AppTextStyles.amountLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.md),
        Text(
          isEn
              ? 'This is the total amount recorded against your name by the association. If something looks wrong, please contact the admin.'
              : 'সমিতির হিসাবে আপনার নামে জমা হওয়া মোট টাকার পরিমাণ এটি। কোনো গরমিল মনে হলে অ্যাডমিনের সাথে যোগাযোগ করুন।',
          textAlign: TextAlign.center,
          style: AppTextStyles.bodyMedium.copyWith(
            color: Colors.white.withValues(alpha: 0.82),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: AppGradients.heroCard,
        borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        border: Border.all(color: AppColors.glassBorderOnDark),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondaryDeep.withValues(alpha: 0.30),
            blurRadius: 28,
            offset: const Offset(0, 16),
          ),
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.22),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      // Glass sheen overlay (see AppGradients.glassSheen) layered above the
      // hero gradient so the card reads as lifted glass, not a flat fill.
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: AppGradients.glassSheen,
          borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: personal ? _personalBody() : Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.account_balance_wallet_rounded, color: Colors.white.withValues(alpha: 0.9), size: 18),
                  const SizedBox(width: 8),
                  Text(
                    label ?? (LocaleService.isEnglish ? 'TOTAL FUND' : 'মোট তহবিল'),
                    style: AppTextStyles.overline.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(Formatters.currency(balance), style: AppTextStyles.amountLarge),
              const SizedBox(height: AppDimensions.lg),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(height: AppDimensions.md),
              Row(
                children: [
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.arrow_downward_rounded,
                      label: AppStrings.totalCollected,
                      value: Formatters.currency(income),
                      color: const Color(0xFF86EFAC),
                    ),
                  ),
                  Container(width: 1, height: 36, color: Colors.white.withValues(alpha: 0.2)),
                  Expanded(
                    child: _MiniStat(
                      icon: Icons.arrow_upward_rounded,
                      label: AppStrings.totalExpense,
                      value: Formatters.currency(expense),
                      color: const Color(0xFFFCA5A5),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Text(label, style: AppTextStyles.caption.copyWith(color: Colors.white.withValues(alpha: 0.75))),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTextStyles.bodyLarge.copyWith(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}
