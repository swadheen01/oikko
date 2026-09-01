import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../widgets/gradient_button.dart';

class EmailVerificationScreen extends StatefulWidget {
  final VoidCallback onVerified;
  const EmailVerificationScreen({super.key, required this.onVerified});

  @override
  State<EmailVerificationScreen> createState() => _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _authService = AuthService();
  bool _isChecking = false;
  bool _isResending = false;
  String? _message;

  Future<void> _checkVerified() async {
    setState(() => _isChecking = true);
    final verified = await _authService.reloadAndCheckVerified();
    setState(() {
      _isChecking = false;
      _message = verified ? null : AppStrings.stillNotVerified;
    });
    if (verified) widget.onVerified();
  }

  Future<void> _resend() async {
    setState(() => _isResending = true);
    await _authService.resendVerificationEmail();
    setState(() {
      _isResending = false;
      _message = AppStrings.verifyEmailSubtitle;
    });
  }

  @override
  Widget build(BuildContext context) {
    final email = _authService.currentUser?.email ?? '';

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: AppGradients.screenBackground),
        child: SafeArea(
          child: Column(
            children: [
              // Root screen (shown by AuthWrapper), so there's nothing to
              // pop — "back" signs out, which routes to the login screen.
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.sm),
                  child: IconButton(
                    onPressed: () => _authService.signOut(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                    tooltip: LocaleService.isEnglish ? 'Back to login' : 'লগইনে ফিরুন',
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.lg),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    gradient: AppGradients.primary,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 24),
                Text(AppStrings.verifyEmailTitle, style: AppTextStyles.h2, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  '${AppStrings.verifyEmailSubtitle}\n$email',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(AppStrings.verifyEmailInstruction, style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
                if (_message != null) ...[
                  const SizedBox(height: AppDimensions.md),
                  Text(_message!, style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary)),
                ],
                const SizedBox(height: AppDimensions.xl),
                GradientButton(
                  label: AppStrings.iveVerified,
                  isLoading: _isChecking,
                  onPressed: _checkVerified,
                  icon: Icons.refresh_rounded,
                ),
                const SizedBox(height: AppDimensions.md),
                TextButton(
                  onPressed: _isResending ? null : _resend,
                  child: Text(
                    AppStrings.resendEmail,
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.primary, fontWeight: FontWeight.w600),
                  ),
                ),
                    ],
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