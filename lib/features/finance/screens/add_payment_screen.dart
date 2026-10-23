import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/finance_service.dart';
import '../../../core/services/finance_pdf_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/designation_rank.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/member.dart';
import '../../directory/widgets/school_filter_field.dart';
import '../../../models/transaction.dart';
import '../widgets/transaction_list_item.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

enum PaymentTargetMode { member, school }

/// Admin-only: log a dues deposit or withdrawal against a specific member OR a school.
/// Stays open on the selected member/school after each save so the admin can log
/// several transactions back-to-back without searching again.
class AddPaymentScreen extends StatefulWidget {
  final Member? initialMember;
  final String? initialSchool;

  const AddPaymentScreen({super.key, this.initialMember, this.initialSchool});

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final _firestoreService = FirestoreService();
  final _financeService = FinanceService();
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  late PaymentTargetMode _targetMode;
  String _query = '';
  String? _schoolFilter;
  Member? _selectedMember;
  String? _selectedSchool;
  TransactionType _type = TransactionType.duePayment;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMember = widget.initialMember;
    _selectedSchool = widget.initialSchool;
    if (widget.initialSchool != null && widget.initialSchool!.trim().isNotEmpty) {
      _targetMode = PaymentTargetMode.school;
    } else {
      _targetMode = PaymentTargetMode.member;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(1990),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final isDeposit = _type == TransactionType.duePayment;
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleService.isEnglish ? 'Enter a valid amount' : 'সঠিক পরিমাণ লিখুন')),
      );
      return;
    }

    if (_targetMode == PaymentTargetMode.member) {
      final member = _selectedMember;
      if (member == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.selectMember)),
        );
        return;
      }

      setState(() => _isSaving = true);

      try {
        final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        await _financeService.addTransaction(AppTransaction(
          id: '',
          memberId: member.id,
          schoolName: member.schoolName.trim().isNotEmpty ? member.schoolName.trim() : null,
          source: 'member_due',
          type: _type,
          amount: amount,
          date: _date,
          description: _descriptionController.text.trim(),
          createdBy: adminUid,
        ));

        final title = isDeposit
            ? (LocaleService.isEnglish ? 'Deposit recorded' : 'টাকা জমা যোগ হয়েছে')
            : (LocaleService.isEnglish ? 'Withdrawal recorded' : 'টাকা উত্তোলন রেকর্ড হয়েছে');
        final body = isDeposit
            ? (LocaleService.isEnglish
                ? '${Formatters.currency(amount)} has been added to your account.'
                : 'আপনার হিসাবে ${Formatters.currency(amount)} জমা হয়েছে।')
            : (LocaleService.isEnglish
                ? '${Formatters.currency(amount)} has been deducted from your account.'
                : 'আপনার হিসাব থেকে ${Formatters.currency(amount)} উত্তোলন বিয়োগ করা হয়েছে।');

        // Store notification in member's inbox
        await _firestoreService.addMemberNotification(
          memberId: member.id,
          authUid: member.authUid,
          title: title,
          body: body,
          type: 'payment',
        );

        // Best-effort push notification
        String? pushError;
        try {
          await NotificationService().sendToMember(
            memberId: member.id,
            title: title,
            body: body,
          );
        } catch (e) {
          pushError = e.toString();
        }

        if (!mounted) return;
        setState(() {
          _isSaving = false;
          _amountController.clear();
          _descriptionController.clear();
          _date = DateTime.now();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pushError == null
                  ? (isDeposit ? AppStrings.depositAdded : AppStrings.withdrawalAdded)
                  : (LocaleService.isEnglish
                      ? 'Saved, but the member could not be notified.'
                      : 'সংরক্ষিত হয়েছে, তবে সদস্যকে জানানো যায়নি।'),
            ),
            backgroundColor: pushError == null ? AppColors.success : AppColors.warning,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.errorGeneric}: $e'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    } else {
      // School-level deposit or withdrawal
      final school = _selectedSchool;
      if (school == null || school.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppStrings.selectSchool)),
        );
        return;
      }

      setState(() => _isSaving = true);

      try {
        final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        await _financeService.addTransaction(AppTransaction(
          id: '',
          memberId: null,
          schoolName: school.trim(),
          source: 'school_fund',
          type: _type,
          amount: amount,
          date: _date,
          description: _descriptionController.text.trim(),
          createdBy: adminUid,
        ));

        if (!mounted) return;
        setState(() {
          _isSaving = false;
          // Retain _selectedSchool so admin can add multiple transactions for this school!
          _amountController.clear();
          _descriptionController.clear();
          _date = DateTime.now();
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              isDeposit
                  ? (LocaleService.isEnglish
                      ? 'Deposit added for $school'
                      : '$school-এর নামে টাকা জমা যোগ করা হয়েছে')
                  : (LocaleService.isEnglish
                      ? 'Withdrawal recorded for $school'
                      : '$school-এর নামে টাকা উত্তোলন লিপিবদ্ধ হয়েছে'),
            ),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppStrings.errorGeneric}: $e'),
            backgroundColor: AppColors.danger,
            duration: const Duration(seconds: 6),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;
    final isDeposit = _type == TransactionType.duePayment;
    final isMemberMode = _targetMode == PaymentTargetMode.member;

    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(AppStrings.addPayment, style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.sm),
              Text(
                isEn
                    ? 'Record dues, deposits or withdrawals by member or by school'
                    : 'সদস্যের নামে অথবা সরাসরি বিদ্যালয়ের নামে টাকা জমা ও উত্তোলন হিসাব সংরক্ষণ করুন',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.lg),

              // Target Selector: Member vs School
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TypeSegment(
                        label: AppStrings.byMember,
                        icon: Icons.person_rounded,
                        selected: isMemberMode,
                        selectedColor: AppColors.primary,
                        onTap: () => setState(() => _targetMode = PaymentTargetMode.member),
                      ),
                    ),
                    Expanded(
                      child: _TypeSegment(
                        label: AppStrings.bySchool,
                        icon: Icons.school_rounded,
                        selected: !isMemberMode,
                        selectedColor: AppColors.accentTeal,
                        onTap: () => setState(() => _targetMode = PaymentTargetMode.school),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.md),

              // Transaction Type Selector: Deposit vs Withdrawal
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceMuted,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _TypeSegment(
                        label: AppStrings.deposit,
                        icon: Icons.arrow_downward_rounded,
                        selected: isDeposit,
                        selectedColor: AppColors.success,
                        onTap: () => setState(() => _type = TransactionType.duePayment),
                      ),
                    ),
                    Expanded(
                      child: _TypeSegment(
                        label: AppStrings.withdrawal,
                        icon: Icons.arrow_upward_rounded,
                        selected: !isDeposit,
                        selectedColor: AppColors.danger,
                        onTap: () => setState(() => _type = TransactionType.withdrawal),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.lg),

              if (isMemberMode) ...[
                Text(AppStrings.selectMember, style: AppTextStyles.overline),
                const SizedBox(height: AppDimensions.sm),
                if (_selectedMember != null)
                  _SelectedMemberCard(
                    member: _selectedMember!,
                    onChange: () => setState(() => _selectedMember = null),
                  )
                else ...[
                  TextField(
                    controller: _searchController,
                    onChanged: (value) => setState(() => _query = value),
                    decoration: InputDecoration(
                      hintText: isEn ? 'Search by name or school' : 'নাম বা বিদ্যালয় দিয়ে খুঁজুন',
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestoreService.watchAllMembers(),
                    builder: (context, snapshot) {
                      final counts = <String, int>{};
                      for (final doc in snapshot.data?.docs ?? const []) {
                        final s = (doc.data()['schoolName'] ?? '').toString().trim();
                        if (s.isEmpty) continue;
                        counts[s] = (counts[s] ?? 0) + 1;
                      }
                      return SchoolFilterField(
                        counts: counts,
                        selected: _schoolFilter,
                        onChanged: (v) => setState(() => _schoolFilter = v),
                      );
                    },
                  ),
                  const SizedBox(height: AppDimensions.sm),
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestoreService.watchAllMembers(),
                    builder: (context, snapshot) {
                      final all = (snapshot.data?.docs ?? [])
                          .map(Member.fromDoc)
                          .where((m) => m.isApproved)
                          .toList();

                      final members = all
                          .where((m) =>
                              _schoolFilter == null ||
                              m.schoolName.trim() == _schoolFilter)
                          .where((m) =>
                              _query.isEmpty ||
                              m.name.toLowerCase().contains(_query.toLowerCase()) ||
                              m.schoolName.toLowerCase().contains(_query.toLowerCase()))
                          .toList()
                        ..sort((a, b) => DesignationRank.compare(
                              a.designation, a.name, b.designation, b.name,
                            ));

                      if (members.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: AppDimensions.lg),
                          child: Center(
                            child: Text(
                              isEn ? 'No members found' : 'কোনো সদস্য পাওয়া যায়নি',
                              style: AppTextStyles.bodyMedium,
                            ),
                          ),
                        );
                      }

                      return ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 280),
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: members.length,
                          separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
                          itemBuilder: (context, index) {
                            final m = members[index];
                            return PremiumCard(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.md, vertical: AppDimensions.sm,
                              ),
                              onTap: () => setState(() => _selectedMember = m),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                    backgroundImage: m.photoUrl.isNotEmpty ? NetworkImage(m.photoUrl) : null,
                                    child: m.photoUrl.isEmpty
                                        ? Text(
                                            m.name.isNotEmpty ? m.name.characters.first : '?',
                                            style: AppTextStyles.bodyMedium.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: AppDimensions.sm),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(m.name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600)),
                                        if (m.schoolName.isNotEmpty)
                                          Text(m.schoolName, style: AppTextStyles.caption),
                                      ],
                                    ),
                                  ),
                                  Icon(Icons.chevron_right_rounded, color: AppColors.primary),
                                ],
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ],
              ] else ...[
                // School Mode
                Text(AppStrings.selectSchool, style: AppTextStyles.overline),
                const SizedBox(height: AppDimensions.sm),
                if (_selectedSchool != null)
                  _SelectedSchoolCard(
                    schoolName: _selectedSchool!,
                    onChange: () => setState(() => _selectedSchool = null),
                  )
                else ...[
                  StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _firestoreService.watchAllMembers(),
                    builder: (context, snapshot) {
                      final counts = <String, int>{};
                      for (final doc in snapshot.data?.docs ?? const []) {
                        final s = (doc.data()['schoolName'] ?? '').toString().trim();
                        if (s.isEmpty) continue;
                        counts[s] = (counts[s] ?? 0) + 1;
                      }
                      final schools = counts.keys.toList()
                        ..sort((a, b) {
                          final bySize = counts[b]!.compareTo(counts[a]!);
                          return bySize != 0 ? bySize : a.compareTo(b);
                        });

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (value) => setState(() => _query = value),
                            decoration: InputDecoration(
                              hintText: isEn ? 'Search school...' : 'বিদ্যালয় খুঁজুন...',
                              prefixIcon: Icon(Icons.search_rounded, color: AppColors.accentTeal),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxHeight: 280),
                            child: ListView.separated(
                              shrinkWrap: true,
                              itemCount: schools
                                  .where((s) => _query.isEmpty || s.toLowerCase().contains(_query.toLowerCase()))
                                  .length,
                              separatorBuilder: (_, __) => const SizedBox(height: AppDimensions.sm),
                              itemBuilder: (context, index) {
                                final s = schools
                                    .where((s) => _query.isEmpty || s.toLowerCase().contains(_query.toLowerCase()))
                                    .toList()[index];
                                final count = counts[s] ?? 0;
                                return PremiumCard(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppDimensions.md, vertical: 12,
                                  ),
                                  onTap: () => setState(() => _selectedSchool = s),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentTeal.withValues(alpha: 0.12),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(Icons.school_rounded, color: AppColors.accentTeal, size: 20),
                                      ),
                                      const SizedBox(width: AppDimensions.md),
                                      Expanded(
                                        child: Text(
                                          s,
                                          style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                      const SizedBox(width: AppDimensions.sm),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: AppColors.accentTeal.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                                        ),
                                        child: Text(
                                          isEn ? '$count teachers' : '$count জন শিক্ষক',
                                          style: AppTextStyles.caption.copyWith(
                                            color: AppColors.accentTeal,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ],

              const SizedBox(height: AppDimensions.lg),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  labelText: isDeposit
                      ? (isEn ? 'Deposit amount' : 'টাকা জমার পরিমাণ')
                      : (isEn ? 'Withdrawal amount' : 'টাকা উত্তোলনের পরিমাণ'),
                  prefixIcon: Icon(
                    isDeposit ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: isDeposit ? AppColors.success : AppColors.danger,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: _descriptionController,
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  labelText: isDeposit
                      ? (isEn
                          ? 'Description (e.g. Annual subscription, School fund, Dues)'
                          : 'বিবরণ (যেমন: বার্ষিক চাঁদা, বিদ্যালয় ফান্ড, কল্যাণ অনুদান)')
                      : (isEn
                          ? 'Description (e.g. Welfare disbursement, Refund, Project aid)'
                          : 'বিবরণ (যেমন: কল্যাণ সহায়তা, চাঁদা ফেরত, বিদ্যালয় সহায়তা)'),
                  prefixIcon: Icon(Icons.description_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              InkWell(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_rounded, color: AppColors.primary),
                      const SizedBox(width: AppDimensions.md),
                      Text('${_date.day}/${_date.month}/${_date.year}', style: AppTextStyles.bodyMedium),
                      const Spacer(),
                      Text(
                        AppStrings.paymentDate,
                        style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.xl),
              GradientButton(
                label: isDeposit
                    ? (isEn ? 'Record Deposit' : 'টাকা জমা যোগ করুন')
                    : (isEn ? 'Record Withdrawal' : 'টাকা উত্তোলন লিপিবদ্ধ করুন'),
                isLoading: _isSaving,
                onPressed: _save,
                icon: isDeposit ? Icons.check_rounded : Icons.remove_circle_outline_rounded,
              ),

              // Recent member records shown directly below the form
              if (isMemberMode && _selectedMember != null) ...[
                const SizedBox(height: AppDimensions.xl),
                Text(
                  isEn
                      ? '${_selectedMember!.name} — Recent records'
                      : '${_selectedMember!.name} — সাম্প্রতিক হিসাব',
                  style: AppTextStyles.h3,
                ),
                const SizedBox(height: AppDimensions.sm),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _financeService.watchMemberTransactions(_selectedMember!.id),
                  builder: (context, snapshot) {
                    final txs = (snapshot.data?.docs ?? []).map(AppTransaction.fromDoc).toList();
                    if (txs.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
                        child: Text(
                          isEn ? 'No records yet for this member.' : 'এই সদস্যের কোনো লেনদেন রেকর্ড নেই।',
                          style: AppTextStyles.caption,
                        ),
                      );
                    }
                    return Column(
                      children: txs.take(6).map((tx) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                          child: TransactionListItem(
                            transaction: tx,
                            onDelete: () async {
                              final ok = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  backgroundColor: AppColors.surface,
                                  title: Text(
                                    isEn ? 'Delete this record?' : 'এই রেকর্ডটি মুছবেন?',
                                    style: AppTextStyles.h3,
                                  ),
                                  content: Text(
                                    isEn
                                        ? '${Formatters.currency(tx.amount)} will be removed. Totals will be recalculated.'
                                        : '${Formatters.currency(tx.amount)} বাদ দিয়ে হিসাব আবার গণনা হবে।',
                                    style: AppTextStyles.bodyMedium,
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(false),
                                      child: Text(isEn ? 'Cancel' : 'বাতিল'),
                                    ),
                                    TextButton(
                                      onPressed: () => Navigator.of(ctx).pop(true),
                                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                      child: Text(isEn ? 'Delete' : 'মুছুন'),
                                    ),
                                  ],
                                ),
                              );
                              if (ok == true) {
                                await _financeService.deleteTransaction(tx.id);
                              }
                            },
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],

              // Recent school records shown directly below the form
              if (!isMemberMode && _selectedSchool != null) ...[
                const SizedBox(height: AppDimensions.xl),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestoreService.watchAllMembers(),
                  builder: (context, memberSnapshot) {
                    final membersMap = <String, Member>{
                      for (final doc in memberSnapshot.data?.docs ?? const [])
                        doc.id: Member.fromDoc(doc),
                    };
                    final memberNames = <String, String>{
                      for (final entry in membersMap.entries) entry.key: entry.value.name,
                    };

                    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: _financeService.watchAllTransactions(),
                      builder: (context, txSnapshot) {
                        final allTxs = (txSnapshot.data?.docs ?? [])
                            .map(AppTransaction.fromDoc)
                            .toList();
                        final schoolTxs = FinanceService.transactionsForSchool(
                          _selectedSchool!,
                          allTxs,
                          membersMap,
                        );

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isEn
                                        ? '$_selectedSchool — Recent records'
                                        : '$_selectedSchool — সাম্প্রতিক হিসাব',
                                    style: AppTextStyles.h3,
                                  ),
                                ),
                                if (schoolTxs.isNotEmpty)
                                  TextButton.icon(
                                    onPressed: () => FinancePdfService.shareSchoolStatement(
                                      schoolName: _selectedSchool!,
                                      transactions: schoolTxs,
                                      memberNames: memberNames,
                                    ),
                                    icon: const Icon(Icons.picture_as_pdf_rounded, size: 16),
                                    label: Text(isEn ? 'PDF' : 'পিডিএফ'),
                                    style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                                  ),
                              ],
                            ),
                            const SizedBox(height: AppDimensions.sm),
                            if (schoolTxs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
                                child: Text(
                                  isEn
                                      ? 'No records yet for this school.'
                                      : 'এই বিদ্যালয়ের কোনো লেনদেন রেকর্ড নেই।',
                                  style: AppTextStyles.caption,
                                ),
                              )
                            else
                              Column(
                                children: schoolTxs.take(6).map((tx) {
                                  final payer = tx.memberId != null ? memberNames[tx.memberId] : null;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                                    child: TransactionListItem(
                                      transaction: tx,
                                      memberName: payer,
                                      onDelete: () async {
                                        final ok = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            backgroundColor: AppColors.surface,
                                            title: Text(
                                              isEn ? 'Delete this record?' : 'এই রেকর্ডটি মুছবেন?',
                                              style: AppTextStyles.h3,
                                            ),
                                            content: Text(
                                              isEn
                                                  ? '${Formatters.currency(tx.amount)} will be removed.'
                                                  : '${Formatters.currency(tx.amount)} বাদ দিয়ে হিসাব আবার গণনা হবে।',
                                              style: AppTextStyles.bodyMedium,
                                            ),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(false),
                                                child: Text(isEn ? 'Cancel' : 'বাতিল'),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(ctx).pop(true),
                                                style: TextButton.styleFrom(
                                                    foregroundColor: AppColors.danger),
                                                child: Text(isEn ? 'Delete' : 'মুছুন'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (ok == true) {
                                          await _financeService.deleteTransaction(tx.id);
                                        }
                                      },
                                    ),
                                  );
                                }).toList(),
                              ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ],
              const SizedBox(height: AppDimensions.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _TypeSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _TypeSegment({
    required this.label,
    required this.icon,
    required this.selected,
    required this.selectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? selectedColor : Colors.transparent,
      borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
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
                  color: selected ? Colors.white : AppColors.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectedMemberCard extends StatelessWidget {
  final Member member;
  final VoidCallback onChange;

  const _SelectedMemberCard({required this.member, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;
    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.success.withValues(alpha: 0.12),
                backgroundImage: member.photoUrl.isNotEmpty ? NetworkImage(member.photoUrl) : null,
                child: member.photoUrl.isEmpty
                    ? Text(
                        member.name.isNotEmpty ? member.name.characters.first : '?',
                        style: AppTextStyles.bodyLarge.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
                      )
                    : null,
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(member.name, style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700)),
                    if (member.schoolName.isNotEmpty)
                      Text(member.schoolName, style: AppTextStyles.caption),
                    if (member.memberCode.isNotEmpty)
                      Text(
                        'ID: ${member.memberCode}',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onChange,
                child: Text(AppStrings.changeMember),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FinanceService().watchMemberTransactions(member.id),
            builder: (context, snapshot) {
              final txs = (snapshot.data?.docs ?? []).map(AppTransaction.fromDoc).toList();
              final dep = FinanceService.totalIncome(txs);
              final withdr = FinanceService.totalExpense(txs);
              final bal = FinanceService.balance(txs);

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.account_balance_wallet_rounded, size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text(
                      '${isEn ? 'Net' : 'স্থিতি'}: ${Formatters.currency(bal)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${isEn ? 'Dep' : 'জমা'}: ${Formatters.currency(dep)} | ${isEn ? 'Withdr' : 'উত্তোলন'}: ${Formatters.currency(withdr)}',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SelectedSchoolCard extends StatelessWidget {
  final String schoolName;
  final VoidCallback onChange;

  const _SelectedSchoolCard({required this.schoolName, required this.onChange});

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;
    final firestoreService = FirestoreService();
    final financeService = FinanceService();

    return PremiumCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.accentTeal.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.school_rounded, color: AppColors.accentTeal, size: 24),
              ),
              const SizedBox(width: AppDimensions.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      schoolName,
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEn ? 'School account' : 'বিদ্যালয়ের তহবিল ও হিসাব',
                      style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: onChange,
                child: Text(AppStrings.changeSchool),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: firestoreService.watchAllMembers(),
            builder: (context, memberSnapshot) {
              final membersMap = <String, Member>{
                for (final doc in memberSnapshot.data?.docs ?? const [])
                  doc.id: Member.fromDoc(doc),
              };
              final memberNames = <String, String>{
                for (final entry in membersMap.entries) entry.key: entry.value.name,
              };

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: financeService.watchAllTransactions(),
                builder: (context, txSnapshot) {
                  final allTxs = (txSnapshot.data?.docs ?? [])
                      .map(AppTransaction.fromDoc)
                      .toList();
                  final schoolTxs = FinanceService.transactionsForSchool(
                    schoolName,
                    allTxs,
                    membersMap,
                  );

                  final dep = schoolTxs
                      .where((t) => t.type == TransactionType.duePayment || t.type == TransactionType.income)
                      .fold(0.0, (acc, t) => acc + t.amount);
                  final withdr = schoolTxs
                      .where((t) => t.type == TransactionType.withdrawal || t.type == TransactionType.expense)
                      .fold(0.0, (acc, t) => acc + t.amount);
                  final bal = dep - withdr;

                  return Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.accentTeal.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.account_balance_rounded, size: 16, color: AppColors.accentTeal),
                            const SizedBox(width: 6),
                            Text(
                              '${isEn ? 'Net' : 'স্থিতি'}: ${Formatters.currency(bal)}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.accentTeal,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${isEn ? 'Dep' : 'জমা'}: ${Formatters.currency(dep)} | ${isEn ? 'Withdr' : 'উত্তোলন'}: ${Formatters.currency(withdr)}',
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (schoolTxs.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Align(
                          alignment: Alignment.centerRight,
                          child: InkWell(
                            onTap: () => FinancePdfService.shareSchoolStatement(
                              schoolName: schoolName,
                              transactions: schoolTxs,
                              memberNames: memberNames,
                            ),
                            borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.picture_as_pdf_rounded, size: 14, color: AppColors.primary),
                                  const SizedBox(width: 4),
                                  Text(
                                    AppStrings.schoolStatementPdf,
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }
}