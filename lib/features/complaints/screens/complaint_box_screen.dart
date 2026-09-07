import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/services/admin_session.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/locale/locale_service.dart';
import '../../../models/complaint.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/premium_card.dart';

/// A single shared entry point for the anonymous complaint box: every member
/// can submit here, but only an admin also sees the submitted list below the
/// form — the same screen adapts to who opened it via the live
/// [AdminSession.isAdmin] notifier, so it needs no separate admin route.
///
/// Deliberately anonymous: no submitter identity is ever written (see
/// firestore.rules `complaints`), so even an admin reading the list cannot
/// tell who sent a given complaint.
class ComplaintBoxScreen extends StatefulWidget {
  const ComplaintBoxScreen({super.key});

  @override
  State<ComplaintBoxScreen> createState() => _ComplaintBoxScreenState();
}

class _ComplaintBoxScreenState extends State<ComplaintBoxScreen> {
  final _firestoreService = FirestoreService();
  final _controller = TextEditingController();
  bool _submitting = false;

  late final Stream<QuerySnapshot<Map<String, dynamic>>> _complaintsStream =
      _firestoreService.watchAllComplaints();

  @override
  void initState() {
    super.initState();
    // Opening the box clears the shared unread badge for every admin.
    if (AdminSession.isAdmin.value) {
      _firestoreService.markComplaintsRead().catchError((_) {});
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    setState(() => _submitting = true);
    try {
      await _firestoreService.submitComplaint(text);
      // Best-effort: lets admins know without having to keep checking the
      // box themselves. Never blocks the "sent" confirmation below.
      try {
        await NotificationService().sendToAdmins(
          title: LocaleService.isEnglish ? 'New complaint' : 'নতুন অভিযোগ',
          body: LocaleService.isEnglish
              ? 'An anonymous complaint was submitted.'
              : 'একটি অভিযোগ জমা পড়েছে।',
        );
      } catch (_) {}
      if (!mounted) return;
      _controller.clear();
      FocusScope.of(context).unfocus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            LocaleService.isEnglish
                ? 'Sent anonymously. Thank you.'
                : 'নাম প্রকাশ ছাড়াই পাঠানো হয়েছে। ধন্যবাদ।',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${LocaleService.isEnglish ? 'Could not send' : 'পাঠানো যায়নি'}: $e'),
          backgroundColor: AppColors.danger,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _delete(String id) async {
    try {
      await _firestoreService.deleteComplaint(id);
    } catch (_) {
      // Non-fatal — the list will just still show it.
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    if (date.year == now.year && date.month == now.month && date.day == now.day) {
      return LocaleService.isEnglish ? 'Today' : 'আজ';
    }
    return '${date.day}/${date.month}/${date.year}';
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
              if (Navigator.of(context).canPop()) ...[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                ),
                const SizedBox(height: AppDimensions.sm),
              ],
              Text(isEn ? 'Complaint box' : 'অভিযোগ বক্স', style: AppTextStyles.h1),
              const SizedBox(height: AppDimensions.sm),
              Text(
                isEn
                    ? 'Share a concern with the admins — no name is attached, not even to them.'
                    : 'অ্যাডমিনদের কাছে আপনার অভিযোগ জানান — কোনো নাম প্রকাশ হবে না, এমনকি তাদের কাছেও নয়।',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.lg),
              PremiumCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _controller,
                      maxLines: 5,
                      minLines: 3,
                      decoration: InputDecoration(
                        hintText: isEn
                            ? 'Write your complaint here…'
                            : 'এখানে আপনার অভিযোগ লিখুন…',
                      ),
                    ),
                    const SizedBox(height: AppDimensions.md),
                    GradientButton(
                      label: isEn ? 'Send anonymously' : 'নাম প্রকাশ ছাড়াই পাঠান',
                      icon: Icons.send_rounded,
                      isLoading: _submitting,
                      onPressed: _submit,
                    ),
                  ],
                ),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: AdminSession.isAdmin,
                builder: (context, isAdmin, _) {
                  if (!isAdmin) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: AppDimensions.xl),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEn ? 'Submitted complaints' : 'জমা হওয়া অভিযোগ',
                          style: AppTextStyles.h3,
                        ),
                        const SizedBox(height: AppDimensions.sm),
                        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                          stream: _complaintsStream,
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return Padding(
                                padding: const EdgeInsets.all(AppDimensions.lg),
                                child: Center(
                                  child: CircularProgressIndicator(color: AppColors.primary),
                                ),
                              );
                            }
                            final complaints =
                                (snapshot.data?.docs ?? []).map(Complaint.fromDoc).toList();
                            if (complaints.isEmpty) {
                              return Padding(
                                padding: const EdgeInsets.all(AppDimensions.lg),
                                child: Text(
                                  isEn ? 'No complaints yet' : 'এখনো কোনো অভিযোগ আসেনি',
                                  style: AppTextStyles.bodyMedium,
                                ),
                              );
                            }
                            return Column(
                              children: [
                                for (final c in complaints)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: AppDimensions.sm),
                                    child: PremiumCard(
                                      child: Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Icon(Icons.report_rounded, color: AppColors.danger, size: 18),
                                          const SizedBox(width: AppDimensions.sm),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(c.message, style: AppTextStyles.bodyMedium),
                                                if (c.createdAt != null) ...[
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _formatDate(c.createdAt!),
                                                    style: AppTextStyles.caption
                                                        .copyWith(color: AppColors.textSecondary),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            onPressed: () => _delete(c.id),
                                            visualDensity: VisualDensity.compact,
                                            icon: Icon(
                                              Icons.close_rounded,
                                              size: 18,
                                              color: AppColors.textSecondary,
                                            ),
                                            tooltip: isEn ? 'Dismiss' : 'মুছুন',
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
