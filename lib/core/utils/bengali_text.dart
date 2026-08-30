/// Bengali text normalisation.
///
/// Three Bengali letters can be written two different ways that look
/// identical on screen but are different character sequences:
///
///   য়  =  U+09DF            or  U+09AF + U+09BC  (য + nukta)
///   ড়  =  U+09DC            or  U+09A1 + U+09BC
///   ঢ়  =  U+09DD            or  U+09A2 + U+09BC
///
/// Which one you get depends on the keyboard or converter that produced the
/// text, so the same word from two sources may not compare equal. Unicode's
/// NFC normalisation does *not* fix this — these are composition exclusions,
/// so NFC leaves the decomposed form decomposed.
///
/// This bit the designation sort: the roster (converted from Bijoy) stores
/// সিনিয়র with U+09DF, while the source literal in the ranking table used
/// the decomposed form, so "সিনিয়র শিক্ষক" never matched its tier and sorted
/// below সহকারী শিক্ষক.
class BengaliText {
  BengaliText._();

  static const _nukta = '়';
  static const _pairs = <String, String>{
    'য$_nukta': 'য়', // য + ় -> য়
    'ড$_nukta': 'ড়', // ড + ় -> ড়
    'ঢ$_nukta': 'ঢ়', // ঢ + ় -> ঢ়
  };

  /// Collapses the decomposed forms to their single-character equivalents,
  /// so two spellings of the same word compare equal. Apply to *both* sides
  /// of any comparison.
  static String normalize(String input) {
    if (input.isEmpty) return input;
    var out = input;
    for (final entry in _pairs.entries) {
      if (out.contains(entry.key)) {
        out = out.replaceAll(entry.key, entry.value);
      }
    }
    return out;
  }

  /// Normalised and lower-cased — the usual form for matching and search.
  static String key(String input) => normalize(input).toLowerCase().trim();
}
