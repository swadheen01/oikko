import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// School selector used above every member list.
///
/// A plain DropdownButton was the obvious choice but works badly here: with
/// 27 schools whose Bengali names run to five or six words, the menu items
/// truncate, there's no way to search, and the popup covers most of the
/// screen anyway. This opens a sheet instead — searchable, showing each
/// school's teacher count, and with room for the full name on one line.
class SchoolFilterField extends StatelessWidget {
  /// School name -> number of members, used for the counts and ordering.
  final Map<String, int> counts;
  final String? selected;
  final ValueChanged<String?> onChanged;

  const SchoolFilterField({
    super.key,
    required this.counts,
    required this.selected,
    required this.onChanged,
  });

  String get _allLabel =>
      LocaleService.isEnglish ? 'All schools' : 'সব বিদ্যালয়';

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SchoolSheet(
        counts: counts,
        selected: selected,
        allLabel: _allLabel,
      ),
    );
    // A dismissed sheet returns null, which is indistinguishable from
    // "All schools" — so the sheet returns a sentinel for a real clear.
    if (picked == null) return;
    onChanged(picked == _kAll ? null : picked);
  }

  @override
  Widget build(BuildContext context) {
    final isAll = selected == null;

    // Kept visibly "active" even with nothing selected — a colored icon,
    // a clear border and a solid surface — so it reads as a real control
    // to tap, not faded-out placeholder text that's easy to miss.
    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.md, vertical: 13,
        ),
        decoration: BoxDecoration(
          color: isAll
              ? AppColors.surface
              : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: isAll ? 0.35 : 0.55),
            width: 1.4,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.12),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppDimensions.radiusSm),
              ),
              child: Icon(Icons.school_rounded, size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: AppDimensions.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleService.isEnglish
                        ? 'Filter by school'
                        : 'বিদ্যালয় অনুযায়ী দেখুন',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                      fontSize: 10,
                    ),
                  ),
                  Text(
                    selected ?? _allLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimary,
                      fontWeight: isAll ? FontWeight.w600 : FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            if (!isAll)
              InkWell(
                onTap: () => onChanged(null),
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Icon(Icons.close_rounded, size: 18, color: AppColors.primary),
                ),
              )
            else
              Icon(Icons.expand_more_rounded, size: 22, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

/// Sentinel meaning "clear the filter", so it can be told apart from the
/// null a dismissed sheet returns.
const String _kAll = '__all__';

class _SchoolSheet extends StatefulWidget {
  final Map<String, int> counts;
  final String? selected;
  final String allLabel;

  const _SchoolSheet({
    required this.counts,
    required this.selected,
    required this.allLabel,
  });

  @override
  State<_SchoolSheet> createState() => _SchoolSheetState();
}

class _SchoolSheetState extends State<_SchoolSheet> {
  final _controller = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final schools = widget.counts.keys
        .where((s) => q.isEmpty || s.toLowerCase().contains(q))
        .toList()
      // Biggest schools first so the main institutions are reachable
      // without scrolling; ties fall back to name order.
      ..sort((a, b) {
        final bySize = widget.counts[b]!.compareTo(widget.counts[a]!);
        return bySize != 0 ? bySize : a.compareTo(b);
      });

    final total = widget.counts.values.fold<int>(0, (sum, n) => sum + n);

    return DraggableScrollableSheet(
      initialChildSize: 0.75,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppDimensions.radiusXl),
          ),
        ),
        child: Column(
          children: [
            const SizedBox(height: AppDimensions.sm),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    LocaleService.isEnglish ? 'Choose a school' : 'বিদ্যালয় নির্বাচন করুন',
                    style: AppTextStyles.h3,
                  ),
                  const SizedBox(height: AppDimensions.md),
                  TextField(
                    controller: _controller,
                    autofocus: false,
                    onChanged: (v) => setState(() => _query = v),
                    decoration: InputDecoration(
                      hintText: LocaleService.isEnglish
                          ? 'Search school'
                          : 'বিদ্যালয় খুঁজুন',
                      prefixIcon: Icon(Icons.search_rounded, color: AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.fromLTRB(
                  AppDimensions.lg, 0, AppDimensions.lg, AppDimensions.xl,
                ),
                children: [
                  if (q.isEmpty)
                    _SchoolTile(
                      name: widget.allLabel,
                      count: total,
                      selected: widget.selected == null,
                      onTap: () => Navigator.of(context).pop(_kAll),
                    ),
                  for (final s in schools)
                    _SchoolTile(
                      name: s,
                      count: widget.counts[s]!,
                      selected: widget.selected == s,
                      onTap: () => Navigator.of(context).pop(s),
                    ),
                  if (schools.isEmpty)
                    Padding(
                      padding: const EdgeInsets.all(AppDimensions.xl),
                      child: Center(
                        child: Text(
                          LocaleService.isEnglish
                              ? 'No school found'
                              : 'কোনো বিদ্যালয় পাওয়া যায়নি',
                          style: AppTextStyles.bodyMedium,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SchoolTile extends StatelessWidget {
  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  const _SchoolTile({
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.sm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.md, vertical: 12,
          ),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.primary.withValues(alpha: 0.12)
                : AppColors.surfaceMuted,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle_rounded : Icons.school_rounded,
                size: 18,
                color: selected ? AppColors.primary : AppColors.textSecondary,
              ),
              const SizedBox(width: AppDimensions.sm),
              Expanded(
                child: Text(
                  name,
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppDimensions.sm),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                  color: selected ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
                ),
                child: Text(
                  '$count',
                  style: AppTextStyles.caption.copyWith(
                    color: selected ? Colors.white : AppColors.textSecondary,
                    fontWeight: FontWeight.w800,
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
