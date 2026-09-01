import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/language_toggle.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _nameEnController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _indexController = TextEditingController();
  DateTime? _joiningDate;
  DateTime? _mpoDate;

  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _nameController.dispose();
    _nameEnController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _indexController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;
    if (_passwordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = AppStrings.passwordMismatch);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final credential = await _authService.registerWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      final authUid = credential.user!.uid;
      final phone = _phoneController.text.trim();
      final nameEn = _nameEnController.text.trim();

      // Flow A (planning doc section 4.9): try to auto-claim a pre-existing
      // admin-entered record with this phone number, matching it to this
      // new login. Falls back to a fresh pending record if none exists.
      final index = _indexController.text.trim();
      final joining = _joiningDate == null ? '' : _isoDate(_joiningDate!);
      final mpo = _mpoDate == null ? '' : _isoDate(_mpoDate!);

      final existing = await _firestoreService.findUnclaimedMemberByPhone(
        phone,
      );
      if (existing != null) {
        await _firestoreService.claimMember(
          memberId: existing.id,
          authUid: authUid,
        );
        final updateData = {
          'email': _emailController.text.trim(),
          if (index.isNotEmpty) 'indexNumber': index,
          if (joining.isNotEmpty) 'joiningDate': joining,
          if (mpo.isNotEmpty) 'mpoDate': mpo,
        };
        if (nameEn.isNotEmpty) {
          updateData['nameEnglish'] = nameEn;
          updateData['name_en'] = nameEn;
        }
        await _firestoreService.updateDoc('members', existing.id, updateData);
      } else {
        await _firestoreService.createPendingMember(
          authUid: authUid,
          phone: phone,
          name: _nameController.text.trim(),
          nameEn: nameEn.isNotEmpty ? nameEn : null,
          indexNumber: index,
          joiningDate: joining,
          mpoDate: mpo,
        );
      }
      // AuthWrapper's authStateChanges stream picks up the new login and
      // routes to the EmailVerificationScreen automatically.
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = _authService.friendlyError(e);
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
        _errorMessage = AppStrings.errorGeneric;
      });
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate({required bool joining}) async {
    final now = DateTime.now();
    final initial = (joining ? _joiningDate : _mpoDate) ?? DateTime(now.year - 5);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1970),
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) {
      setState(() {
        if (joining) {
          _joiningDate = picked;
        } else {
          _mpoDate = picked;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GradientScaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.lg),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Language toggle at top-right
              const Align(
                alignment: Alignment.topRight,
                child: LanguageToggle(),
              ),
              const SizedBox(height: 20),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(
                  Icons.arrow_back_rounded,
                  color: AppColors.textPrimary,
                ),
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              ),
              const SizedBox(height: 16),
              Text(AppStrings.registerTitle, style: AppTextStyles.h1),
              const SizedBox(height: 4),
              Text(
                AppStrings.registerSubtitle,
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.lg),

              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  hintText: AppStrings.nameHint,
                  prefixIcon: Icon(
                    Icons.person_rounded,
                    color: AppColors.primary,
                  ),
                ),
                validator: Validators.required,
              ),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: _nameEnController,
                decoration: InputDecoration(
                  hintText: AppStrings.nameHintEn,
                  prefixIcon: Icon(
                    Icons.person_outline_rounded,
                    color: AppColors.primary,
                  ),
                ),
                // optional field; no validator
              ),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  hintText: AppStrings.emailHint,
                  prefixIcon: Icon(
                    Icons.email_rounded,
                    color: AppColors.primary,
                  ),
                ),
                validator: Validators.email,
              ),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  hintText: AppStrings.phoneHint,
                  prefixIcon: Icon(
                    Icons.phone_android_rounded,
                    color: AppColors.primary,
                  ),
                ),
                validator: Validators.phone,
              ),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: _indexController,
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  hintText: LocaleService.isEnglish ? 'Index number' : 'ইনডেক্স নম্বর',
                  prefixIcon: Icon(Icons.tag_rounded, color: AppColors.primary),
                ),
                // optional
              ),
              const SizedBox(height: AppDimensions.md),
              _DatePickerField(
                label: LocaleService.isEnglish ? 'Joining date' : 'যোগদানের তারিখ',
                icon: Icons.event_available_rounded,
                value: _joiningDate,
                onTap: () => _pickDate(joining: true),
              ),
              const SizedBox(height: AppDimensions.md),
              _DatePickerField(
                label: LocaleService.isEnglish ? 'MPO date' : 'এমপিও তারিখ',
                icon: Icons.event_note_rounded,
                value: _mpoDate,
                onTap: () => _pickDate(joining: false),
              ),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                decoration: InputDecoration(
                  hintText: AppStrings.passwordHint,
                  prefixIcon: Icon(
                    Icons.lock_rounded,
                    color: AppColors.primary,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    icon: Icon(
                      _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                validator: Validators.password,
              ),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: _obscureConfirm,
                decoration: InputDecoration(
                  hintText: AppStrings.confirmPasswordHint,
                  prefixIcon: Icon(
                    Icons.lock_rounded,
                    color: AppColors.primary,
                  ),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm),
                    icon: Icon(
                      _obscureConfirm ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
                validator: Validators.password,
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppDimensions.sm),
                Text(
                  _errorMessage!,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.danger,
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.md),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.sm),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
                  border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
                ),
                child: Text(
                  LocaleService.isEnglish
                      ? '⚠️ A verification email will be sent — check your Spam / Junk folder for the link.'
                      : '⚠️ একটি ভেরিফিকেশন ইমেইল পাঠানো হবে — লিংকের জন্য আপনার স্প্যাম / জাঙ্ক ফোল্ডার দেখুন।',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.warning,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              GradientButton(
                label: AppStrings.register,
                isLoading: _isLoading,
                onPressed: _handleRegister,
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

/// Tappable field that opens a date picker; shows the chosen date or a hint.
class _DatePickerField extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime? value;
  final VoidCallback onTap;

  const _DatePickerField({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final has = value != null;
    final text = has
        ? '${value!.day.toString().padLeft(2, '0')}/${value!.month.toString().padLeft(2, '0')}/${value!.year}'
        : label;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: InputDecorator(
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: AppColors.primary),
          suffixIcon: Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.textSecondary),
        ),
        child: Text(
          has ? '$label: $text' : label,
          style: AppTextStyles.bodyLarge.copyWith(
            color: has ? AppColors.textPrimary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
