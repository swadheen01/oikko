import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/finance_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/utils/formatters.dart';
import '../../../models/transaction.dart';
import '../widgets/transaction_list_item.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

/// Admin-only: record general association income (including donations from patrons,
/// bank profit, form sales) or association spending (meetings, office, refreshments).
///
/// Neither is tied to any specific member — `memberId` stays null, keeping general
/// association finances distinct from individual teacher dues.
///
/// Stays open after each save so several transactions can be entered in one session.
class AddExpenseScreen extends StatefulWidget {
  final bool initialIsIncome;

  const AddExpenseScreen({super.key, this.initialIsIncome = false});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _financeService = FinanceService();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _donorController = TextEditingController();

  late bool _isIncome;
  late String _selectedCategory;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  static const _incomeCategories = [
    'অনুদান',
    'ব্যাংক মুনাফা / সুদ',
    'ফরম / প্রকাশনা বিক্রি',
    'সম্মেলন / অনুষ্ঠান ফি',
    'অন্যান্য আয়',
  ];

  static const _incomeCategoriesEn = [
    'Donation',
    'Bank profit / interest',
    'Form / publication sale',
    'Conference / event fee',
    'Other income',
  ];

  static const _expenseCategories = [
    'সভা ও সম্মেলন',
    'অফিস ও স্টেশনারি',
    'আপ্যায়ন ও নাস্তা',
    'শিক্ষক কল্যাণ ও সহায়তা',
    'যাতায়াত ও ভ্রমণ',
    'অন্যান্য খরচ',
  ];

  static const _expenseCategoriesEn = [
    'Meeting & Conference',
    'Office & Stationery',
    'Refreshments & Food',
    'Teacher Welfare & Grant',
    'Travel & Transport',
    'Other expense',
  ];

  @override
  void initState() {
    super.initState();
    _isIncome = widget.initialIsIncome;
    _selectedCategory = _isIncome ? _incomeCategories.first : _expenseCategories.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _donorController.dispose();
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
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleService.isEnglish
              ? 'Enter a valid amount'
              : 'সঠিক পরিমাণ লিখুন'),
        ),
      );
      return;
    }

    final isDonation = _isIncome && _selectedCategory == 'অনুদান';
    final donor = _donorController.text.trim();
    if (isDonation && donor.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleService.isEnglish
              ? 'Enter the donor or organization name'
              : 'দাতার নাম বা প্রতিষ্ঠানের নাম লিখুন'),
        ),
      );
      return;
    }

    final description = _descriptionController.text.trim();
    if (!_isIncome && description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.expenseReason)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _financeService.addTransaction(AppTransaction(
        id: '',
        memberId: null,
        type: _isIncome ? TransactionType.income : TransactionType.expense,
        source: _isIncome
            ? (isDonation ? 'donation' : 'general_income')
            : 'general_expense',
        category: _selectedCategory,
        donorName: isDonation ? donor : null,
        amount: amount,
        date: _date,
        description: description,
        createdBy: adminUid,
      ));

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _amountController.clear();
        _descriptionController.clear();
        _donorController.clear();
        _date = DateTime.now();
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isIncome
                ? (isDonation
                    ? (LocaleService.isEnglish ? 'Donation recorded successfully' : 'অনুদান সফলভাবে লিপিবদ্ধ হয়েছে')
                    : AppStrings.incomeAdded)
                : AppStrings.expenseAdded,
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

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;
    final isDonation = _isIncome && _selectedCategory == 'অনুদান';
    final categories = _isIncome ? _incomeCategories : _expenseCategories;
    final categoriesEn = _isIncome ? _incomeCategoriesEn : _expenseCategoriesEn;

    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Navigator.of(context).canPop()) ...[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                ),
                const SizedBox(height: AppDimensions.md),
              ],
              Text(
                AppStrings.incomeAndExpense,
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                isEn
                    ? 'Association income (including donations) and general spending.'
                    : 'সমিতির বিভিন্ন উৎস থেকে সাধারণ আয়, অনুদান এবং সামগ্রিক খরচের হিসাব সংরক্ষণ করুন।',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.lg),

              // Segment: Income vs Expense
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
                      child: _ModeSegment(
                        label: isEn ? 'Income / Donation' : 'সাধারণ আয় ও অনুদান',
                        icon: Icons.volunteer_activism_rounded,
                        selected: _isIncome,
                        selectedColor: AppColors.success,
                        onTap: () {
                          setState(() {
                            _isIncome = true;
                            _selectedCategory = _incomeCategories.first;
                          });
                        },
                      ),
                    ),
                    Expanded(
                      child: _ModeSegment(
                        label: isEn ? 'Expense / Spending' : 'সমিতির ব্যয় / খরচ',
                        icon: Icons.receipt_long_rounded,
                        selected: !_isIncome,
                        selectedColor: AppColors.danger,
                        onTap: () {
                          setState(() {
                            _isIncome = false;
                            _selectedCategory = _expenseCategories.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.lg),

              Text(
                _isIncome
                    ? (isEn ? 'SELECT INCOME SOURCE' : 'আয়ের উৎস বা খাত নির্বাচন করুন')
                    : (isEn ? 'SELECT EXPENSE CATEGORY' : 'ব্যয়ের খাত নির্বাচন করুন'),
                style: AppTextStyles.overline,
              ),
              const SizedBox(height: AppDimensions.sm),

              // Category chips
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < categories.length; i++)
                    ChoiceChip(
                      label: Text(isEn ? categoriesEn[i] : categories[i]),
                      selected: _selectedCategory == categories[i],
                      selectedColor: _isIncome
                          ? AppColors.success.withValues(alpha: 0.15)
                          : AppColors.danger.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                        color: _selectedCategory == categories[i]
                            ? (_isIncome ? AppColors.success : AppColors.danger)
                            : AppColors.textPrimary,
                        fontWeight: _selectedCategory == categories[i]
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                      side: BorderSide(
                        color: _selectedCategory == categories[i]
                            ? (_isIncome ? AppColors.success : AppColors.danger)
                            : AppColors.border,
                      ),
                      onSelected: (selected) {
                        if (selected) setState(() => _selectedCategory = categories[i]);
                      },
                    ),
                ],
              ),

              const SizedBox(height: AppDimensions.lg),

              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isDonation) ...[
                      TextFormField(
                        controller: _donorController,
                        style: AppTextStyles.bodyLarge,
                        decoration: InputDecoration(
                          labelText: AppStrings.donorName,
                          hintText: isEn ? 'e.g. Alhaj Md. Abdur Rahim' : 'যেমন: আলহাজ্ব মোঃ আব্দুর রহিম',
                          prefixIcon: Icon(
                            Icons.volunteer_activism_rounded,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                      const SizedBox(height: AppDimensions.md),
                    ],

                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        labelText: AppStrings.amount,
                        prefixIcon: Icon(
                          Icons.payments_rounded,
                          color: _isIncome ? AppColors.success : AppColors.danger,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),

                    TextFormField(
                      controller: _descriptionController,
                      style: AppTextStyles.bodyLarge,
                      minLines: 2,
                      maxLines: 4,
                      keyboardType: TextInputType.multiline,
                      textAlignVertical: TextAlignVertical.top,
                      decoration: InputDecoration(
                        labelText: _isIncome
                            ? (isEn ? 'Description / Remarks (optional)' : 'বিবরণ / মন্তব্যের বিবরণ (ঐচ্ছিক)')
                            : AppStrings.expenseReason,
                        prefixIcon: Align(
                          widthFactor: 1.0,
                          alignment: Alignment.topLeft,
                          child: Icon(
                            Icons.description_rounded,
                            color: _isIncome ? AppColors.success : AppColors.danger,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),

                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                      child: Container(
                        padding: const EdgeInsets.all(AppDimensions.md),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceMuted,
                          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.calendar_today_rounded,
                              color: _isIncome ? AppColors.success : AppColors.danger,
                            ),
                            const SizedBox(width: AppDimensions.md),
                            Text(
                              '${_date.day}/${_date.month}/${_date.year}',
                              style: AppTextStyles.bodyMedium,
                            ),
                            const Spacer(),
                            Text(
                              AppStrings.paymentDate,
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.xl),
              GradientButton(
                label: _isIncome
                    ? (isDonation
                        ? (isEn ? 'Record Donation' : 'অনুদান সংরক্ষণ করুন')
                        : (isEn ? 'Record Income' : 'আয় সংরক্ষণ করুন'))
                    : AppStrings.addExpense,
                isLoading: _isSaving,
                onPressed: _save,
                icon: _isIncome ? Icons.check_rounded : Icons.check_rounded,
              ),

              const SizedBox(height: AppDimensions.xl),

              // Stream of recent entries in this mode
              Text(
                _isIncome
                    ? (isEn ? 'Recent income & donations' : 'সাম্প্রতিক আয় ও অনুদানসমূহ')
                    : (isEn ? 'Recent association expenses' : 'সাম্প্রতিক ব্যয় ও খরচসমূহ'),
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: AppDimensions.sm),

              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: _financeService.watchAllTransactions(),
                builder: (context, snapshot) {
                  final all = (snapshot.data?.docs ?? []).map(AppTransaction.fromDoc).toList();
                  final txs = all.where((t) {
                    if (_isIncome) {
                      return t.type == TransactionType.income;
                    } else {
                      return t.type == TransactionType.expense;
                    }
                  }).toList();

                  if (txs.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: AppDimensions.md),
                      child: Text(
                        isEn ? 'No records yet in this category.' : 'এই খাতে কোনো লেনদেন পাওয়া যায়নি।',
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

              const SizedBox(height: AppDimensions.xxl),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModeSegment extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color selectedColor;
  final VoidCallback onTap;

  const _ModeSegment({
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
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}