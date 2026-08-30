import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  bool _obscurePassword = true;

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

  Future<void> _handleGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final cred = await _authService.signInWithGoogle();
      if (cred == null) {
        // User backed out of the Google picker — not an error.
        if (mounted) setState(() => _isLoading = false);
        return;
      }
      final user = cred.user!;
      // First-ever Google sign-in: provision a member record prefilled with
      // the Google profile. Missing fields (phone, school, etc.) are filled
      // in later via Edit Profile.
      final hasMember = await _firestoreService.hasMemberForAuthUid(user.uid);
      if (!hasMember) {
        await _firestoreService.createGoogleMember(
          authUid: user.uid,
          name: (user.displayName ?? '').trim(),
          email: user.email ?? '',
          photoUrl: user.photoURL ?? '',
        );
      }
      // AuthWrapper picks up the new login and routes automatically; this
      // screen is disposed, so don't touch state after this point.
      AppSnackbar.success(
        LocaleService.isEnglish ? 'Signed in with Google' : 'গুগল দিয়ে লগইন হয়েছে',
      );
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = _authService.friendlyError(e);
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = AppStrings.errorGeneric;
        });
      }
    }
  }

  Future<void> _handleForgotPassword() async {
    final isEn = LocaleService.isEnglish;
    final controller = TextEditingController(
      text: _identifierController.text.contains('@')
          ? _identifierController.text.trim()
          : '',
    );
    final email = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(isEn ? 'Reset password' : 'পাসওয়ার্ড রিসেট', style: AppTextStyles.h3),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isEn
                  ? 'Enter your account email — we\'ll send a reset link.'
                  : 'আপনার একাউন্টের ইমেইল দিন — আমরা রিসেট লিংক পাঠাবো।',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: AppDimensions.md),
            TextField(
              controller: controller,
              keyboardType: TextInputType.emailAddress,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'email@example.com',
                prefixIcon: Icon(Icons.email_rounded, color: AppColors.primary),
              ),
            ),
            const SizedBox(height: AppDimensions.sm),
            Text(
              isEn
                  ? '⚠️ Check your Spam / Junk folder for the reset link.'
                  : '⚠️ রিসেট লিংকের জন্য আপনার স্প্যাম / জাঙ্ক ফোল্ডার দেখুন।',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(isEn ? 'Cancel' : 'বাতিল'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text(isEn ? 'Send link' : 'লিংক পাঠান'),
          ),
        ],
      ),
    );
    if (email == null || email.isEmpty || !email.contains('@')) return;
    try {
      await _authService.sendPasswordResetEmail(email);
      AppSnackbar.success(
        isEn ? 'Reset link sent to $email' : '$email এ রিসেট লিংক পাঠানো হয়েছে',
      );
    } catch (_) {
      AppSnackbar.success(
        isEn
            ? 'If that email has an account, a reset link was sent.'
            : 'ইমেইলটিতে একাউন্ট থাকলে রিসেট লিংক পাঠানো হয়েছে।',
      );
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
                            obscureText: _obscurePassword,
                            style: AppTextStyles.bodyLarge,
                            decoration: InputDecoration(
                              hintText: AppStrings.passwordHint,
                              prefixIcon: Icon(
                                Icons.lock_rounded,
                                color: AppColors.primary,
                              ),
                              suffixIcon: IconButton(
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_rounded
                                      : Icons.visibility_off_rounded,
                                  color: AppColors.textSecondary,
                                ),
                                tooltip: _obscurePassword
                                    ? (LocaleService.isEnglish ? 'Show password' : 'পাসওয়ার্ড দেখুন')
                                    : (LocaleService.isEnglish ? 'Hide password' : 'পাসওয়ার্ড লুকান'),
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
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _isLoading ? null : _handleForgotPassword,
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(vertical: 4),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(
                                LocaleService.isEnglish ? 'Forgot password?' : 'পাসওয়ার্ড ভুলে গেছেন?',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppDimensions.sm),
                          GradientButton(
                            label: AppStrings.login,
                            isLoading: _isLoading,
                            onPressed: _handleLogin,
                            icon: Icons.arrow_forward_rounded,
                          ),
                          const SizedBox(height: AppDimensions.md),
                          Row(
                            children: [
                              Expanded(child: Divider(color: AppColors.border)),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: AppDimensions.sm),
                                child: Text(
                                  LocaleService.isEnglish ? 'or' : 'অথবা',
                                  style: AppTextStyles.caption.copyWith(color: AppColors.textSecondary),
                                ),
                              ),
                              Expanded(child: Divider(color: AppColors.border)),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.md),
                          _GoogleButton(
                            onPressed: _isLoading ? null : _handleGoogle,
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
          // Language toggle at top-right (drawn last so it appears on top),
          // dropped ~1 inch down from the very top so it isn't cramped
          // against the status bar / screen edge.
          const Positioned(right: 12, top: 96, child: LanguageToggle()),
        ],
      ),
    );
  }
}

/// The official multi-colour Google "G" logo, inlined as SVG so it needs no
/// network fetch or bundled asset.
const String _googleLogoSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48">'
    '<path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.72 17.74 9.5 24 9.5z"/>'
    '<path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/>'
    '<path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/>'
    '<path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/>'
    '</svg>';

/// White "Continue with Google" button with the real Google logo and a light
/// grey border (Google's own guideline colour) so it stays clearly visible
/// against a white/light card instead of blending in.
class _GoogleButton extends StatelessWidget {
  final VoidCallback? onPressed;
  const _GoogleButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        elevation: 1.5,
        shadowColor: Colors.black.withValues(alpha: 0.25),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          onTap: onPressed,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 13),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
              border: Border.all(color: const Color(0xFFDADCE0), width: 1.4),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SvgPicture.string(_googleLogoSvg, width: 20, height: 20),
                const SizedBox(width: 12),
                Text(
                  LocaleService.isEnglish ? 'Continue with Google' : 'গুগল দিয়ে চালিয়ে যান',
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: const Color(0xFF3C4043),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
