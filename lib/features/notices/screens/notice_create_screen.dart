import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';

class NoticeCreateScreen extends StatefulWidget {
  const NoticeCreateScreen({super.key});

  @override
  State<NoticeCreateScreen> createState() => _NoticeCreateScreenState();
}

/// Tappable field-styled tile used for the meeting date and time pickers.
class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _PickerTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: 14,
        ),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
          border: Border.all(color: AppColors.accentViolet.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppColors.accentViolet, size: 18),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Text(
                label,
                style: AppTextStyles.bodyMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoticeCreateScreenState extends State<NoticeCreateScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _locationController = TextEditingController();
  final _firestoreService = FirestoreService();
  bool _isEvent = false;
  bool _isMeeting = false;
  DateTime? _eventDate;
  TimeOfDay? _meetingTime;
  int _reminderMinutes = 30;
  bool _isLoading = false;

  static const _reminderOptions = [10, 15, 30, 60, 120];

  /// Combines the picked date and time. Meetings need both — the reminder
  /// fires relative to the start time, so a date alone isn't enough.
  DateTime? get _meetingStart {
    if (_eventDate == null) return null;
    final t = _meetingTime;
    if (t == null) return _eventDate;
    return DateTime(
      _eventDate!.year, _eventDate!.month, _eventDate!.day, t.hour, t.minute,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _submitNotice() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('সব ফিল্ড পূরণ করুন')));
      return;
    }

    if ((_isEvent || _isMeeting) && _eventDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ইভেন্টের তারিখ নির্বাচন করুন')),
      );
      return;
    }

    if (_isMeeting && _meetingTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleService.isEnglish
              ? 'Choose the meeting time'
              : 'সভার সময় নির্বাচন করুন'),
        ),
      );
      return;
    }

    // A reminder that would fire in the past is worse than none: it never
    // arrives and the admin has no idea why.
    final start = _meetingStart;
    if (_isMeeting &&
        start != null &&
        start.subtract(Duration(minutes: _reminderMinutes)).isBefore(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(LocaleService.isEnglish
              ? 'That meeting time is too soon for a $_reminderMinutes-minute reminder.'
              : 'এই সময়ের জন্য $_reminderMinutes মিনিট আগের রিমাইন্ডার দেওয়া সম্ভব নয়।'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in again before publishing.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _firestoreService.createNotice(
        title: title,
        body: body,
        postedBy: user.uid,
        eventDate: (_isEvent || _isMeeting) ? _meetingStart : null,
        location: (_isEvent || _isMeeting) ? _locationController.text.trim() : '',
        isMeeting: _isMeeting,
        reminderMinutes: _reminderMinutes,
      );

      // The notice itself is already posted at this point regardless of
      // what happens below — a push-send failure (e.g. the Edge Function
      // isn't deployed yet) shouldn't look like the whole action failed.
      String? pushError;
      try {
        await NotificationService().sendToAllMembers(title: title, body: body);
      } catch (e) {
        pushError = e.toString();
      }

      if (mounted) {
        // This screen is a tab inside AdminShell, not a pushed route, so
        // popping here would tear down the shell itself and leave a black
        // screen with no way back. Only pop when something actually pushed
        // us; otherwise reset the form and stay put.
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          setState(() {
            _isLoading = false;
            _titleController.clear();
            _bodyController.clear();
            _locationController.clear();
            _isEvent = false;
            _isMeeting = false;
            _eventDate = null;
            _meetingTime = null;
            _reminderMinutes = 30;
          });
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              pushError == null
                  ? 'নোটিশ প্রকাশ করা হয়েছে'
                  : 'নোটিশ প্রকাশ করা হয়েছে, কিন্তু পুশ নোটিফিকেশন পাঠানো যায়নি: $pushError',
            ),
            backgroundColor: pushError == null ? AppColors.success : AppColors.warning,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${LocaleService.isEnglish ? 'Error' : 'ত্রুটি ঘটেছে'}: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _meetingTime ?? const TimeOfDay(hour: 10, minute: 0),
    );
    if (picked != null) {
      setState(() => _meetingTime = picked);
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
              // Same reason as in _submitNotice: as a tab there is nothing
              // to go back to, and tapping it would black-screen the app.
              if (Navigator.of(context).canPop()) ...[
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                ),
                const SizedBox(height: AppDimensions.md),
              ],
              Text(
                LocaleService.isEnglish ? 'New notice' : 'নতুন নোটিশ',
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: AppDimensions.lg),
              TextFormField(
                controller: _titleController,
                decoration: InputDecoration(
                  hintText: LocaleService.isEnglish ? 'Notice title' : 'নোটিশের শিরোনাম',
                  prefixIcon: Icon(
                    Icons.title_rounded,
                    color: AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: AppDimensions.md),
              TextFormField(
                controller: _bodyController,
                minLines: 5,
                maxLines: 10,
                keyboardType: TextInputType.multiline,
                textAlignVertical: TextAlignVertical.top,
                decoration: InputDecoration(
                  hintText: LocaleService.isEnglish ? 'Full content' : 'বিস্তারিত বিষয়বস্তু',
                  // widthFactor: 1.0 is load-bearing — without it, Align
                  // expands to fill the full width of the field, leaving
                  // no room for the text itself (which then wraps one
                  // character per line). heightFactor stays null so the
                  // icon still pins to the top of the tall multiline box.
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
              Row(
                children: [
                  Checkbox(
                    value: _isEvent,
                    onChanged: (val) => setState(() {
                      _isEvent = val ?? false;
                      // Event and meeting both use eventDate; a meeting is
                      // just an event that also has a time and a reminder,
                      // so they can't both be on.
                      if (_isEvent) _isMeeting = false;
                    }),
                  ),
                  Text(LocaleService.isEnglish ? 'This is an event' : 'এটি একটি ইভেন্ট'),
                ],
              ),
              Row(
                children: [
                  Checkbox(
                    value: _isMeeting,
                    activeColor: AppColors.accentViolet,
                    onChanged: (val) => setState(() {
                      _isMeeting = val ?? false;
                      if (_isMeeting) _isEvent = false;
                    }),
                  ),
                  Expanded(
                    child: Text(
                      LocaleService.isEnglish
                          ? 'This is a meeting (send a reminder)'
                          : 'এটি একটি সভা (রিমাইন্ডার পাঠান)',
                    ),
                  ),
                ],
              ),
              if (_isMeeting) ...[
                const SizedBox(height: AppDimensions.md),
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.calendar_today_rounded,
                        label: _eventDate != null
                            ? '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}'
                            : (LocaleService.isEnglish ? 'Meeting date' : 'সভার তারিখ'),
                        onTap: _pickDate,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.sm),
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.schedule_rounded,
                        label: _meetingTime != null
                            ? _meetingTime!.format(context)
                            : (LocaleService.isEnglish ? 'Start time' : 'শুরুর সময়'),
                        onTap: _pickTime,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppDimensions.md),
                Text(
                  LocaleService.isEnglish ? 'Remind members before' : 'কত আগে মনে করিয়ে দেবে',
                  style: AppTextStyles.overline,
                ),
                const SizedBox(height: AppDimensions.sm),
                Wrap(
                  spacing: AppDimensions.sm,
                  children: _reminderOptions.map((minutes) {
                    final selected = _reminderMinutes == minutes;
                    return ChoiceChip(
                      selected: selected,
                      onSelected: (_) => setState(() => _reminderMinutes = minutes),
                      selectedColor: AppColors.accentViolet,
                      backgroundColor: AppColors.surface,
                      labelStyle: AppTextStyles.bodyMedium.copyWith(
                        color: selected ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                      label: Text(
                        minutes < 60
                            ? (LocaleService.isEnglish ? '$minutes min' : '$minutes মিনিট')
                            : (LocaleService.isEnglish
                                ? '${minutes ~/ 60} hr'
                                : '${minutes ~/ 60} ঘণ্টা'),
                      ),
                    );
                  }).toList(),
                ),
                const SizedBox(height: AppDimensions.md),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: AppStrings.location,
                    prefixIcon: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
              if (_isEvent) ...[
                const SizedBox(height: AppDimensions.md),
                InkWell(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.all(AppDimensions.md),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusLg,
                      ),
                      border: Border.all(color: AppColors.primary),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today_rounded,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: AppDimensions.md),
                        Text(
                          _eventDate != null
                              ? '${_eventDate!.day}/${_eventDate!.month}/${_eventDate!.year}'
                              : (LocaleService.isEnglish ? 'Choose a date' : 'তারিখ নির্বাচন করুন'),
                          style: AppTextStyles.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.md),
                TextFormField(
                  controller: _locationController,
                  decoration: InputDecoration(
                    hintText: AppStrings.location,
                    prefixIcon: Icon(
                      Icons.location_on_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: AppDimensions.xl),
              GradientButton(
                label: AppStrings.publishNotice,
                isLoading: _isLoading,
                onPressed: _submitNotice,
                icon: Icons.send_rounded,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
