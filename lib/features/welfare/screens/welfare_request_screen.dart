import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/member.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';

class WelfareRequestScreen extends StatefulWidget {
  final Member member;

  const WelfareRequestScreen({super.key, required this.member});

  @override
  State<WelfareRequestScreen> createState() => _WelfareRequestScreenState();
}

class _WelfareRequestScreenState extends State<WelfareRequestScreen> {
  final _reasonController = TextEditingController();
  final _amountController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void dispose() {
    _reasonController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    final reason = _reasonController.text.trim();
    final amountText = _amountController.text.trim();

    if (reason.isEmpty || amountText.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('সকল ফিল্ড পূরণ করুন')));
      return;
    }

    final amount = double.tryParse(amountText);
    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: const Text('সঠিক টাকার পরিমাণ লিখুন')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestoreService.createWelfareRequest(
        memberId: widget.member.id,
        reason: reason,
        amountRequested: amount,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('অনুরোধ জমা দেওয়া হয়েছে'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ত্রুটি ঘটেছে')));
      }
    }
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
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.arrow_back_rounded),
                style: IconButton.styleFrom(backgroundColor: AppColors.surface),
              ),
              const SizedBox(height: AppDimensions.md),
              Text(
                LocaleService.isEnglish ? 'Welfare fund request' : 'কল্যাণ তহবিল অনুরোধ',
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                LocaleService.isEnglish
                    ? 'Submit a request based on your need'
                    : 'আপনার প্রয়োজন অনুসারে অনুরোধ করুন',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.lg),
              TextFormField(
                controller: _reasonController,
                minLines: 4,
                maxLines: 6,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: LocaleService.isEnglish ? 'Describe the reason' : 'কারণ বা বিবরণ দিন',
                  // widthFactor: 1.0 is load-bearing — see the same fix in
                  // notice_create_screen.dart: without it Align eats the
                  // whole field width and the text wraps one char per line.
                  prefixIcon: Align(
                    widthFactor: 1.0,
                    alignment: Alignment.topLeft,
                    child: Icon(
                      Icons.description_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  hintText: LocaleService.isEnglish ? 'Amount needed (Taka)' : 'প্রয়োজনীয় টাকা (টাকায়)',
                  prefixIcon: Icon(
                    Icons.currency_pound_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.xl),
              GradientButton(
                label: LocaleService.isEnglish ? 'Submit request' : 'অনুরোধ জমা দিন',
                isLoading: _isLoading,
                onPressed: _submitRequest,
                icon: Icons.send_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
