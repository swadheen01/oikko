import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';

class PollCreateScreen extends StatefulWidget {
  const PollCreateScreen({super.key});

  @override
  State<PollCreateScreen> createState() => _PollCreateScreenState();
}

class _PollCreateScreenState extends State<PollCreateScreen> {
  final _questionController = TextEditingController();
  final _optionControllers = <TextEditingController>[];
  final _firestoreService = FirestoreService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _optionControllers.addAll(List.generate(2, (_) => TextEditingController()));
  }

  @override
  void dispose() {
    _questionController.dispose();
    for (final controller in _optionControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addOption() {
    setState(() {
      _optionControllers.add(TextEditingController());
    });
  }

  void _removeOption(int index) {
    if (_optionControllers.length > 2) {
      setState(() {
        _optionControllers[index].dispose();
        _optionControllers.removeAt(index);
      });
    }
  }

  Future<void> _submitPoll() async {
    final question = _questionController.text.trim();
    final options = _optionControllers
        .map((c) => c.text.trim())
        .where((o) => o.isNotEmpty)
        .toList();

    if (question.isEmpty || options.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('প্রশ্ন এবং কমপক্ষে ২টি অপশন প্রয়োজন')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw StateError('An authenticated admin is required to create a poll.');
      }
      await _firestoreService.createPoll(
        question: question,
        options: options,
        createdByUid: user.uid,
        createdByName: user.displayName ?? user.email ?? 'Admin',
      );

      String? pushError;
      try {
        await NotificationService().sendToAllMembers(
          title: LocaleService.isEnglish ? 'New poll' : 'নতুন পোল',
          body: question,
        );
      } catch (e) {
        pushError = e.toString();
      }

      if (mounted) {
        // Tab inside AdminShell, not a pushed route — popping would
        // destroy the shell and leave a black screen. See the same guard
        // in NoticeCreateScreen.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _isLoading = false;
            _questionController.clear();
            for (final c in _optionControllers) {
              c.dispose();
            }
            _optionControllers
              ..clear()
              ..addAll(List.generate(2, (_) => TextEditingController()));
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pushError == null
                  ? 'পোল তৈরি করা হয়েছে'
                  : 'পোল তৈরি করা হয়েছে, কিন্তু পুশ নোটিফিকেশন পাঠানো যায়নি: $pushError',
            ),
            backgroundColor: pushError == null ? AppColors.success : AppColors.warning,
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
              if (Navigator.of(context).canPop()) ...[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                ),
                const SizedBox(height: AppDimensions.md),
              ],
              Text(
                LocaleService.isEnglish ? 'New poll' : 'নতুন পোল',
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: AppDimensions.lg),
              TextFormField(
                controller: _questionController,
                decoration: InputDecoration(
                  hintText: LocaleService.isEnglish ? 'Question' : 'প্রশ্ন',
                  prefixIcon: Icon(
                    Icons.help_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.lg),
              Text(
                LocaleService.isEnglish ? 'Options' : 'অপশনগুলি',
                style: AppTextStyles.h3,
              ),
              const SizedBox(height: AppDimensions.md),
              ..._optionControllers.asMap().entries.map((e) {
                final index = e.key;
                final controller = e.value;

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppDimensions.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: controller,
                          decoration: InputDecoration(
                            hintText: LocaleService.isEnglish ? 'Option ${index + 1}' : 'অপশন ${index + 1}',
                            prefixIcon: Icon(
                              Icons.check_circle_rounded,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ),
                      if (_optionControllers.length > 2)
                        IconButton(
                          onPressed: () => _removeOption(index),
                          icon: const Icon(Icons.close_rounded),
                          color: AppColors.danger,
                        ),
                    ],
                  ),
                );
              }).toList(),
              const SizedBox(height: AppDimensions.md),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _addOption,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(LocaleService.isEnglish ? 'Add option' : 'অপশন যোগ করুন'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.xl),
              GradientButton(
                label: LocaleService.isEnglish ? 'Create poll' : 'পোল তৈরি করুন',
                isLoading: _isLoading,
                onPressed: _submitPoll,
                icon: Icons.send_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
