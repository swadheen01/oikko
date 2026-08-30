/// Firestore collection name constants — avoids typos like "member" vs
/// "members" scattered across the codebase. Matches the data model in
/// section 4.4 of the planning doc.
class FirestorePaths {
  FirestorePaths._();

  static const String members = 'members';
  static const String transactions = 'transactions';
  static const String notices = 'notices';
  static const String welfareRequests = 'welfare_requests';
  static const String polls = 'polls';
  static const String linkRequests = 'link_requests';

  /// Private per-member inbox (e.g. "your payment was recorded"). Each doc
  /// carries a `memberId`; a member reads only their own, so unlike
  /// `notices` (which everyone sees) these can hold personal detail like an
  /// amount without leaking it to the whole association.
  static const String notifications = 'notifications';

  /// The elected branch committee shown on the About page. Seeded lazily
  /// from the app's built-in defaults; admins can edit each member (name,
  /// designation, photo). Doc IDs are fixed slots `c0`..`c4`.
  static const String committee = 'committee';
}
