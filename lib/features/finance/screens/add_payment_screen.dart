import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/finance_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/member.dart';
import '../../../models/transaction.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

/// Admin-only: log a dues/welfare payment against a specific member.
/// Stays open after each save (clearing the form) so the admin can log
/// several teachers' payments back-to-back in one sitting.
class AddPaymentScreen extends StatefulWidget {
  const AddPaymentScreen({super.key});

  @override
  State<AddPaymentScreen> createState() => _AddPaymentScreenState();
}

class _AddPaymentScreenState extends State<AddPaymentScreen> {
  final _firestoreService = FirestoreService();
  final _financeService = FinanceService();
  final _searchController = TextEditingController();
  final _amountController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _query = '';
  Member? _selectedMember;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

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
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    final member = _selectedMember;
    if (member == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.selectMember)),
      );
      return;
    }
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleService.isEnglish ? 'Enter a valid amount' : 'সঠিক পরিমাণ লিখুন')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final adminUid = FirebaseAuth.instance.currentUser?.uid ?? '';
      await _financeService.addTransaction(AppTransaction(
        id: '',
        memberId: member.id,
        type: TransactionType.duePayment,
        amount: amount,
        date: _date,
        description: _descriptionController.text.trim(),
        createdBy: adminUid,
      ));

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _selectedMember = null;
        _amountController.clear();
        _descriptionController.clear();
        _date = DateTime.now();
        _searchController.clear();
        _query = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.paymentAdded), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      // Show the real cause, not just "something went wrong" — a
      // permission-denied here almost always means the signed-in admin has
      // no `admins/{uid}` marker doc, which is invisible from a generic
      // message and sends you looking in the wrong place.
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
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(AppStrings.addPayment, style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.lg),

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
                    hintText: LocaleService.isEnglish ? 'Search by name or school' : 'নাম বা বিদ্যালয় দিয়ে খুঁজুন',
                    prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: AppDimensions.sm),
                StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _firestoreService.watchAllMembers(),
                  builder: (context, snapshot) {
                    final members = (snapshot.data?.docs ?? [])
                        .map(Member.fromDoc)
                        .where((m) => m.isApproved)
                        .where((m) =>
                            _query.isEmpty ||
                            m.name.toLowerCase().contains(_query.toLowerCase()) ||
                            m.schoolName.toLowerCase().contains(_query.toLowerCase()))
                        .toList();

                    if (members.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: AppDimensions.lg),
                        child: Center(
                          child: Text(
                            LocaleService.isEnglish ? 'No members found' : 'কোনো সদস্য পাওয়া যায়নি',
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

              const SizedBox(height: AppDimensions.lg),
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  labelText: AppStrings.amount,
                  prefixIcon: Icon(Icons.payments_rounded, color: AppColors.primary),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: _descriptionController,
                style: AppTextStyles.bodyLarge,
                decoration: InputDecoration(
                  labelText: AppStrings.descriptionOptional,
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
                label: AppStrings.addPayment,
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

class _SelectedMemberCard extends StatelessWidget {
  final Member member;
  final VoidCallback onChange;

  const _SelectedMemberCard({required this.member, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return PremiumCard(
      child: Row(
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
              ],
            ),
          ),
          TextButton(
            onPressed: onChange,
            child: Text(AppStrings.changeMember),
          ),
        ],
      ),
    );
  }
}
