import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/utils/app_snackbar.dart';
import '../../../core/utils/validators.dart';
import '../../../widgets/app_logo.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/language_toggle.dart';
import '../../../widgets/premium_card.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  final _firestoreService = FirestoreService();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final identifier = _identifierController.text.trim();
      String email;

      if (identifier.contains('@')) {
        email = identifier;
      } else {
        // Phone identifier — resolve to the linked account's email first.
        final resolvedEmail = await _firestoreService.findEmailByPhone(
          identifier,
        );
        if (resolvedEmail == null) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'এই নম্বরে কোনো একাউন্ট পাওয়া যায়নি';
          });
          return;
        }
        email = resolvedEmail;
      }

      await _authService.signInWithEmail(
        email: email,
        password: _passwordController.text,
      );
      // AuthWrapper's authStateChanges stream picks this up automatically —
      // which also disposes this screen, so the confirmation has to go
      // through the app-level messenger rather than this Scaffold's.
      AppSnackbar.success(
        LocaleService.isEnglish ? 'Login successful' : 'সফলভাবে লগইন হয়েছে',
      );
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            height: 280,
            decoration: BoxDecoration(gradient: AppGradients.primary),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: AppDimensions.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  const AppLogo(size: 64, withGlassBackground: true),
                  const SizedBox(height: 20),
                  Text(
                    AppStrings.loginTitle,
                    style: AppTextStyles.h1.copyWith(
                      color: AppColors.textOnPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    AppStrings.loginSubtitle,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
                  ),
                  const SizedBox(height: 32),
                  PremiumCard(
                    padding: const EdgeInsets.all(AppDimensions.lg),
                    radius: AppDimensions.radiusXl,
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          TextFormField(
                            controller: _identifierController,
                            keyboardType: TextInputType.emailAddress,
                            style: AppTextStyles.bodyLarge,
                            decoration: InputDecoration(
                              hintText: AppStrings.identifierHint,
                              prefixIcon: Icon(
                                Icons.person_rounded,
                                color: AppColors.primary,
                              ),
                            ),
                            validator: Validators.emailOrPhone,
                          ),
                          const SizedBox(height: AppDimensions.md),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            style: AppTextStyles.bodyLarge,
                            decoration: InputDecoration(
                              hintText: AppStrings.passwordHint,
                              prefixIcon: Icon(
                                Icons.lock_rounded,
                                color: AppColors.primary,
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
                          const SizedBox(height: AppDimensions.lg),
                          GradientButton(
                            label: AppStrings.login,
                            isLoading: _isLoading,
                            onPressed: _handleLogin,
                            icon: Icons.arrow_forward_rounded,
                          ),
                          const SizedBox(height: AppDimensions.md),
                          Center(
                            child: TextButton(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              ),
                              child: Text(
                                AppStrings.dontHaveAccount,
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.xl),
                ],
              ),
            ),
          ),
          // Language toggle at top-right (drawn last so it appears on top)
          const Positioned(right: 12, top: 8, child: LanguageToggle()),
        ],
      ),
    );
  }
}
