import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/notice.dart';
import '../../../widgets/gradient_scaffold.dart';

class NoticeDetailScreen extends StatelessWidget {
  final Notice notice;

  const NoticeDetailScreen({super.key, required this.notice});

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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.surface,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
              ),
              const SizedBox(height: AppDimensions.md),
              Text(notice.title, style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.sm),
              Row(
                children: [
                  Text(
                    '${AppStrings.noticePostedBy}: ${notice.postedBy}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
              if (notice.createdAt != null) ...[
                const SizedBox(height: 4),
                Text(
                  _formatFullDate(notice.createdAt!),
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.lg),
              if (notice.isEvent && notice.eventDate != null) ...[
                Container(
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.eventDate, style: AppTextStyles.bodyMedium),
                      const SizedBox(height: 8),
                      Text(
                        _formatFullDate(notice.eventDate!),
                        style: AppTextStyles.h3.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      if (notice.location.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.location_on_rounded,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              notice.location,
                              style: AppTextStyles.bodyMedium,
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
              ],
              Text(notice.body, style: AppTextStyles.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    final months = LocaleService.isEnglish
        ? const [
            'January', 'February', 'March', 'April', 'May', 'June',
            'July', 'August', 'September', 'October', 'November', 'December',
          ]
        : const [
            'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
            'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর', 'ডিসেম্বর',
          ];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
