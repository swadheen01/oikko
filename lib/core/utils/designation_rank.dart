import 'bengali_text.dart';

/// Orders members by seniority for the roster, since `designation` is
/// free text and sorting it alphabetically puts an assistant teacher above
/// a head teacher.
///
/// Designations are entered in Bengali or English (and sometimes both), so
/// each rank matches on several spellings. Order of the checks matters:
/// "সহকারী প্রধান শিক্ষক" (assistant head teacher) contains "প্রধান", so it
/// has to be tested before plain "প্রধান" or every assistant head would sort
/// as a head teacher.
class DesignationRank {
  /// Lower comes first. Anything unrecognised sorts last, but still above
  /// members with no designation at all.
  static int of(String designation) {
    // Both sides go through BengaliText.key: the roster writes য় as one
    // character while these keywords may hold য + nukta, and the two are
    // unequal despite looking the same. Without this, সিনিয়র শিক্ষক missed
    // its tier and sorted below সহকারী শিক্ষক.
    final d = BengaliText.key(designation);
    if (d.isEmpty) return 99;

    for (var i = 0; i < _tiers.length; i++) {
      for (final keyword in _tiers[i]) {
        if (d.contains(BengaliText.key(keyword))) return i;
      }
    }
    return 90;
  }

  static const List<List<String>> _tiers = [
    // 0 — Assistant head teacher. Checked first: see the note above.
    ['সহকারী প্রধান', 'সহঃ প্রধান', 'assistant head', 'asst head', 'asst. head', 'vice principal'],
    // 1 — Head teacher / principal.
    ['প্রধান শিক্ষক', 'প্রধান শিক্ষিকা', 'প্রধান', 'head teacher', 'headmaster', 'head master', 'principal'],
    // 2 — Senior teacher.
    ['সিনিয়র', 'জ্যেষ্ঠ', 'senior'],
    // 3 — Assistant teacher. Deliberately not a bare 'সহকারী': that also
    // matches অফিস সহকারী (office assistant), which is support staff and
    // was landing among the assistant teachers.
    ['সহকারী শিক্ষক', 'সহকারী শিক্ষিকা', 'assistant teacher', 'asst teacher'],
    // 4 — Any other teaching role.
    ['শিক্ষক', 'শিক্ষিকা', 'teacher'],
  ];

  /// Head teacher outranks assistant head, but assistant head has to be
  /// pattern-matched first — so the display order swaps tiers 0 and 1.
  static int sortKey(String designation) {
    final r = of(designation);
    if (r == 0) return 1;
    if (r == 1) return 0;
    return r;
  }

  /// Sorts by seniority, then alphabetically by name within a tier.
  static int compare(String designationA, String nameA, String designationB, String nameB) {
    final byRank = sortKey(designationA).compareTo(sortKey(designationB));
    if (byRank != 0) return byRank;
    return nameA.toLowerCase().compareTo(nameB.toLowerCase());
  }

  /// Groups members by school, each school's staff ordered by seniority.
  ///
  /// Schools are ordered largest first, so the main institutions lead the
  /// list; members with no school recorded are collected under [noSchool]
  /// at the end rather than forming a blank-titled group.
  static List<MapEntry<String, List<T>>> groupBySchool<T>(
    List<T> members, {
    required String Function(T) school,
    required String Function(T) designation,
    required String Function(T) name,
    required String noSchool,
  }) {
    final groups = <String, List<T>>{};
    for (final m in members) {
      final key = school(m).trim().isEmpty ? noSchool : school(m).trim();
      groups.putIfAbsent(key, () => []).add(m);
    }

    for (final list in groups.values) {
      list.sort((a, b) => compare(
            designation(a), name(a), designation(b), name(b),
          ));
    }

    final entries = groups.entries.toList()
      ..sort((a, b) {
        if (a.key == noSchool) return 1;
        if (b.key == noSchool) return -1;
        final bySize = b.value.length.compareTo(a.value.length);
        return bySize != 0 ? bySize : a.key.compareTo(b.key);
      });
    return entries;
  }
}
