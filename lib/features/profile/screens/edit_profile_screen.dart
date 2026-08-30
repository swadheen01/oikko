import 'dart:typed_data';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/member.dart';
import '../../directory/widgets/school_autocomplete_field.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

/// Lets the signed-in member edit their own profile fields and upload a
/// profile photo — writes are constrained server-side to the "self-edit"
/// branch of the members security rule (role/status/authUid are protected).
class EditProfileScreen extends StatefulWidget {
  final Member member;

  /// True when shown as the one-time setup after a first Google sign-in:
  /// no back button, a "complete your profile" title, and on save it clears
  /// the setup flag and lets AuthWrapper route on instead of popping.
  final bool isInitialSetup;

  const EditProfileScreen({
    super.key,
    required this.member,
    this.isInitialSetup = false,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final _nameController = TextEditingController(text: widget.member.name);
  late final _nameEnController = TextEditingController(text: widget.member.nameEnglish);
  late final _schoolController = TextEditingController(text: widget.member.schoolName);
  late final _designationController = TextEditingController(text: widget.member.designation);
  late final _phoneController = TextEditingController(text: widget.member.phone);

  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _picker = ImagePicker();

  static const _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];
  late String? _bloodGroup = widget.member.bloodGroup.isNotEmpty ? widget.member.bloodGroup : null;

  Uint8List? _pickedPhotoBytes;
  bool _isSaving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _schoolController.dispose();
    _designationController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      imageQuality: 85,
    );
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() => _pickedPhotoBytes = bytes);
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(LocaleService.isEnglish ? 'Name is required' : 'নাম আবশ্যক')),
      );
      return;
    }

    setState(() => _isSaving = true);

    // Photo upload is attempted separately from the field save below: if
    // Cloud Storage rejects it (e.g. storage.rules not deployed yet), the
    // name/school/blood-group edits should still go through rather than
    // the whole save silently failing because of an unrelated photo error.
    String? photoUrl;
    String? photoError;
    if (_pickedPhotoBytes != null) {
      try {
        photoUrl = await _storageService.uploadProfilePhoto(
          memberId: widget.member.id,
          bytes: _pickedPhotoBytes!,
        );
      } catch (e) {
        photoError = _describeError(e);
      }
    }

    try {
      final updates = <String, dynamic>{
        'name': name,
        'nameEnglish': _nameEnController.text.trim(),
        'name_en': _nameEnController.text.trim(),
        'schoolName': _schoolController.text.trim(),
        'designation': _designationController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bloodGroup': _bloodGroup ?? '',
        if (photoUrl != null) 'photoUrl': photoUrl,
        // Clearing this lets AuthWrapper route a first-time Google user on
        // into the app once they've completed setup.
        if (widget.isInitialSetup) 'needsProfileSetup': false,
      };

      await _firestoreService.updateDoc(FirestorePaths.members, widget.member.id, updates);

      if (!mounted) return;

      // Setup mode is shown by AuthWrapper as the root (nothing to pop);
      // clearing the flag above makes it route to the shell on its own.
      if (widget.isInitialSetup) {
        AppSnackbar.success(AppStrings.profileUpdated);
        return;
      }

      if (photoError != null) {
        // Fields saved, but the photo specifically failed — surface that
        // separately instead of a blanket "something went wrong".
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              LocaleService.isEnglish
                  ? 'Profile saved, but the photo failed to upload: $photoError'
                  : 'প্রোফাইল সংরক্ষণ হয়েছে, কিন্তু ছবি আপলোড ব্যর্থ হয়েছে: $photoError',
            ),
            backgroundColor: AppColors.warning,
          ),
        );
        return;
      }

      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppStrings.profileUpdated),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppStrings.errorGeneric}: ${_describeError(e)}')),
        );
      }
    }
  }

  String _describeError(Object e) {
    if (e is FirebaseException) return '${e.code}: ${e.message ?? e.code}';
    if (e is StorageException) return '${e.statusCode ?? ''} ${e.message}'.trim();
    return e.toString();
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
              if (!widget.isInitialSetup)
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                ),
              const SizedBox(height: AppDimensions.md),
              Text(
                widget.isInitialSetup
                    ? (LocaleService.isEnglish ? 'Complete your profile' : 'আপনার প্রোফাইল সম্পূর্ণ করুন')
                    : AppStrings.editProfile,
                style: AppTextStyles.h1,
              ),
              if (widget.isInitialSetup) ...[
                const SizedBox(height: 6),
                Text(
                  LocaleService.isEnglish
                      ? 'Add your school, designation, phone and blood group so members can find you.'
                      : 'আপনার বিদ্যালয়, পদবী, ফোন ও রক্তের গ্রুপ যোগ করুন, যাতে সদস্যরা আপনাকে খুঁজে পান।',
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
                ),
              ],
              const SizedBox(height: AppDimensions.lg),

              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: AppDimensions.avatarLg / 2,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                        backgroundImage: _pickedPhotoBytes != null
                            ? MemoryImage(_pickedPhotoBytes!)
                            : (widget.member.photoUrl.isNotEmpty
                                ? NetworkImage(widget.member.photoUrl)
                                : null) as ImageProvider?,
                        child: _pickedPhotoBytes == null && widget.member.photoUrl.isEmpty
                            ? Text(
                                widget.member.name.isNotEmpty ? widget.member.name.characters.first : '?',
                                style: AppTextStyles.h1.copyWith(color: AppColors.primary),
                              )
                            : null,
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 16),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.sm),
                  child: Text(
                    AppStrings.changePhoto,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),

              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Field(
                      controller: _nameController,
                      label: LocaleService.isEnglish ? 'Name' : 'নাম',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _Field(
                      controller: _nameEnController,
                      label: LocaleService.isEnglish ? 'Name (English)' : 'নাম (ইংরেজিতে)',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    SchoolAutocompleteField(
                      controller: _schoolController,
                      label: LocaleService.isEnglish ? 'School' : 'বিদ্যালয়',
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _Field(
                      controller: _designationController,
                      label: LocaleService.isEnglish ? 'Designation' : 'পদবী',
                      icon: Icons.badge_rounded,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _Field(
                      controller: _phoneController,
                      label: LocaleService.isEnglish ? 'Phone' : 'ফোন নম্বর',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      LocaleService.isEnglish ? 'Blood group' : 'রক্তের গ্রুপ',
                      style: AppTextStyles.overline,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.favorite_rounded, size: 14, color: AppColors.danger),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            LocaleService.isEnglish
                                ? 'Please add your blood group — it helps our association find a donor quickly in an emergency.'
                                : 'অনুগ্রহ করে আপনার রক্তের গ্রুপ যোগ করুন — জরুরি প্রয়োজনে সমিতির সদস্যদের দ্রুত রক্তদাতা খুঁজে পেতে এটি সাহায্য করবে।',
                            style: AppTextStyles.caption.copyWith(color: AppColors.danger),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.sm),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _bloodGroups.map((bg) {
                        final selected = _bloodGroup == bg;
                        return GestureDetector(
                          onTap: () => setState(() => _bloodGroup = selected ? null : bg),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: selected ? AppColors.danger : AppColors.surfaceMuted,
                              borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                              border: Border.all(
                                color: selected ? AppColors.danger : AppColors.border,
                              ),
                            ),
                            child: Text(
                              bg,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: selected ? Colors.white : AppColors.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: AppDimensions.xl),
              GradientButton(
                label: AppStrings.save,
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
