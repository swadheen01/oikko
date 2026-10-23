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
import '../../../widgets/premium_card.dart';
import '../widgets/balance_hero_card.dart';
import '../widgets/transaction_list_item.dart';
import 'add_expense_screen.dart';
import 'add_payment_screen.dart';

enum FinanceTab { all, schools, donations, expenses }

/// Finance screen (planning doc section 2 — "Financial Management &
/// Dashboard"), used in two modes:
/// - Admin (`isAdmin: true`): sees every transaction across all members,
///   school-wise statements & PDFs, donations, and association expenses.
/// - Member (`isAdmin: false`, default): sees only their own dues/payments
///   — the "personal statement".
class FinanceDashboardScreen extends StatefulWidget {
  final bool isAdmin;
  final String? memberId;

  /// The member's own name / ID, used only to title their PDF statement.
  final String memberName;
  final String memberCode;

  /// False when the account isn't attached to a member record yet.
  final bool isLinked;

  /// The admin's *own* member id/name/code.
  final String? personalMemberId;
  final String personalMemberName;
  final String personalMemberCode;

  /// True when an admin is inspecting another member's statement.
  final bool isViewerAdmin;

  /// Full member model if known, so actions like Add Payment have complete data.
  final Member? targetMember;

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
    this.targetMember,
  }) : assert(isAdmin || memberId != null, 'memberId is required when isAdmin is false');

  @override
  State<FinanceDashboardScreen> createState() => _FinanceDashboardScreenState();
}

class _FinanceDashboardScreenState extends State<FinanceDashboardScreen> {
  final _financeService = FinanceService();

  bool _showPersonal = false;
  FinanceTab _activeTab = FinanceTab.all;
  String _schoolSearchQuery = '';

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _membersStream =
      FirestoreService().watchAllMembers();

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

  void _showSchoolStatementSheet(
    BuildContext context,
    SchoolFinanceSummary summary,
    Map<String, String> memberNames,
  ) {
    final isEn = LocaleService.isEnglish;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppDimensions.radiusXl),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: AppDimensions.sm),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppDimensions.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(summary.schoolName, style: AppTextStyles.h2),
                          const SizedBox(height: 2),
                          Text(
                            isEn
                                ? '${summary.memberCount} teachers • ${summary.transactions.length} records'
                                : '${summary.memberCount} জন শিক্ষক • ${summary.transactions.length} টি লেনদেন',
                            style: AppTextStyles.caption,
                          ),
                        ],
                      ),
                    ),
                    if (summary.transactions.isNotEmpty)
                      FilledButton.icon(
                        onPressed: () => FinancePdfService.shareSchoolStatement(
                          schoolName: summary.schoolName,
                          transactions: summary.transactions,
                          memberNames: memberNames,
                        ),
                        icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                        label: Text(isEn ? 'PDF' : 'পিডিএফ'),
                        style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
                child: Row(
                  children: [
                    Expanded(
                      child: _MiniBox(
                        label: isEn ? 'Deposit' : 'মোট জমা',
                        value: Formatters.currency(summary.totalDeposit),
                        color: AppColors.success,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniBox(
                        label: isEn ? 'Withdrawal' : 'উত্তোলন',
                        value: Formatters.currency(summary.totalWithdrawal),
                        color: AppColors.danger,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniBox(
                        label: isEn ? 'Net balance' : 'স্থিতি',
                        value: Formatters.currency(summary.balance),
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              const Divider(height: 1),
              Expanded(
                child: summary.transactions.isEmpty
                    ? Center(
                        child: Text(
                          isEn ? 'No records for this school.' : 'এই বিদ্যালয়ের কোনো লেনদেন নেই।',
                          style: AppTextStyles.bodyMedium,
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.all(AppDimensions.lg),
                        itemCount: summary.transactions.length,
                        itemBuilder: (context, i) {
                          final tx = summary.transactions[i];
                          final payer = tx.memberId != null ? memberNames[tx.memberId] : null;
                          return Padding(
                            padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                            child: TransactionListItem(
                              transaction: tx,
                              memberName: payer,
                              onDelete: () => _confirmDeleteOne(
                                context,
                                _financeService,
                                tx,
                                payer ?? summary.schoolName,
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!isAdmin && !isLinked && !widget.isViewerAdmin) return const _NotLinkedFinanceView();
    if (!isAdmin) return _buildBody(context, const {}, const {});

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
    final isEn = LocaleService.isEnglish;
    final currentMember = widget.targetMember ??
        (membersMap[widget.memberId] ??
            Member(
              id: widget.memberId ?? '',
              name: widget.memberName,
              memberCode: widget.memberCode,
              schoolName: '',
              designation: '',
              phone: '',
              bloodGroup: '',
              photoUrl: '',
              authUid: '',
              role: 'member',
              status: 'approved',
              isClaimed: true,
            ));

    return GradientScaffold(
      floatingActionButton: widget.isViewerAdmin
          ? FloatingActionButton.extended(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AddPaymentScreen(initialMember: currentMember),
                  ),
                );
              },
              backgroundColor: AppColors.primary,
              icon: const Icon(Icons.add_rounded, color: Colors.white),
              label: Text(
                isEn ? 'Deposit / Withdrawal' : 'জমা ও উত্তোলন',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _currentTxStream,
        builder: (context, snapshot) {
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
          final totalDonations = FinanceService.totalDonations(transactions);

          // Build school summaries when in admin mode
          final knownSchools = membersMap.values
              .map((m) => m.schoolName.trim())
              .where((s) => s.isNotEmpty)
              .toSet();
          final schoolSummaries = isAdmin
              ? FinanceService.allSchoolSummaries(transactions, membersMap, knownSchools)
              : <SchoolFinanceSummary>[];

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

                    // Admin Tab Chips: All, Schools, Donations, Expenses
                    if (isAdmin) ...[
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _FinanceTabChip(
                              label: isEn ? 'All transactions' : 'সকল লেনদেন',
                              icon: Icons.list_alt_rounded,
                              selected: _activeTab == FinanceTab.all,
                              onTap: () => setState(() => _activeTab = FinanceTab.all),
                            ),
                            const SizedBox(width: 8),
                            _FinanceTabChip(
                              label: isEn ? 'School statements' : 'বিদ্যালয়ভিত্তিক হিসাব ও পিডিএফ',
                              icon: Icons.school_rounded,
                              selected: _activeTab == FinanceTab.schools,
                              badge: '${schoolSummaries.length}',
                              onTap: () => setState(() => _activeTab = FinanceTab.schools),
                            ),
                            const SizedBox(width: 8),
                            _FinanceTabChip(
                              label: isEn ? 'Donations' : 'অনুদান ও আয়',
                              icon: Icons.volunteer_activism_rounded,
                              selected: _activeTab == FinanceTab.donations,
                              onTap: () => setState(() => _activeTab = FinanceTab.donations),
                            ),
                            const SizedBox(width: 8),
                            _FinanceTabChip(
                              label: isEn ? 'Expenses' : 'খরচসমূহ',
                              icon: Icons.receipt_long_rounded,
                              selected: _activeTab == FinanceTab.expenses,
                              onTap: () => setState(() => _activeTab = FinanceTab.expenses),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: AppDimensions.lg),
                    ],

                    // Header row for the active view
                    if (_activeTab == FinanceTab.all || !isAdmin)
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
                          if (widget.isViewerAdmin)
                            TextButton.icon(
                              onPressed: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => AddPaymentScreen(initialMember: currentMember),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.add_circle_outline_rounded, size: 18),
                              label: Text(isEn ? 'Deposit/Withdraw' : 'জমা ও উত্তোলন'),
                              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                            ),
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
                          if (isAdmin && transactions.isNotEmpty)
                            TextButton.icon(
                              onPressed: () => _confirmClearAll(context, financeService),
                              icon: const Icon(Icons.delete_sweep_rounded, size: 18),
                              label: Text(AppStrings.clearAll),
                              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                            ),
                        ],
                      )
                    else if (_activeTab == FinanceTab.schools) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEn ? 'School-wise financial statements' : 'বিদ্যালয়ভিত্তিক হিসাব ও স্টেটমেন্ট',
                                  style: AppTextStyles.h3,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEn
                                      ? 'Deposit, withdrawal & PDF statement per school'
                                      : 'প্রতিটি বিদ্যালয়ের মোট জমা, উত্তোলন এবং পিডিএফ বিবরণী',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          if (schoolSummaries.isNotEmpty)
                            FilledButton.icon(
                              onPressed: () => FinancePdfService.shareAllSchoolsSummary(
                                summaries: schoolSummaries,
                              ),
                              icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                              label: Text(isEn ? 'All Schools PDF' : 'সারসংক্ষেপ পিডিএফ'),
                              style: FilledButton.styleFrom(backgroundColor: AppColors.accentTeal),
                            ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      TextField(
                        onChanged: (v) => setState(() => _schoolSearchQuery = v.trim().toLowerCase()),
                        decoration: InputDecoration(
                          hintText: isEn ? 'Search school...' : 'বিদ্যালয় খুঁজুন...',
                          prefixIcon: Icon(Icons.search_rounded, color: AppColors.accentTeal),
                        ),
                      ),
                    ] else if (_activeTab == FinanceTab.donations) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEn ? 'Donations & other income' : 'অনুদান ও সাধারণ আয়সমূহ',
                                  style: AppTextStyles.h3,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEn
                                      ? 'Total collected from donations: ${Formatters.currency(totalDonations)}'
                                      : 'মোট অনুদান সংগ্রহ: ${Formatters.currency(totalDonations)}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.success,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AddExpenseScreen(initialIsIncome: true),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(isEn ? 'Add income' : 'আয় / অনুদান যোগ'),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.success),
                          ),
                        ],
                      ),
                    ] else if (_activeTab == FinanceTab.expenses) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  isEn ? 'Association expenses' : 'সমিতির খরচ ও ব্যয়সমূহ',
                                  style: AppTextStyles.h3,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isEn
                                      ? 'Total expenses: ${Formatters.currency(expense)}'
                                      : 'মোট ব্যয়: ${Formatters.currency(expense)}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.danger,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const AddExpenseScreen(initialIsIncome: false),
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(isEn ? 'Add expense' : 'খরচ যোগ করুন'),
                            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: AppDimensions.sm),
                  ]),
                ),
              ),

              // TAB 1: ALL TRANSACTIONS
              if (_activeTab == FinanceTab.all || !isAdmin) ...[
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
                                            targetMember: payerMember,
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
              ],

              // TAB 2: SCHOOLS LIST WITH DIRECT PDF DOWNLOAD
              if (isAdmin && _activeTab == FinanceTab.schools) ...[
                Builder(
                  builder: (context) {
                    final filtered = schoolSummaries.where((s) {
                      if (_schoolSearchQuery.isEmpty) return true;
                      return s.schoolName.toLowerCase().contains(_schoolSearchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.xl),
                          child: Center(
                            child: Text(
                              isEn ? 'No schools found' : 'কোনো বিদ্যালয় পাওয়া যায়নি',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.lg, 0, AppDimensions.lg, AppDimensions.xxl,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final s = filtered[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppDimensions.md),
                              child: _SchoolFinanceCard(
                                summary: s,
                                onPdf: () => FinancePdfService.shareSchoolStatement(
                                  schoolName: s.schoolName,
                                  transactions: s.transactions,
                                  memberNames: memberNames,
                                ),
                                onAddPayment: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => AddPaymentScreen(initialSchool: s.schoolName),
                                    ),
                                  );
                                },
                                onViewTransactions: () => _showSchoolStatementSheet(
                                  context,
                                  s,
                                  memberNames,
                                ),
                              ),
                            );
                          },
                          childCount: filtered.length,
                        ),
                      ),
                    );
                  },
                ),
              ],

              // TAB 3: DONATIONS & GENERAL INCOME
              if (isAdmin && _activeTab == FinanceTab.donations) ...[
                Builder(
                  builder: (context) {
                    final donationTxs = transactions
                        .where((t) => t.type == TransactionType.income)
                        .toList();

                    if (donationTxs.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.xl),
                          child: Center(
                            child: Text(
                              isEn ? 'No donations or general income recorded yet.' : 'এখনো কোনো অনুদান বা সাধারণ আয়ের রেকর্ড নেই।',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.lg, 0, AppDimensions.lg, AppDimensions.xxl,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final tx = donationTxs[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                              child: TransactionListItem(
                                transaction: tx,
                                onDelete: () => _confirmDeleteOne(
                                  context,
                                  financeService,
                                  tx,
                                  tx.donorName ?? tx.description,
                                ),
                              ),
                            );
                          },
                          childCount: donationTxs.length,
                        ),
                      ),
                    );
                  },
                ),
              ],

              // TAB 4: EXPENSES
              if (isAdmin && _activeTab == FinanceTab.expenses) ...[
                Builder(
                  builder: (context) {
                    final expenseTxs = transactions
                        .where((t) => t.type == TransactionType.expense)
                        .toList();

                    if (expenseTxs.isEmpty) {
                      return SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.all(AppDimensions.xl),
                          child: Center(
                            child: Text(
                              isEn ? 'No association expenses recorded yet.' : 'এখনো সমিতির কোনো খরচের রেকর্ড নেই।',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        ),
                      );
                    }

                    return SliverPadding(
                      padding: const EdgeInsets.fromLTRB(
                        AppDimensions.lg, 0, AppDimensions.lg, AppDimensions.xxl,
                      ),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final tx = expenseTxs[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                              child: TransactionListItem(
                                transaction: tx,
                                onDelete: () => _confirmDeleteOne(
                                  context,
                                  financeService,
                                  tx,
                                  tx.description,
                                ),
                              ),
                            );
                          },
                          childCount: expenseTxs.length,
                        ),
                      ),
                    );
                  },
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: AppDimensions.xl)),
            ],
          );
        },
      ),
    );
  }
}

class _FinanceTabChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final String? badge;
  final VoidCallback onTap;

  const _FinanceTabChip({
    required this.label,
    required this.icon,
    required this.selected,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primary : AppColors.surface,
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: selected ? Colors.white : AppColors.textPrimary,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppColors.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  ),
                  child: Text(
                    badge!,
                    style: AppTextStyles.caption.copyWith(
                      color: selected ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 10,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SchoolFinanceCard extends StatelessWidget {
  final SchoolFinanceSummary summary;
  final VoidCallback onPdf;
  final VoidCallback onAddPayment;
  final VoidCallback onViewTransactions;

  const _SchoolFinanceCard({
    required this.summary,
    required this.onPdf,
    required this.onAddPayment,
    required this.onViewTransactions,
  });

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.school_rounded, color: AppColors.accentTeal, size: 20),
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary.schoolName,
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn
                          ? '${summary.memberCount} teachers • ${summary.transactions.length} records'
                          : '${summary.memberCount} জন শিক্ষক • ${summary.transactions.length} টি লেনদেন',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            children: [
              Expanded(
                child: _MiniBox(
                  label: isEn ? 'Deposit' : 'মোট জমা',
                  value: Formatters.currency(summary.totalDeposit),
                  color: AppColors.success,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MiniBox(
                  label: isEn ? 'Withdrawal' : 'মোট উত্তোলন',
                  value: Formatters.currency(summary.totalWithdrawal),
                  color: AppColors.danger,
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _MiniBox(
                  label: isEn ? 'Balance' : 'অবশিষ্ট স্থিতি',
                  value: Formatters.currency(summary.balance),
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: onViewTransactions,
                icon: const Icon(Icons.visibility_rounded, size: 16),
                label: Text(isEn ? 'History' : 'বিবরণী'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.textSecondary,
                ),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: onAddPayment,
                icon: const Icon(Icons.add_rounded, size: 16),
                label: Text(isEn ? 'Deposit / Withdraw' : 'জমা / উত্তোলন'),
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  foregroundColor: AppColors.primary,
                ),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: onPdf,
                icon: const Icon(Icons.picture_as_pdf_rounded, size: 14),
                label: Text(isEn ? 'PDF' : 'পিডিএফ'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniBox extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniBox({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: AppColors.textSecondary,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: AppTextStyles.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

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