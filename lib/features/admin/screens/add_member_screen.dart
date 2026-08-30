import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../directory/widgets/school_autocomplete_field.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

/// Admin-only: pre-provision a member record ahead of that teacher ever
/// opening the app (planning doc section 4.9). Only the name is required —
/// everything else can be filled in later, either by the admin or by the
/// teacher themself via Edit Profile once they've connected their account
/// with the generated Member ID. Stays open after each save (clearing the
/// form) so ~500 members can be entered back-to-back in one sitting.
class AddMemberScreen extends StatefulWidget {
  const AddMemberScreen({super.key});

  @override
  State<AddMemberScreen> createState() => _AddMemberScreenState();
}

class _AddMemberScreenState extends State<AddMemberScreen> {
  final _firestoreService = FirestoreService();
  final _nameController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _phoneController = TextEditingController();
  final _schoolController = TextEditingController();
  final _designationController = TextEditingController();

  bool _isSaving = false;
  String? _lastGeneratedCode;
  int _addedCount = 0;

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _phoneController.dispose();
    _schoolController.dispose();
    _designationController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleService.isEnglish ? 'Name is required' : 'নাম আবশ্যক')),
      );
      return;
    }

    setState(() {
      _isSaving = true;
      _lastGeneratedCode = null;
    });

    try {
      final code = await _firestoreService.createMemberByAdmin(
        name: name,
        nameEn: _nameEnController.text.trim(),
        phone: _phoneController.text.trim(),
        schoolName: _schoolController.text.trim(),
        designation: _designationController.text.trim(),
      );

      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _lastGeneratedCode = code;
        _addedCount++;
        _nameController.clear();
        _nameEnController.clear();
        _phoneController.clear();
        _schoolController.clear();
        _designationController.clear();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${AppStrings.errorGeneric}: ${_describeError(e)}')),
      );
    }
  }

  String _describeError(Object e) {
    if (e is FirebaseException) return '${e.code}: ${e.message ?? e.code}';
    return e.toString();
  }

  void _copyCode() {
    final code = _lastGeneratedCode;
    if (code == null) return;
    Clipboard.setData(ClipboardData(text: code));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppStrings.idCopied), backgroundColor: AppColors.success),
    );
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
              Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                  ),
                  const Spacer(),
                  if (_addedCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                      ),
                      child: Text(
                        LocaleService.isEnglish ? 'Added: $_addedCount' : 'যোগ হয়েছে: $_addedCount',
                        style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.w700),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              Text(AppStrings.addMember, style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.lg),

              if (_lastGeneratedCode != null) ...[
                _GeneratedCodeCard(code: _lastGeneratedCode!, onCopy: _copyCode),
                const SizedBox(height: AppDimensions.lg),
              ],

              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameController,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        labelText: LocaleService.isEnglish ? 'Name' : 'নাম',
                        prefixIcon: Icon(Icons.person_rounded, color: AppColors.primary),
                      ),
                    ),
                    // Ordered to match the admin's own member list — name,
                    // school, mobile — so entries can be typed straight
                    // down the page without hunting between fields.
                    const SizedBox(height: AppDimensions.md),
                    SchoolAutocompleteField(
                      controller: _schoolController,
                      label: LocaleService.isEnglish ? 'School' : 'বিদ্যালয়',
                    ),
                    const SizedBox(height: AppDimensions.md),
                    TextFormField(
                      controller: _phoneController,
                      keyboardType: TextInputType.phone,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        labelText: LocaleService.isEnglish ? 'Mobile number' : 'মোবাইল নম্বর',
                        prefixIcon: Icon(Icons.phone_rounded, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    TextFormField(
                      controller: _designationController,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        labelText: LocaleService.isEnglish ? 'Designation (optional)' : 'পদবী (ঐচ্ছিক)',
                        prefixIcon: Icon(Icons.badge_rounded, color: AppColors.primary),
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    TextFormField(
                      controller: _nameEnController,
                      style: AppTextStyles.bodyLarge,
                      decoration: InputDecoration(
                        labelText: LocaleService.isEnglish ? 'Name in English (optional)' : 'নাম ইংরেজিতে (ঐচ্ছিক)',
                        prefixIcon: Icon(Icons.person_outline_rounded, color: AppColors.primary),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.xl),
              GradientButton(
                label: _lastGeneratedCode != null ? AppStrings.addAnother : AppStrings.addMember,
                isLoading: _isSaving,
                onPressed: _save,
                icon: Icons.person_add_rounded,
              ),
              const SizedBox(height: AppDimensions.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeneratedCodeCard extends StatelessWidget {
  final String code;
  final VoidCallback onCopy;

  const _GeneratedCodeCard({required this.code, required this.onCopy});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.lg),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: AppColors.success, size: 18),
              const SizedBox(width: 6),
              Text(AppStrings.memberAdded, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.success, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: AppDimensions.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  code,
                  style: AppTextStyles.display.copyWith(color: AppColors.textPrimary, fontSize: 28, letterSpacing: 2),
                ),
              ),
              IconButton(
                onPressed: onCopy,
                icon: Icon(Icons.copy_rounded, color: AppColors.success),
                tooltip: AppStrings.copyId,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(AppStrings.memberIdGeneratedHint, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
