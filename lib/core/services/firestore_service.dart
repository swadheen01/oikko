import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';

/// Central Firestore access layer. Implements the member auto-match /
/// link-request logic from planning doc section 4.9, plus generic
/// CRUD helpers reused by every feature module.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ---------------- MEMBERS ----------------

  /// Flow A (section 4.9): after OTP login, look for an existing
  /// admin-created member record with this phone number that hasn't
  /// been claimed yet.
  Future<DocumentSnapshot<Map<String, dynamic>>?> findUnclaimedMemberByPhone(
    String e164Phone,
  ) async {
    final query = await _db
        .collection(FirestorePaths.members)
        .where('phone', isEqualTo: e164Phone)
        .where('authUid', isNull: true)
        .limit(1)
        .get();
    return query.docs.isEmpty ? null : query.docs.first;
  }

  /// Links the given member document to the newly authenticated user
  /// (auto-claim). Enforced server-side by Firestore security rules
  /// (only allowed when authUid is currently null and phone matches).
  Future<void> claimMember({
    required String memberId,
    required String authUid,
  }) {
    return _db.collection(FirestorePaths.members).doc(memberId).update({
      'authUid': authUid,
      'isClaimed': true,
    });
  }

  /// Creates a brand-new pending member record for a first-time user
  /// with no pre-existing admin entry (fallback of Flow A).
  Future<void> createPendingMember({
    required String authUid,
    required String phone,
    required String name,
    String? nameEn,
  }) {
    final englishName = nameEn ?? '';
    return _db.collection(FirestorePaths.members).add({
      'name': name,
      'nameEnglish': englishName,
      'name_en': englishName,
      'phone': phone,
      'authUid': authUid,
      'isClaimed': true,
      'role': 'member',
      'status': 'pending',
      'photoUrl': '',
      'designation': '',
      'schoolName': '',
      'bloodGroup': '',
      'qualification': '',
      'email': '',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Resolves a phone number to its linked account's email, so the
  /// login screen can let the user sign in with either identifier.
  /// Returns null if no member record has that phone with an email set.
  Future<String?> findEmailByPhone(String phone) async {
    final query = await _db
        .collection(FirestorePaths.members)
        .where('phone', isEqualTo: phone)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    final email = query.docs.first.data()['email'] as String?;
    return (email != null && email.isNotEmpty) ? email : null;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchMemberByAuthUid(
    String authUid,
  ) {
    return _db
        .collection(FirestorePaths.members)
        .where('authUid', isEqualTo: authUid)
        .limit(1)
        .snapshots();
  }

  /// Directory listing — all approved members (for search/browse).
  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllMembers() {
    return _db.collection(FirestorePaths.members).orderBy('name').snapshots();
  }

  /// Flow B (section 4.9): unclaimed records for the "Find My Profile" search.
  Future<QuerySnapshot<Map<String, dynamic>>> searchUnclaimedByName(
    String query,
  ) {
    return _db
        .collection(FirestorePaths.members)
        .where('isClaimed', isEqualTo: false)
        .orderBy('name')
        .startAt([query])
        .endAt(['$query\uf8ff'])
        .get();
  }

  /// Admin bulk-adds a member record ahead of that teacher ever opening the
  /// app (planning doc section 4.9's "pre-provisioned records"). The doc ID
  /// is allocated up front so a short, human-shareable `memberCode` can be
  /// derived from it and stored on the same doc \u2014 no separate uniqueness
  /// check needed, since Firestore doc IDs are already globally unique.
  /// Returns the generated code so the UI can show/share it immediately.
  Future<String> createMemberByAdmin({
    required String name,
    String nameEn = '',
    String phone = '',
    String schoolName = '',
    String designation = '',
    String qualification = '',
    String bloodGroup = '',
  }) async {
    final docRef = _db.collection(FirestorePaths.members).doc();
    final code = docRef.id.substring(0, 6).toUpperCase();
    await docRef.set({
      'name': name,
      'nameEnglish': nameEn,
      'name_en': nameEn,
      'phone': phone,
      'schoolName': schoolName,
      'designation': designation,
      'qualification': qualification,
      'bloodGroup': bloodGroup,
      'email': '',
      'photoUrl': '',
      'role': 'member',
      'status': 'approved', // admin-entered records are pre-vetted
      'authUid': null,
      'isClaimed': false,
      'memberCode': code,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return code;
  }

  /// Admin-only: removes a member record along with everything that points
  /// at it. Deleting only the member doc would leave orphaned transactions
  /// still counted in the association's income totals (FinanceService sums
  /// every transaction, it doesn't join against members), plus dangling
  /// welfare and link requests that reference a member that no longer
  /// exists \u2014 so all of it goes in one batch.
  ///
  /// If the member was linked to a login, that account isn't deleted; it
  /// simply falls back to the "find my profile" screen on next launch.
  Future<void> deleteMemberAndData(String memberId) async {
    final transactions = await _db
        .collection(FirestorePaths.transactions)
        .where('memberId', isEqualTo: memberId)
        .get();
    final welfare = await _db
        .collection(FirestorePaths.welfareRequests)
        .where('memberId', isEqualTo: memberId)
        .get();
    final links = await _db
        .collection(FirestorePaths.linkRequests)
        .where('memberId', isEqualTo: memberId)
        .get();

    final batch = _db.batch();
    for (final doc in [...transactions.docs, ...welfare.docs, ...links.docs]) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.collection(FirestorePaths.members).doc(memberId));
    await batch.commit();
  }

  /// How many payment records would be destroyed by deleting this member \u2014
  /// shown in the delete confirmation so the admin isn't wiping out a
  /// payment history they didn't know was there.
  Future<int> countMemberTransactions(String memberId) async {
    final snapshot = await _db
        .collection(FirestorePaths.transactions)
        .where('memberId', isEqualTo: memberId)
        .count()
        .get();
    return snapshot.count ?? 0;
  }

  /// The code-entry counterpart to `searchUnclaimedByName` \u2014 looks up a
  /// single unclaimed member by their shareable `memberCode`.
  Future<DocumentSnapshot<Map<String, dynamic>>?> findUnclaimedMemberByCode(
    String code,
  ) async {
    final query = await _db
        .collection(FirestorePaths.members)
        .where('memberCode', isEqualTo: code.trim().toUpperCase())
        .where('isClaimed', isEqualTo: false)
        .limit(1)
        .get();
    return query.docs.isEmpty ? null : query.docs.first;
  }

  /// Promotes or demotes a member, keeping the two things that define
  /// "admin" in sync: the `role` field (which drives what the app shows)
  /// and the `admins/{authUid}` marker doc (which is what the security
  /// rules actually enforce). Setting only one leaves an admin who sees
  /// admin screens but is denied every write, or vice versa.
  ///
  /// Requires the member to already be linked to a login — the marker doc
  /// is keyed by Firebase Auth uid, which an unclaimed record doesn't have.
  Future<void> setMemberAdmin({
    required String memberId,
    required String? authUid,
    required bool makeAdmin,
  }) async {
    if (authUid == null || authUid.isEmpty) {
      throw StateError(
        'This member is not connected to a login yet, so they cannot be made an admin.',
      );
    }

    await _db.collection(FirestorePaths.members).doc(memberId).update({
      'role': makeAdmin ? 'admin' : 'member',
    });

    final marker = _db.collection('admins').doc(authUid);
    if (makeAdmin) {
      await marker.set({'grantedAt': FieldValue.serverTimestamp()});
    } else {
      await marker.delete();
    }
  }

  /// Whether this account has the `admins/{uid}` marker doc that
  /// firestore.rules actually checks. A member doc's `role: "admin"` only
  /// controls what the app *shows*; without this doc every admin write is
  /// rejected server-side, which otherwise surfaces as an unexplained
  /// permission-denied on each separate feature.
  Future<bool> hasAdminMarker(String authUid) async {
    try {
      final doc = await _db.collection('admins').doc(authUid).get();
      return doc.exists;
    } catch (_) {
      // Older deployed rules denied this read outright — treat that as
      // "can't tell" rather than "missing", so the warning banner never
      // fires spuriously against a correctly-configured admin.
      return true;
    }
  }

  // ---------------- LINK REQUESTS ----------------

  /// `requestedEmail` matters more than it looks: the app signs users in
  /// with email/password, so `User.phoneNumber` (the source of
  /// `requestedPhone`) is always null and that field arrives empty. Without
  /// the email, the admin's approval card would show which *member* is
  /// being claimed but nothing at all about which *account* is claiming it.
  Future<void> createLinkRequest({
    required String memberId,
    required String requestedByUid,
    required String requestedPhone,
    String requestedEmail = '',
  }) {
    return _db.collection(FirestorePaths.linkRequests).add({
      'memberId': memberId,
      'requestedByUid': requestedByUid,
      'requestedPhone': requestedPhone,
      'requestedEmail': requestedEmail,
      'status': 'pending',
      'requestedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchPendingLinkRequests() {
    return _db
        .collection(FirestorePaths.linkRequests)
        .where('status', isEqualTo: 'pending')
        .snapshots();
  }

  /// So the homepage "connect your Member ID" banner can show a "pending
  /// admin approval" state instead of the connect prompt once the member
  /// has already submitted a request.
  Stream<QuerySnapshot<Map<String, dynamic>>> watchMyPendingLinkRequest(String authUid) {
    return _db
        .collection(FirestorePaths.linkRequests)
        .where('requestedByUid', isEqualTo: authUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .snapshots();
  }

  /// Admin approves a link request: attaches the requester's auth uid to
  /// the target member doc (mirrors the auto-claim in `claimMember`) and
  /// marks the request approved.
  ///
  /// A member can only ever be linked to one auth account at a time
  /// (`watchMemberByAuthUid` assumes exactly one match). If this user is
  /// already linked to a *different* member doc — e.g. an empty
  /// self-registered record created before they had a real Member ID to
  /// enter — that old doc is unlinked first so the two don't end up
  /// pointing at the same account simultaneously.
  Future<void> approveLinkRequest({
    required String requestId,
    required String memberId,
    required String requestedByUid,
    required String reviewedBy,
  }) async {
    final existing = await _db
        .collection(FirestorePaths.members)
        .where('authUid', isEqualTo: requestedByUid)
        .get();

    final batch = _db.batch();
    for (final doc in existing.docs) {
      if (doc.id != memberId) {
        batch.update(doc.reference, {'authUid': null, 'isClaimed': false});
      }
    }
    batch.update(_db.collection(FirestorePaths.members).doc(memberId), {
      'authUid': requestedByUid,
      'isClaimed': true,
    });
    batch.update(_db.collection(FirestorePaths.linkRequests).doc(requestId), {
      'status': 'approved',
      'reviewedBy': reviewedBy,
    });
    await batch.commit();
  }

  Future<void> rejectLinkRequest({
    required String requestId,
    required String reviewedBy,
  }) {
    return _db.collection(FirestorePaths.linkRequests).doc(requestId).update({
      'status': 'rejected',
      'reviewedBy': reviewedBy,
    });
  }

  // ----------- NOTICES ---------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllNotices() {
    return _db
        .collection(FirestorePaths.notices)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> createNotice({
    required String title,
    required String body,
    required String postedBy,
    DateTime? eventDate,
    String location = '',
    bool isMeeting = false,
    int reminderMinutes = 30,
  }) {
    return _db.collection(FirestorePaths.notices).add({
      'title': title,
      'body': body,
      'postedBy': postedBy,
      'createdAt': FieldValue.serverTimestamp(),
      'eventDate': eventDate != null ? Timestamp.fromDate(eventDate) : null,
      'location': location,
      'isMeeting': isMeeting,
      'reminderMinutes': reminderMinutes,
    });
  }

  Future<void> updateNotice(String noticeId, Map<String, dynamic> updates) {
    return _db.collection(FirestorePaths.notices).doc(noticeId).update(updates);
  }

  Future<void> deleteNotice(String noticeId) {
    return _db.collection(FirestorePaths.notices).doc(noticeId).delete();
  }

  /// Admin-only: clear the whole notice board. Batched at 400 (the
  /// write-batch limit is 500) since Firestore can't delete a collection
  /// in one call.
  Future<int> deleteAllNotices() async {
    var deleted = 0;
    while (true) {
      final snapshot =
          await _db.collection(FirestorePaths.notices).limit(400).get();
      if (snapshot.docs.isEmpty) break;

      final batch = _db.batch();
      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      deleted += snapshot.docs.length;
    }
    return deleted;
  }

  // ----------- WELFARE REQUESTS ---------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchWelfareRequests() {
    return _db
        .collection(FirestorePaths.welfareRequests)
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchUserWelfareRequests(
    String memberId,
  ) {
    return _db
        .collection(FirestorePaths.welfareRequests)
        .where('memberId', isEqualTo: memberId)
        .orderBy('submittedAt', descending: true)
        .snapshots();
  }

  Future<void> createWelfareRequest({
    required String memberId,
    required String reason,
    required double amountRequested,
  }) {
    return _db.collection(FirestorePaths.welfareRequests).add({
      'memberId': memberId,
      'reason': reason,
      'amountRequested': amountRequested,
      'status': 'pending',
      'submittedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateWelfareRequest({
    required String requestId,
    required String status,
    String? reviewedBy,
  }) {
    return _db.collection(FirestorePaths.welfareRequests).doc(requestId).update(
      {'status': status, 'reviewedBy': reviewedBy},
    );
  }

  // ----------- POLLS ---------

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAllPolls() {
    return _db
        .collection(FirestorePaths.polls)
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> createPoll({
    required String question,
    required List<String> options,
    required String createdByUid,
    required String createdByName,
    DateTime? closesAt,
  }) {
    final votes = {for (int i = 0; i < options.length; i++) i.toString(): 0};
    return _db.collection(FirestorePaths.polls).add({
      'question': question,
      'options': options,
      'votes': votes,
      'voterIds': [],
      'isActive': true,
      'createdByUid': createdByUid,
      'createdByName': createdByName,
      'createdAt': FieldValue.serverTimestamp(),
      'closesAt': closesAt != null ? Timestamp.fromDate(closesAt) : null,
    });
  }

  Future<void> votePoll({
    required String pollId,
    required int optionIndex,
    required String voterId,
  }) async {
    final pollDoc = await _db
        .collection(FirestorePaths.polls)
        .doc(pollId)
        .get();
    if (!pollDoc.exists) return;

    final data = pollDoc.data() ?? {};
    final votes = Map<String, int>.from(data['votes'] ?? {});
    final voterIds = List<String>.from(data['voterIds'] ?? []);

    if (voterIds.contains(voterId)) return; // Already voted

    final optionKey = optionIndex.toString();
    votes[optionKey] = (votes[optionKey] ?? 0) + 1;
    voterIds.add(voterId);

    await _db.collection(FirestorePaths.polls).doc(pollId).update({
      'votes': votes,
      'voterIds': voterIds,
    });
  }

  // ---------------- GENERIC HELPERS ----------------

  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _db.collection(path);

  Future<void> updateDoc(
    String collectionPath,
    String docId,
    Map<String, dynamic> data,
  ) {
    return _db.collection(collectionPath).doc(docId).update(data);
  }

  Future<DocumentReference<Map<String, dynamic>>> addDoc(
    String collectionPath,
    Map<String, dynamic> data,
  ) {
    return _db.collection(collectionPath).add(data);
  }
}
