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
}
