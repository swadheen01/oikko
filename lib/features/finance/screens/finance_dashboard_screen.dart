import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/finance_pdf_service.dart';
import '../../../core/services/finance_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/member.dart';
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
class FinanceDashboardScreen extends StatefulWidget {
  final bool isAdmin;
  final String? memberId;

  /// The member's own name / ID, used only to title their PDF statement.
  final String memberName;
  final String memberCode;

  /// False when the account isn't attached to a member record yet — there
  /// is no payment history to show, so this explains how to get one rather
  /// than displaying a misleading ৳0.
  final bool isLinked;

  /// The admin's *own* member id/name/code — an admin is a teacher too, so
  /// alongside the association-wide total this screen can also show the
  /// admin's personal dues, the same statement an ordinary member sees.
  /// Null/empty when the admin account has no linked member record, in
  /// which case the personal toggle simply doesn't appear.
  final String? personalMemberId;
  final String personalMemberName;
  final String personalMemberCode;

  /// True when an admin is inspecting another member's statement.
  final bool isViewerAdmin;

  const FinanceDashboardScreen({
    super.key,
    this.isAdmin = false,
    this.memberId,
    this.memberName = '',
    this.memberCode = '',
    this.isLinked = true,
    this.personalMemberId,
    this.personalMemberName = '',
    this.personalMemberCode = '',
    this.isViewerAdmin = false,
  }) : assert(isAdmin || memberId != null, 'memberId is required when isAdmin is false');

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  final _financeService = FinanceService();

  // When an admin (who also has their own member record) switches to "My
  // statement", the screen behaves exactly like an ordinary member's finance
  // tab — scoped to their own transactions, read-only, no clear-all.
  bool _showPersonal = false;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream =
      FirestoreService().watchAllMembers();

  // The transaction stream depends on the personal/total toggle, so unlike
  // the other cached streams in this app it's rebuilt on demand rather than
  // fixed at construction — but still only when the mode actually changes,
  // not on every build (the same flicker/scroll-reset problem otherwise).
  Stream<QuerySnapshot<Map<String, dynamic>>>? _txStream;
  bool? _txStreamIsAdmin;
  Stream<QuerySnapshot<Map<String, dynamic>>> get _currentTxStream {
    if (_txStreamIsAdmin != isAdmin || _txStream == null) {
      _txStreamIsAdmin = isAdmin;
      _txStream = isAdmin
          ? _financeService.watchAllTransactions()
          : _financeService.watchMemberTransactions(memberId!);
    }
    return _txStream!;
  }

  /// Once a Firestore listener errors (e.g. a transient permission-denied
  /// right at the moment an account gets linked, before the write has fully
  /// propagated), it terminates for good — Firestore does not retry a dead
  /// subscription on its own. Without this, the cached `_txStream` would
  /// keep returning that same dead stream forever, leaving the error on
  /// screen permanently. Called from the error state's retry button to
  /// force a fresh subscription.
  void _retryTxStream() {
    setState(() {
      _txStream = null;
      _txStreamIsAdmin = null;
    });
  }

  bool get isAdmin => widget.isAdmin && !_showPersonal;
  bool get canShowPersonalToggle =>
      widget.isAdmin && (widget.personalMemberId?.isNotEmpty ?? false);
  String? get memberId => _showPersonal ? widget.personalMemberId : widget.memberId;
  String get memberName => _showPersonal ? widget.personalMemberName : widget.memberName;
  String get memberCode => _showPersonal ? widget.personalMemberCode : widget.memberCode;
  bool get isLinked => widget.isLinked;

  Future<void> _sharePdf(
    BuildContext context, {
    required List<AppTransaction> transactions,
    required Map<String, String> memberNames,
  }) async {
    final isEn = LocaleService.isEnglish;
    try {
      if (isAdmin) {
        await FinancePdfService.shareAdminSummary(
          transactions: transactions,
          memberNames: memberNames,
        );
      } else {
        await FinancePdfService.shareMemberStatement(
          transactions: transactions,
          memberName: memberName.isNotEmpty
              ? memberName
              : (isEn ? 'Member' : 'সদস্য'),
          memberCode: memberCode,
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${isEn ? 'Could not create PDF' : 'পিডিএফ তৈরি করা যায়নি'}: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

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
    if (!isAdmin && !isLinked && !widget.isViewerAdmin) return const _NotLinkedFinanceView();
    if (!isAdmin) return _buildBody(context, const {}, const {});

    // Transactions store only a memberId, so the admin list would otherwise
    // show an amount and a reason with no indication of who paid it.
    // Resolving names from one members stream (rather than a lookup per
    // row) keeps this to a single extra query no matter how many payments
    // are listed.
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _membersStream,
      builder: (context, snapshot) {
        final membersMap = <String, Member>{
          for (final doc in snapshot.data?.docs ?? const [])
            doc.id: Member.fromDoc(doc),
        };
        final names = <String, String>{
          for (final entry in membersMap.entries)
            entry.key: entry.value.name,
        };
        return _buildBody(context, names, membersMap);
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    Map<String, String> memberNames, [
    Map<String, Member> membersMap = const {},
  ]) {
    final financeService = _financeService;

    return GradientScaffold(
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _currentTxStream,
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
                    const SizedBox(height: AppDimensions.lg),
                    // A dead Firestore listener never recovers on its own —
                    // this forces a fresh subscription instead of leaving
                    // the error on screen until the app is fully restarted.
                    TextButton.icon(
                      onPressed: _retryTxStream,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(LocaleService.isEnglish ? 'Try again' : 'আবার চেষ্টা করুন'),
                      style: TextButton.styleFrom(foregroundColor: AppColors.primary),
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
                    if (Navigator.of(context).canPop()) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded),
                          style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.sm),
                    ],
                    Text(
                      widget.isViewerAdmin
                          ? (LocaleService.isEnglish
                              ? '${widget.memberName} — Statement'
                              : '${widget.memberName} — হিসাব')
                          : (isAdmin ? AppStrings.finance : AppStrings.myStatement),
                      style: AppTextStyles.h1,
                    ),
                    if (widget.isViewerAdmin && widget.memberCode.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        LocaleService.isEnglish
                            ? 'Member ID: ${widget.memberCode}'
                            : 'সদস্য আইডি: ${widget.memberCode}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                    // An admin is a teacher too — this switches between the
                    // association-wide total and their own personal dues,
                    // the same statement an ordinary member sees.
                    if (canShowPersonalToggle) ...[
                      const SizedBox(height: AppDimensions.md),
                      _PersonalToggle(
                        showPersonal: _showPersonal,
                        onChanged: (v) => setState(() => _showPersonal = v),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.md),
                    BalanceHeroCard(
                      balance: balance,
                      income: income,
                      expense: expense,
                      label: isAdmin ? AppStrings.totalNetAmount : null,
                      personal: !isAdmin,
                      personalTitle: widget.isViewerAdmin
                          ? (LocaleService.isEnglish ? 'TOTAL PAID BY MEMBER' : 'সদস্যের মোট জমা')
                          : null,
                      personalSubtitle: widget.isViewerAdmin
                          ? (LocaleService.isEnglish
                              ? 'Total payments and dues recorded for ${widget.memberName}.'
                              : '${widget.memberName}-এর নামে সমিতিতে জমা হওয়া মোট টাকা।')
                          : null,
                    ),
                    const SizedBox(height: AppDimensions.lg),
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.isViewerAdmin
                                    ? (LocaleService.isEnglish ? 'Payment records' : 'পেমেন্ট বিবরণী')
                                    : (isAdmin ? AppStrings.allTransactions : AppStrings.myStatement),
                                style: AppTextStyles.h3,
                              ),
                              if (transactions.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  LocaleService.isEnglish
                                      ? '${transactions.length} record${transactions.length == 1 ? '' : 's'}'
                                      : '${transactions.length} টি পেমেন্ট',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Share a PDF of the summary (admin) or the member's
                        // own statement — the shareable financial document.
                        if (transactions.isNotEmpty)
                          TextButton.icon(
                            onPressed: () => _sharePdf(
                              context,
                              transactions: transactions,
                              memberNames: memberNames,
                            ),
                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                            label: Text(LocaleService.isEnglish ? 'PDF' : 'পিডিএফ'),
                            style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                          ),
                        // Wiping every payment record is irreversible and
                        // affects every member, but every admin has equal,
                        // full power now — no protected tier reserves this.
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
                      (context, index) {
                        final tx = transactions[index];
                        final mId = tx.memberId;
                        final payerMember = mId != null ? membersMap[mId] : null;
                        final payerName = isAdmin
                            ? (payerMember?.name ?? memberNames[mId])
                            : null;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                          child: TransactionListItem(
                            transaction: tx,
                            memberName: payerName,
                            onTap: (isAdmin && mId != null && mId.isNotEmpty)
                                ? () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => FinanceDashboardScreen(
                                          isAdmin: false,
                                          isViewerAdmin: true,
                                          memberId: mId,
                                          memberName: payerMember?.name ?? memberNames[mId] ?? '',
                                          memberCode: payerMember?.memberCode ?? '',
                                        ),
                                      ),
                                    );
                                  }
                                : null,
                            onDelete: (isAdmin || widget.isViewerAdmin)
                                ? () => _confirmDeleteOne(
                                      context,
                                      financeService,
                                      tx,
                                      isAdmin ? payerName : widget.memberName,
                                    )
                                : null,
                          ),
                        );
                      },
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

/// Two-way switch between the association-wide total and the admin's own
/// personal statement, shown only when the admin has a linked member record.
class _PersonalToggle extends StatelessWidget {
  final bool showPersonal;
  final ValueChanged<bool> onChanged;

  const _PersonalToggle({required this.showPersonal, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ToggleSegment(
              label: isEn ? 'Total finance' : 'মোট হিসাব',
              selected: !showPersonal,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _ToggleSegment(
              label: isEn ? 'My finance' : 'আমার হিসাব',
              selected: showPersonal,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _ToggleSegment extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ToggleSegment({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: selected ? AppColors.textOnPrimary : AppColors.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
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
