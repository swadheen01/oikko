import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Whether the signed-in account is an admin / super admin, held for the
/// session so screens can gate UI without each one doing its own read.
///
/// This is a *display* gate only — the real enforcement is in
/// firestore.rules, which rejects the same writes server-side. Never rely
/// on this alone to protect anything.
///
/// Admin status is now driven by a **live** subscription to the caller's own
/// `admins/{uid}` marker doc ([watch]), not a one-shot read. That means when
/// an admin is demoted (their marker deleted) their app drops out of the
/// admin panel within seconds — no log out / log back in required.
///
/// A super admin is an `admins/{uid}` doc with `superAdmin: true`. That
/// account usually has no `members` record at all, so it doesn't appear in
/// the directory, and no other admin can discover it: the `admins`
/// collection isn't listable and each caller may read only their own doc.
class AdminSession {
  AdminSession._();

  static final ValueNotifier<bool> isAdmin = ValueNotifier(false);
  static final ValueNotifier<bool> isSuperAdmin = ValueNotifier(false);

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

  /// Push the latest marker state into the notifiers other screens read.
  /// Only writes on an actual change, so it's safe to call from a post-frame
  /// callback without spamming listeners.
  static void set({required bool admin, required bool superAdmin}) {
    if (isAdmin.value != admin) isAdmin.value = admin;
    if (isSuperAdmin.value != superAdmin) isSuperAdmin.value = superAdmin;
  }

  static void clear() {
    _uid = null;
    _markerStream = null;
    isAdmin.value = false;
    isSuperAdmin.value = false;
  }
}
