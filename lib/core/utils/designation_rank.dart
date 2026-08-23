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
    final d = designation.toLowerCase().trim();
    if (d.isEmpty) return 99;

    for (var i = 0; i < _tiers.length; i++) {
      for (final keyword in _tiers[i]) {
        if (d.contains(keyword)) return i;
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
    // 3 — Assistant teacher.
    ['সহকারী শিক্ষক', 'সহকারী শিক্ষিকা', 'সহকারী', 'assistant teacher', 'asst teacher', 'assistant'],
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
}
