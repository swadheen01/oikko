import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/finance_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/transaction.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

/// Admin-only: record an association expense (rent, refreshments, printing).
///
/// Unlike a payment this has no member attached — `memberId` stays null,
/// which is exactly how `models/transaction.dart` distinguishes general
/// association spending from a member's dues. That also keeps it out of
/// every member's personal statement, which is scoped by memberId.
///
/// Stays open after each save so several expenses can be entered in one go.
class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _financeService = FinanceService();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
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

    final description = _descriptionController.text.trim();
    // An expense with no description is unauditable later — the amount
    // alone tells nobody what the money went on.
    if (description.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.expenseReason)),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      await _financeService.addTransaction(AppTransaction(
        id: '',
        memberId: null,
        type: TransactionType.expense,
        amount: amount,
        date: _date,
        description: description,
        createdBy: FirebaseAuth.instance.currentUser?.uid ?? '',
      ));

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _amountController.clear();
        _descriptionController.clear();
        _date = DateTime.now();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.expenseAdded),
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
              Text(AppStrings.addExpense, style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.sm),
              Text(
                LocaleService.isEnglish
                    ? 'Association spending — not tied to any member, and not shown in anyone\'s personal statement.'
                    : 'সমিতির খরচ — কোনো নির্দিষ্ট সদস্যের সাথে যুক্ত নয়, কারও ব্যক্তিগত হিসাবেও দেখাবে না।',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.lg),

              PremiumCard(
                child: Column(
                  children: [
                    TextFormField(
                      controller: _amountController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        labelText: AppStrings.amount,
                        prefixIcon: Icon(
                          Icons.payments_rounded,
                          color: AppColors.danger,
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
                        labelText: AppStrings.expenseReason,
                        // widthFactor: 1.0 keeps Align from swallowing the
                        // full field width — see notice_create_screen.
                        prefixIcon: Align(
                          widthFactor: 1.0,
                          alignment: Alignment.topLeft,
                          child: Icon(
                            Icons.description_rounded,
                            color: AppColors.danger,
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
                            Icon(Icons.calendar_today_rounded, color: AppColors.danger),
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
                label: AppStrings.addExpense,
                isLoading: _isSaving,
                onPressed: _save,
                icon: Icons.check_rounded,
              ),
              const SizedBox(height: AppDimensions.xl),
            ],
          ),
        ),
      ),
    );
  }
}
