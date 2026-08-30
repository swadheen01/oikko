import 'dart:typed_data';

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
class CommitteeEditScreen extends StatefulWidget {
  final CommitteeMember member;
  const CommitteeEditScreen({super.key, required this.member});

  @override
  State<CommitteeEditScreen> createState() => _CommitteeEditScreenState();
}

class _CommitteeEditScreenState extends State<CommitteeEditScreen> {
  late final _nameBn = TextEditingController(text: widget.member.nameBn);
  late final _nameEn = TextEditingController(text: widget.member.nameEn);
  late final _desigBn = TextEditingController(text: widget.member.designationBn);
  late final _desigEn = TextEditingController(text: widget.member.designationEn);

  final _firestoreService = FirestoreService();
  final _storageService = StorageService();
  final _picker = ImagePicker();

  Uint8List? _pickedPhoto;
  bool _isSaving = false;

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

    String photoUrl = widget.member.photoUrl;
    String? photoError;
    if (_pickedPhoto != null) {
      try {
        photoUrl = await _storageService.uploadCommitteePhoto(
          slotId: widget.member.docId,
          bytes: _pickedPhoto!,
        );
      } catch (e) {
        photoError = e.toString();
      }
    }

    try {
      await _firestoreService
          .collection(FirestorePaths.committee)
          .doc(widget.member.docId)
          .set({
        'nameBn': _nameBn.text.trim(),
        'nameEn': _nameEn.text.trim(),
        'designationBn': _desigBn.text.trim(),
        'designationEn': _desigEn.text.trim(),
        'photoUrl': photoUrl,
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            photoError == null
                ? (isEn ? 'Committee updated' : 'কমিটি আপডেট হয়েছে')
                : (isEn
                    ? 'Saved, but the photo failed to upload'
                    : 'সংরক্ষণ হয়েছে, তবে ছবি আপলোড হয়নি'),
          ),
          backgroundColor: photoError == null ? AppColors.success : AppColors.warning,
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
              Text(isEn ? 'Edit committee member' : 'কমিটি সদস্য সম্পাদনা', style: AppTextStyles.h1),
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
                          border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 2),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: _pickedPhoto != null
                            ? Image.memory(_pickedPhoto!, fit: BoxFit.cover)
                            : (widget.member.hasPhoto
                                ? Image(image: widget.member.image, fit: BoxFit.cover)
                                : Icon(Icons.person_rounded,
                                    size: 44, color: AppColors.primary.withValues(alpha: 0.5))),
                      ),
                      Positioned(
                        right: 0,
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          child: const Icon(Icons.camera_alt_rounded, color: Colors.white, size: 15),
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
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              PremiumCard(
                child: Column(
                  children: [
                    _Field(controller: _nameBn, label: isEn ? 'Name (Bengali)' : 'নাম (বাংলা)', icon: Icons.person_rounded),
                    const SizedBox(height: AppDimensions.md),
                    _Field(controller: _nameEn, label: isEn ? 'Name (English)' : 'নাম (ইংরেজি)', icon: Icons.person_outline_rounded),
                    const SizedBox(height: AppDimensions.md),
                    _Field(controller: _desigBn, label: isEn ? 'Designation (Bengali)' : 'পদবী (বাংলা)', icon: Icons.badge_rounded),
                    const SizedBox(height: AppDimensions.md),
                    _Field(controller: _desigEn, label: isEn ? 'Designation (English)' : 'পদবী (ইংরেজি)', icon: Icons.badge_outlined),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.xl),
              GradientButton(
                label: isEn ? 'Save' : 'সংরক্ষণ করুন',
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

  const _Field({required this.controller, required this.label, required this.icon});

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
