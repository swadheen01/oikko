import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/finance_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transaction.dart';
import '../../account_linking/widgets/sync_payment_card.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../widgets/balance_hero_card.dart';
import '../widgets/transaction_list_item.dart';

/// Finance screen (planning doc section 2 — "Financial Management &
/// Dashboard"), used in two modes:
/// - Admin (`isAdmin: true`): sees every transaction across all members and
///   the association-wide total. Adding a payment is reached via the
///   global "+" speed-dial FAB (`AdminSpeedDialFab`), not a FAB on this
///   screen specifically, since it needs to be reachable from every admin
///   tab, not just this one.
/// - Member (`isAdmin: false`, default): sees only their own dues/payments
///   — the "personal statement". Enforced both here (query is scoped to
///   `memberId`) and server-side by the `transactions` security rule, so a
///   member can never see another member's payment amounts.
class FinanceDashboardScreen extends StatelessWidget {
  final bool isAdmin;
  final String? memberId;

  /// False when the account isn't attached to a member record yet — there
  /// is no payment history to show, so this explains how to get one rather
  /// than displaying a misleading ৳0.
  final bool isLinked;

  const FinanceDashboardScreen({
    super.key,
    this.isAdmin = false,
    this.memberId,
    this.isLinked = true,
  }) : assert(isAdmin || memberId != null, 'memberId is required when isAdmin is false');

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

  Future<void> _confirmDeleteOne(
    BuildContext context,
    FinanceService service,
    AppTransaction transaction,
    String? memberName,
  ) async {
    final isEn = LocaleService.isEnglish;
    final who = (memberName != null && memberName.isNotEmpty)
        ? memberName
        : (transaction.description.isNotEmpty
            ? transaction.description
            : (isEn ? 'this record' : 'এই রেকর্ড'));

    final ok = await _confirm(
      context,
      title: isEn ? 'Delete this record?' : 'এই রেকর্ডটি মুছবেন?',
      message: isEn
          ? '${Formatters.currency(transaction.amount)} — $who\n\nThe totals will be recalculated without it. This cannot be undone.'
          : '${Formatters.currency(transaction.amount)} — $who\n\nএটি বাদ দিয়ে হিসাব আবার গণনা হবে। এটি ফেরানো যাবে না।',
      confirmLabel: isEn ? 'Delete' : 'মুছুন',
    );
    if (!ok || !context.mounted) return;

    try {
      await service.deleteTransaction(transaction.id);
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

  Future<void> _confirmClearAll(BuildContext context, FinanceService service) async {
    final isEn = LocaleService.isEnglish;
    final ok = await _confirm(
      context,
      title: isEn ? 'Clear all records?' : 'সব হিসাব মুছবেন?',
      message: isEn
          ? 'Every payment and expense will be permanently deleted and all totals reset to zero — for every member, not just one. This cannot be undone.'
          : 'সব পেমেন্ট ও খরচ স্থায়ীভাবে মুছে যাবে এবং সব হিসাব শূন্য হয়ে যাবে — শুধু একজনের নয়, সব সদস্যের। এটি ফেরানো যাবে না।',
      confirmLabel: isEn ? 'Delete everything' : 'সব মুছুন',
    );
    if (!ok || !context.mounted) return;

    try {
      final n = await service.deleteAllTransactions();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? '$n records deleted' : '$n টি রেকর্ড মুছে ফেলা হয়েছে'),
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
    if (!isAdmin && !isLinked) return const _NotLinkedFinanceView();
    if (!isAdmin) return _buildBody(context, const {});

    // Transactions store only a memberId, so the admin list would otherwise
    // show an amount and a reason with no indication of who paid it.
    // Resolving names from one members stream (rather than a lookup per
    // row) keeps this to a single extra query no matter how many payments
    // are listed.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().watchAllMembers(),
      builder: (context, snapshot) {
        final names = <String, String>{
          for (final doc in snapshot.data?.docs ?? const [])
            doc.id: (doc.data()['name'] as String?) ?? '',
        };
        return _buildBody(context, names);
      },
    );
  }

  Widget _buildBody(BuildContext context, Map<String, String> memberNames) {
    final financeService = FinanceService();

    return GradientScaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: isAdmin
            ? financeService.watchAllTransactions()
            : financeService.watchMemberTransactions(memberId!),
        builder: (context, snapshot) {
          // Without this, a failed query (a missing composite index is the
          // usual cause) renders as a perfectly normal-looking zero
          // balance — the totals briefly appear from cache, then vanish
          // with no indication anything went wrong.
          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, color: AppColors.danger, size: 40),
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      AppStrings.errorGeneric,
                      style: AppTextStyles.h3.copyWith(color: AppColors.danger),
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Text(
                      '${snapshot.error}',
                      style: AppTextStyles.caption,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: AppColors.primary));
          }

          final transactions =
              (snapshot.data?.docs ?? []).map(AppTransaction.fromDoc).toList();
          final income = FinanceService.totalIncome(transactions);
          final expense = FinanceService.totalExpense(transactions);
          final balance = FinanceService.balance(transactions);

          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.all(AppDimensions.lg),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Text(isAdmin ? AppStrings.finance : AppStrings.myStatement, style: AppTextStyles.h1),
                    const SizedBox(height: AppDimensions.md),
                    BalanceHeroCard(
                      balance: balance,
                      income: income,
                      expense: expense,
                      label: isAdmin ? AppStrings.totalNetAmount : null,
                      personal: !isAdmin,
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            isAdmin ? AppStrings.allTransactions : AppStrings.myStatement,
                            style: AppTextStyles.h3,
                          ),
                        ),
                        if (isAdmin && transactions.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _confirmClearAll(context, financeService),
                            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                            label: Text(AppStrings.clearAll),
                            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                  ]),
                ),
              ),
              if (transactions.isEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(AppDimensions.xl),
                    child: Center(
                      child: Text(AppStrings.noTransactions, style: AppTextStyles.bodyMedium),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppDimensions.lg, 0, AppDimensions.lg, AppDimensions.xxl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                        child: TransactionListItem(
                          transaction: transactions[index],
                          // Only the admin view mixes members together, so
                          // only it needs the payer's name; a member's own
                          // statement is all their own payments already.
                          memberName: isAdmin
                              ? memberNames[transactions[index].memberId]
                              : null,
                          onDelete: isAdmin
                              ? () => _confirmDeleteOne(
                                    context,
                                    financeService,
                                    transactions[index],
                                    memberNames[transactions[index].memberId],
                                  )
                              : null,
                        ),
                      ),
                      childCount: transactions.length,
                    ),
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.xl)),
            ],
          );
        },
      ),
    );
  }
}

/// Shown on the finance tab while the account has no member record. A ৳0
/// balance here would be a lie — there is no statement yet, rather than an
/// empty one — so this explains why and links to the fix.
class _NotLinkedFinanceView extends StatelessWidget {
  const _NotLinkedFinanceView();

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;

    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.myStatement, style: AppTextStyles.h1),
            const SizedBox(height: AppDimensions.md),
            Text(
              isEn
                  ? 'Your account isn\'t connected to a member record yet, so there\'s no payment history to show.'
                  : 'আপনার একাউন্টটি এখনো কোনো সদস্য রেকর্ডের সাথে যুক্ত হয়নি, তাই এখানে দেখানোর মতো কোনো হিসাব নেই।',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.lg),
            const SyncPaymentCard(),
          ],
        ),
      ),
    );
  }
}
