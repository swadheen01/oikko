import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../../../core/constants/app_dimensions.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../widgets/gradient_button.dart';
import '../../../widgets/gradient_scaffold.dart';
import '../../../widgets/premium_card.dart';

/// Admin-only: loads the association's roster (converted from the office's
/// Bijoy-encoded Word file into `assets/members_seed.json`) and creates a
/// member record for each person, complete with a shareable Member ID.
///
/// Safe to run more than once — anyone already in the database, matched on
/// name plus school, is skipped rather than duplicated.
class ImportMembersScreen extends StatefulWidget {
  const ImportMembersScreen({super.key});

  @override
  State<ImportMembersScreen> createState() => _ImportMembersScreenState();
}

class _ImportMembersScreenState extends State<ImportMembersScreen> {
  final _firestoreService = FirestoreService();

  List<Map<String, String>>? _rows;
  bool _isRunning = false;
  int _written = 0;
  int _total = 0;
  ImportResult? _result;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadRoster();
  }

  Future<void> _loadRoster() async {
    try {
      final raw = await rootBundle.loadString('assets/members_seed.json');
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      setState(() {
        _rows = list
            .map((e) => {
                  'name': (e['name'] ?? '').toString(),
                  'designation': (e['designation'] ?? '').toString(),
                  'school': (e['school'] ?? '').toString(),
                  'phone': (e['phone'] ?? '').toString(),
                })
            .toList();
      });
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _run() async {
    final rows = _rows;
    if (rows == null || _isRunning) return;

    setState(() {
      _isRunning = true;
      _error = null;
      _result = null;
      _written = 0;
      _total = rows.length;
    });

    try {
      final result = await _firestoreService.importMembers(
        rows,
        onProgress: (written, total) {
          if (!mounted) return;
          setState(() {
            _written = written;
            _total = total;
          });
        },
      );
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _result = result;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isRunning = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = LocaleService.isEnglish;
    final rows = _rows;

    final schools = <String>{for (final r in rows ?? const []) r['school'] ?? ''}
      ..remove('');

    return GradientScaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppDimensions.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (Navigator.of(context).canPop()) ...[
                IconButton(
                  onPressed: _isRunning ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_rounded),
                  style: IconButton.styleFrom(backgroundColor: AppColors.surface),
                ),
                const SizedBox(height: AppDimensions.md),
              ],
              Text(
                isEn ? 'Import member list' : 'সদস্য তালিকা ইমপোর্ট',
                style: AppTextStyles.h1,
              ),
              const SizedBox(height: AppDimensions.sm),
              Text(
                isEn
                    ? 'Adds every teacher from the association roster, each with their own Member ID. Running it again is safe — anyone already added is skipped.'
                    : 'সমিতির তালিকার সব শিক্ষককে যুক্ত করবে, প্রত্যেকের জন্য আলাদা সদস্য আইডিসহ। আবার চালালেও সমস্যা নেই — আগে যুক্ত হওয়া কেউ দ্বিতীয়বার যোগ হবে না।',
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: AppDimensions.lg),

              if (rows == null && _error == null)
                const Center(child: CircularProgressIndicator())
              else if (rows != null) ...[
                PremiumCard(
                  child: Row(
                    children: [
                      Expanded(
                        child: _Stat(
                          value: '${rows.length}',
                          label: isEn ? 'members' : 'জন সদস্য',
                          color: AppColors.primary,
                        ),
                      ),
                      Container(width: 1, height: 40, color: AppColors.border),
                      Expanded(
                        child: _Stat(
                          value: '${schools.length}',
                          label: isEn ? 'schools' : 'বিদ্যালয়',
                          color: AppColors.accentTeal,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
              ],

              if (_isRunning) ...[
                LinearProgressIndicator(
                  value: _total == 0 ? null : _written / _total,
                  minHeight: 8,
                  backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                ),
                const SizedBox(height: AppDimensions.sm),
                Text(
                  isEn ? 'Added $_written of $_total…' : '$_total জনের মধ্যে $_written জন যোগ হয়েছে…',
                  style: AppTextStyles.bodyMedium,
                ),
                const SizedBox(height: AppDimensions.lg),
              ],

              if (_result != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.success.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(color: AppColors.success.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.check_circle_rounded, color: AppColors.success),
                          const SizedBox(width: AppDimensions.sm),
                          Text(
                            isEn ? 'Import finished' : 'ইমপোর্ট সম্পন্ন',
                            style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        isEn
                            ? '${_result!.imported} added, ${_result!.skipped} already existed.'
                            : '${_result!.imported} জন যোগ হয়েছে, ${_result!.skipped} জন আগে থেকেই ছিলেন।',
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppDimensions.sm),
                      Text(
                        isEn
                            ? 'Member IDs are ready — open Members to share or export them.'
                            : 'সদস্য আইডি তৈরি হয়ে গেছে — "সদস্য তালিকা" থেকে শেয়ার বা এক্সপোর্ট করুন।',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
              ],

              if (_error != null) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(AppDimensions.md),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(AppDimensions.radiusLg),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.35)),
                  ),
                  child: Text(
                    '${AppStrings.errorGeneric}: $_error',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.danger),
                  ),
                ),
                const SizedBox(height: AppDimensions.lg),
              ],

              GradientButton(
                label: _result != null
                    ? (isEn ? 'Run again' : 'আবার চালান')
                    : (isEn ? 'Start import' : 'ইমপোর্ট শুরু করুন'),
                isLoading: _isRunning,
                onPressed: rows == null ? () {} : _run,
                icon: Icons.cloud_upload_rounded,
              ),
              const SizedBox(height: AppDimensions.xl),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: AppTextStyles.h1.copyWith(color: color, fontSize: 30),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTextStyles.caption),
      ],
    );
  }
}
