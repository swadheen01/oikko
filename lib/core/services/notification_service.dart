import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles FCM push notifications (planning doc section 4.6).
///
/// Receiving is free/client-only (FCM itself needs no billing plan), but
/// *sending* needs something running server-side to call FCM's API when
/// e.g. a notice is posted — that piece is the `send-notification`
/// Supabase Edge Function (see supabase/functions/send-notification),
/// since Firebase's own Cloud Functions now require the paid Blaze plan
/// just like Storage did.
///
/// Every device subscribes to two FCM topics on init:
/// - `all_members` — broadcasts (new notice, new poll)
/// - `member_{memberId}` — sent only to that one member's device(s)
///   (welfare request approved/rejected, account-link approved)
///
/// Topic-based rather than per-token: sending only ever needs one call
/// (to a topic) instead of looking up and looping over device tokens.
class NotificationService {
  static const String allMembersTopic = 'all_members';

  /// Every admin device subscribes here — used for "a new link request
  /// needs review" pushes, since those don't target a single member.
  static const String adminsTopic = 'admins';

  static String memberTopic(String memberId) => 'member_$memberId';

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  /// Call once after login: requests permission, subscribes this device to
  /// `all_members`, its personal topic (if `memberId` is known), and
  /// `admins` (if `isAdmin`), and returns the device's FCM token (for
  /// callers that also want to store it, e.g. for a future per-device
  /// send).
  Future<String?> init({String? memberId, bool isAdmin = false}) async {
    // Web requires an extra VAPID key param; handled separately when
    // we wire up Phase 3 (push notifications). Skipped here for MVP.
    if (kIsWeb) return null;

    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.denied) {
      return null;
    }

    await _messaging.subscribeToTopic(allMembersTopic);
    if (memberId != null) {
      await _messaging.subscribeToTopic(memberTopic(memberId));
    }
    if (isAdmin) {
      await _messaging.subscribeToTopic(adminsTopic);
    }
    return _messaging.getToken();
  }

  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  /// Admin-only: pushes `title`/`body` to everyone (new notice, new poll).
  Future<void> sendToAllMembers({required String title, required String body}) {
    return _send(title: title, body: body, topic: allMembersTopic);
  }

  /// Admin-only: pushes `title`/`body` to one member only (welfare request
  /// decision, account-link approved).
  Future<void> sendToMember({
    required String memberId,
    required String title,
    required String body,
  }) {
    return _send(title: title, body: body, topic: memberTopic(memberId));
  }

  /// Any signed-in member may call this one (not admin-only) — it's how a
  /// member notifies admins that a new link request needs review, since
  /// they aren't an admin themselves yet. The Edge Function special-cases
  /// the `admins` topic to skip its admin check (still requires a valid
  /// signed-in caller); every other topic stays admin-only, enforced
  /// server-side.
  Future<void> sendToAdmins({required String title, required String body}) {
    return _send(title: title, body: body, topic: adminsTopic);
  }

  /// Calls the send-notification Edge Function. It independently re-checks
  /// that the caller is really an admin (via the same `admins/{uid}` doc
  /// firestore.rules trusts) before sending anything — this call being
  /// reachable from the client isn't itself the security boundary.
  Future<void> _send({required String title, required String body, required String topic}) async {
    final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
    if (idToken == null) {
      throw StateError('Must be signed in to send a push notification.');
    }

    final response = await Supabase.instance.client.functions.invoke(
      'send-notification',
      body: {
        'title': title,
        'body': body,
        'topic': topic,
        'idToken': idToken,
      },
    );

    if (response.status != 200) {
      throw Exception('Push send failed (${response.status}): ${response.data}');
    }
  }
}
