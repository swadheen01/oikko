import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/firestore_paths.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/storage_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';
import 'committee_screen.dart';

/// Admin-only: edit one committee member — Bengali/English name, Bengali/
/// English designation, and photo. Writes to `committee/{docId}`, which
/// overrides the built-in default for that slot everywhere it's shown.
///
/// Pass [isNew] = true to create a brand-new member (a fresh Firestore doc
/// with a generated slot ID is created instead of overwriting an existing one).
class CommitteeEditScreen extends StatefulWidget {
  final CommitteeMember member;

  /// When true the screen is in "Add new member" mode — the slot ID is
  /// auto-generated and the save button creates a new doc instead of
  /// updating an existing one.
  final bool isNew;

  const CommitteeEditScreen({
    super.key,
    required this.member,
    this.isNew = false,
  });

  @override
  State<CommitteeEditScreen> createState() => _CommitteeEditScreenState();
}

class _CommitteeEditScreenState extends State<CommitteeEditScreen> {
  late final _nameBn = TextEditingController(
    text: widget.isNew ? '' : widget.member.nameBn,
  );
  late final _nameEn = TextEditingController(
    text: widget.isNew ? '' : widget.member.nameEn,
  );
  late final _desigBn = TextEditingController(
    text: widget.isNew ? '' : widget.member.designationBn,
  );
  late final _desigEn = TextEditingController(
    text: widget.isNew ? '' : widget.member.designationEn,
  );

  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _picker = ImagePicker();

  Uint8List? _pickedPhoto;
  bool _isSaving = false;
  bool _isDeleting = false;

  @override
  void dispose() {
    _nameBn.dispose();
    _nameEn.dispose();
    _desigBn.dispose();
    _desigEn.dispose();
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
    setState(() => _pickedPhoto = bytes);
  }

  Future<void> _save() async {
    final isEn = LocaleService.isEnglish;
    if (_nameBn.text.trim().isEmpty && _nameEn.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(isEn ? 'Name is required' : 'নাম আবশ্যক')),
      );
      return;
    }
    setState(() => _isSaving = true);

    // For new members, generate a unique slot ID based on current time.
    final docId = widget.isNew
        ? 'cx_${DateTime.now().millisecondsSinceEpoch}'
        : widget.member.docId;

    String photoUrl = widget.isNew ? '' : widget.member.photoUrl;
    String? photoError;
    if (_pickedPhoto != null) {
      try {
        photoUrl = await _storageService.uploadCommitteePhoto(
          slotId: docId,
          bytes: _pickedPhoto!,
        );
      } catch (e) {
        photoError = e.toString();
      }
    }

    try {
      await _firestoreService
          .collection(FirestorePaths.committee)
          .doc(docId)
          .set({
            'nameBn': _nameBn.text.trim(),
            'nameEn': _nameEn.text.trim(),
            'designationBn': _desigBn.text.trim(),
            'designationEn': _desigEn.text.trim(),
            'photoUrl': photoUrl,
            // Mark as dynamically added so the list can identify these
            // and place them at the end (after the built-in 55 slots).
            if (widget.isNew) 'isDynamic': true,
          });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            photoError == null
                ? (isEn
                      ? (widget.isNew ? 'Member added' : 'Committee updated')
                      : (widget.isNew
                            ? 'সদস্য যোগ করা হয়েছে'
                            : 'কমিটি আপডেট হয়েছে'))
                : (isEn
                      ? 'Saved, but the photo failed to upload'
                      : 'সংরক্ষণ হয়েছে, তবে ছবি আপলোড হয়নি'),
          ),
          backgroundColor: photoError == null
              ? AppColors.success
              : AppColors.warning,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${AppStrings.errorGeneric}: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    }
  }

  /// Removes this committee member from the visible list.
  ///
  /// **Built-in slots (c0..c54):** Cannot be fully deleted from the app
  /// because the hard-coded defaults in `kAllCommitteeDefaults` would bring
  /// them back. Instead, a `{hidden: true}` flag is written to Firestore.
  /// `mergeCommittee()` filters hidden members out of every rendered list.
  /// To restore a hidden member, an admin can simply edit them again and save.
  ///
  /// **Dynamically-added members (cx_… IDs):** The Firestore doc is the only
  /// record, so it is truly deleted and the member disappears permanently.
  Future<void> _delete() async {
    final isEn = LocaleService.isEnglish;
    final displayName = widget.member.nameBn.isNotEmpty
        ? widget.member.nameBn
        : widget.member.nameEn;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isEn ? 'Remove member?' : 'সদস্য মুছবেন?'),
        content: Text(
          isEn
              ? '"$displayName" will be removed from the committee list.'
              : '"$displayName" কে কমিটি তালিকা থেকে মুছে ফেলা হবে।',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(AppStrings.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(isEn ? 'Remove' : 'মুছুন'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      final ref = _firestoreService
          .collection(FirestorePaths.committee)
          .doc(widget.member.docId);

      if (widget.member.isDynamic) {
        // Dynamic members exist only in Firestore — hard delete is safe.
        await ref.delete();
      } else {
        // Built-in slots: soft-delete by writing hidden:true. The hard-coded
        // default stays in kAllCommitteeDefaults but mergeCommittee() hides it.
        // Admins can restore the member at any time by editing and re-saving.
        await ref.set({'hidden': true}, SetOptions(merge: true));
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Member removed' : 'সদস্য মুছে ফেলা হয়েছে'),
          backgroundColor: AppColors.danger,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
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
    final isEn = LocaleService.isEnglish;
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
              Text(
                widget.isNew
                    ? (isEn ? 'Add committee member' : 'কমিটি সদস্য যোগ করুন')
                    : (isEn ? 'Edit committee member' : 'কমিটি সদস্য সম্পাদনা'),
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: AppDimensions.lg),
              Center(
                child: GestureDetector(
                  onTap: _pickPhoto,
                  child: Stack(
                    children: [
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.35),
                            width: 2,
                          ),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _pickedPhoto != null
                            ? Image.memory(_pickedPhoto!, fit: BoxFit.cover)
                            : ((!widget.isNew && widget.member.hasPhoto)
                                  ? Image(
                                      image: widget.member.image,
                                      fit: BoxFit.cover,
                                    )
                                  : Icon(
                                      Icons.person_rounded,
                                      size: 44,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.5,
                                      ),
                                    )),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 15,
                          ),
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
                    isEn ? 'Change photo' : 'ছবি পরিবর্তন করুন',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              PremiumCard(
                child: Column(
                  children: [
                    _Field(
                      controller: _nameBn,
                      label: isEn ? 'Name (Bengali)' : 'নাম (বাংলা)',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _Field(
                      controller: _nameEn,
                      label: isEn ? 'Name (English)' : 'নাম (ইংরেজি)',
                      icon: Icons.person_outline_rounded,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _Field(
                      controller: _desigBn,
                      label: isEn ? 'Designation (Bengali)' : 'পদবী (বাংলা)',
                      icon: Icons.badge_rounded,
                    ),
                    const SizedBox(height: AppDimensions.md),
                    _Field(
                      controller: _desigEn,
                      label: isEn ? 'Designation (English)' : 'পদবী (ইংরেজি)',
                      icon: Icons.badge_outlined,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.xl),
              GradientButton(
                label: widget.isNew
                    ? (isEn ? 'Add member' : 'সদস্য যোগ করুন')
                    : (isEn ? 'Save' : 'সংরক্ষণ করুন'),
                isLoading: _isSaving,
                onPressed: _save,
                icon: widget.isNew
                    ? Icons.person_add_rounded
                    : Icons.check_rounded,
              ),
              // Delete button — only shown for existing (non-new) members.
              if (!widget.isNew) ...[
                const SizedBox(height: AppDimensions.md),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _isDeleting ? null : _delete,
                    icon: _isDeleting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(
                            Icons.delete_outline_rounded,
                            color: AppColors.danger,
                          ),
                    label: Text(
                      isEn ? 'Remove from committee' : 'কমিটি থেকে মুছুন',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.danger,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                        color: AppColors.danger.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          AppDimensions.radiusMd,
                        ),
                      ),
                    ),
                  ),
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

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;

  const _Field({
    required this.controller,
    required this.label,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      style: AppTextStyles.bodyLarge,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon, color: AppColors.primary),
      ),
    );
  }
}
