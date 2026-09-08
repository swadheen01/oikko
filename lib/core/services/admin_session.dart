import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Whether the signed-in account is an admin, held for the session so
/// screens can gate UI without each one doing its own read.
///
/// This is a *display* gate only — the real enforcement is in
/// firestore.rules, which rejects the same writes server-side. Never rely
/// on this alone to protect anything.
///
/// Admin status is driven by a **live** subscription to the caller's own
/// `admins/{uid}` marker doc ([watch]), not a one-shot read. That means when
/// an admin is demoted (their marker deleted) their app drops out of the
/// admin panel within seconds — no log out / log back in required.
///
/// Every admin has equal, full power — there is no separate protected
/// "super admin" tier. Any admin can promote or demote any other admin
/// (including whoever promoted them), and every irreversible action
/// (clearing all finance records, all notices) is available to every admin.
class AdminSession {
  AdminSession._();

  /// The association's original owner account (no `members` record by
  /// design, so it must never be counted or listed as a member). Any stray
  /// member doc carrying this email (e.g. created by a first Google
  /// sign-in) is filtered out of the directory and the member counts. This
  /// is just an identity check, unrelated to admin permissions — that
  /// account has no special power beyond any other admin.
  static const String superAdminEmail = 'contactwith.swadheen@gmail.com';

  /// True if [email] is the owner account's, ignoring case and surrounding
  /// whitespace — use this to keep that account out of member listings.
  static bool isSuperAdminEmail(String email) =>
      email.trim().toLowerCase() == superAdminEmail;

  static final ValueNotifier<bool> isAdmin = ValueNotifier(false);

  static String? _uid;
  static Stream<DocumentSnapshot<Map<String, dynamic>>>? _markerStream;

  /// Live stream of the caller's own `admins/{uid}` marker doc, cached per
  /// uid so repeated widget rebuilds reuse a single subscription (a fresh
  /// stream each build would make the router flicker). The security rules
  /// allow a caller to read exactly their own marker, so this is permitted.
  static Stream<DocumentSnapshot<Map<String, dynamic>>> watch(String uid) {
    if (_uid != uid || _markerStream == null) {
      _uid = uid;
      _markerStream = FirebaseFirestore.instance
          .collection('admins')
          .doc(uid)
          .snapshots();
    }
    return _markerStream!;
  }

  /// Push the latest marker state into the notifier other screens read.
  /// Only writes on an actual change, so it's safe to call from a post-frame
  /// callback without spamming listeners.
  static void set({required bool admin}) {
    if (isAdmin.value != admin) isAdmin.value = admin;
  }

  static void clear() {
    _uid = null;
    _markerStream = null;
    isAdmin.value = false;
  }
}
