import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../../core/constants/app_dimensions.dart';
import '../../../core/locale/locale_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// School name field that suggests schools already in the database.
///
/// The directory groups members by the exact school string, so typing
/// "বানিয়াচং আদর্শ উচ্চ বিদ্যালয়" with one character different silently
/// creates a second group holding one person. Picking from the existing
/// names makes that mistake hard to make — while still allowing free text,
/// since a genuinely new school has to be typed the first time.
class SchoolAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final String label;

  const SchoolAutocompleteField({
    super.key,
    required this.controller,
    required this.label,
  });

  @override
  State<SchoolAutocompleteField> createState() => _SchoolAutocompleteFieldState();
}

class _SchoolAutocompleteFieldState extends State<SchoolAutocompleteField> {
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirestoreService().watchAllMembers(),
      builder: (context, snapshot) {
        // Ordered by how many members each school has, so the big schools
        // surface first when the query is short or empty.
        final counts = <String, int>{};
        for (final doc in snapshot.data?.docs ?? const []) {
          final s = (doc.data()['schoolName'] ?? '').toString().trim();
          if (s.isEmpty) continue;
          counts[s] = (counts[s] ?? 0) + 1;
        }
        final schools = counts.keys.toList()
          ..sort((a, b) {
            final bySize = counts[b]!.compareTo(counts[a]!);
            return bySize != 0 ? bySize : a.compareTo(b);
          });

        return RawAutocomplete<String>(
          textEditingController: widget.controller,
          focusNode: _focusNode,
          optionsBuilder: (value) {
            final q = value.text.trim().toLowerCase();
            if (q.isEmpty) return schools.take(8);
            final hits = schools.where((s) => s.toLowerCase().contains(q)).toList();
            // An exact match means there's nothing left to suggest.
            if (hits.length == 1 && hits.first.toLowerCase() == q) {
              return const Iterable<String>.empty();
            }
            return hits.take(8);
          },
          fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
            return TextFormField(
              controller: controller,
              focusNode: focusNode,
              style: AppTextStyles.bodyLarge,
              onFieldSubmitted: (_) => onSubmitted(),
              decoration: InputDecoration(
                labelText: widget.label,
                helperText: LocaleService.isEnglish
                    ? 'Pick an existing school to keep the grouping correct'
                    : 'তালিকা থেকে বিদ্যালয় বেছে নিলে গ্রুপিং ঠিক থাকবে',
                helperMaxLines: 2,
                prefixIcon: Icon(Icons.school_rounded, color: AppColors.primary),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            final list = options.toList();
            return Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(right: AppDimensions.lg * 2),
                child: Material(
                  elevation: 6,
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 260),
                    child: ListView.builder(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: list.length,
                      itemBuilder: (context, i) {
                        final s = list[i];
                        return InkWell(
                          onTap: () => onSelected(s),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.md, vertical: 11,
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.school_rounded,
                                    size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: AppDimensions.sm),
                                Expanded(
                                  child: Text(
                                    s,
                                    style: AppTextStyles.bodyMedium,
                                    maxLines: 2,
                                  ),
                                ),
                                const SizedBox(width: AppDimensions.sm),
                                Text(
                                  '${counts[s]}',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
