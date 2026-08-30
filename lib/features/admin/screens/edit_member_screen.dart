import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/member.dart';
import '../../directory/widgets/school_autocomplete_field.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

/// Admin-only: correct a member's details.
///
/// The roster was imported from the association's own Word file, so typos
/// in a name or school came along with it — and a wrong school name is
/// worse than cosmetic, since the directory groups people by that exact
/// string, so one stray character splits a school into two.
///
/// Deliberately does not touch `role`, `status`, `authUid`, `isClaimed` or
/// `memberCode`: those are account-linking state, changed through the
/// linking and role flows, not by editing a profile.
class EditMemberScreen extends StatefulWidget {
  final Member member;

  const EditMemberScreen({super.key, required this.member});

  @override
  State<EditMemberScreen> createState() => _EditMemberScreenState();
}

class _EditMemberScreenState extends State<EditMemberScreen> {
  final _firestoreService = FirestoreService();

  late final _nameController = TextEditingController(text: widget.member.name);
  late final _schoolController = TextEditingController(text: widget.member.schoolName);
  late final _phoneController = TextEditingController(text: widget.member.phone);
  late final _designationController =
      TextEditingController(text: widget.member.designation);
  late final _nameEnController =
      TextEditingController(text: widget.member.nameEnglish);
  late final _bloodController = TextEditingController(text: widget.member.bloodGroup);

  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _schoolController.dispose();
    _phoneController.dispose();
    _designationController.dispose();
    _nameEnController.dispose();
    _bloodController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleService.isEnglish ? 'Name is required' : 'নাম আবশ্যক'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    final english = _nameEnController.text.trim();

    try {
      await _firestoreService.updateDoc(
        FirestorePaths.members,
        widget.member.id,
        {
          'name': name,
          'nameEnglish': english,
          // Older records were written with `name_en`; keep both in step so
          // whichever one a screen reads shows the corrected value.
          'name_en': english,
          'schoolName': _schoolController.text.trim(),
          'phone': _phoneController.text.trim(),
          'designation': _designationController.text.trim(),
          'bloodGroup': _bloodController.text.trim(),
        },
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocaleService.isEnglish ? 'Member updated' : 'তথ্য সংশোধন করা হয়েছে',
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

    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconButton(
                onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                isEn ? 'Edit member' : 'সদস্যের তথ্য সংশোধন',
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                isEn
                    ? 'Fixing a school name here also moves this member into the right group in the member list.'
                    : 'এখানে বিদ্যালয়ের নাম ঠিক করলে সদস্য তালিকাতেও তিনি সঠিক বিদ্যালয়ের নিচে চলে যাবেন।',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.lg),

              if (widget.member.memberCode.isNotEmpty) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.badge_rounded, size: 18, color: AppColors.primary),
                      const SizedBox(width: AppDimensions.sm),
                      Text(
                        isEn ? 'Member ID' : 'সদস্য আইডি',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const Spacer(),
                      Text(
                        widget.member.memberCode,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
              ],

              PremiumCard(
                child: Column(
                  children: [
                    _Field(
                      controller: _nameController,
                      label: isEn ? 'Name' : 'নাম',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    SchoolAutocompleteField(
                      controller: _schoolController,
                      label: isEn ? 'School' : 'বিদ্যালয়',
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _Field(
                      controller: _phoneController,
                      label: isEn ? 'Mobile number' : 'মোবাইল নম্বর',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _Field(
                      controller: _designationController,
                      label: isEn ? 'Designation' : 'পদবী',
                      icon: Icons.badge_rounded,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _Field(
                      controller: _bloodController,
                      label: isEn ? 'Blood group (optional)' : 'রক্তের গ্রুপ (ঐচ্ছিক)',
                      icon: Icons.bloodtype_rounded,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _Field(
                      controller: _nameEnController,
                      label: isEn ? 'Name in English (optional)' : 'নাম ইংরেজিতে (ঐচ্ছিক)',
                      icon: Icons.person_outline_rounded,
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.xl),
              GradientButton(
                label: isEn ? 'Save changes' : 'সংরক্ষণ করুন',
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final TextInputType? keyboardType;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}
