import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_gradients.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/member.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';

class ProfileMatchScreen extends StatelessWidget {
  final Member member;
  final String currentUserUid;
  final String currentPhone;

  const ProfileMatchScreen({
    super.key,
    required this.member,
    required this.currentUserUid,
    required this.currentPhone,
  });

  @override
  Widget build(BuildContext context) {
    final firestoreService = FirestoreService();

    return GradientScaffold(
      body: SafeArea(
        child: Padding(
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.lg),
                decoration: BoxDecoration(
                  gradient: AppGradients.heroCard,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusXl),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: AppTextStyles.h2.copyWith(color: Colors.white),
                    ),
                    if (member.nameEnglish.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        member.nameEnglish,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppDimensions.md),
                    Text(
                      member.schoolName,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      member.designation,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white.withValues(alpha: 0.9),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppDimensions.xl),
              Text(
                LocaleService.isEnglish ? 'Is this your profile?' : 'এটা আপনার প্রোফাইল?',
                style: AppTextStyles.h2,
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                LocaleService.isEnglish
                    ? 'If so, a link request will be sent to the admin.'
                    : 'যদি তাই হয়, তাহলে অ্যাডমিনকে লিংক রিকুয়েস্ট পাঠানো হবে।',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.xl),
              GradientButton(
                label: AppStrings.thisIsMe,
                icon: Icons.check_rounded,
                onPressed: () async {
                  await firestoreService.createLinkRequest(
                    memberId: member.id,
                    requestedByUid: currentUserUid,
                    requestedPhone: currentPhone,
                    requestedEmail: FirebaseAuth.instance.currentUser?.email ?? '',
                  );

                  // Best-effort: admins should hear about this immediately,
                  // but a push failure here shouldn't undo the request that
                  // was already saved above.
                  try {
                    await NotificationService().sendToAdmins(
                      title: LocaleService.isEnglish
                          ? 'New connection request'
                          : 'নতুন সংযোগ অনুরোধ',
                      body: LocaleService.isEnglish
                          ? '${member.name} wants to connect their account.'
                          : '${member.name} তার একাউন্ট সংযুক্ত করতে চান।',
                    );
                  } catch (_) {}

                  if (context.mounted) {
                    Navigator.of(context).popUntil((route) => route.isFirst);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppStrings.linkRequestSent,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
