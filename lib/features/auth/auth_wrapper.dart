import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/admin_session.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/meeting_reminder_service.dart';
import '../../core/services/notification_service.dart';
import '../../models/member.dart';
import '../admin/admin_shell.dart';
import '../home/home_shell.dart';
import '../profile/screens/edit_profile_screen.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'screens/email_verification_screen.dart';

/// Root-level widget: not logged in -> LoginScreen; logged in but email
/// not verified -> EmailVerificationScreen; verified -> fetch the linked
/// `members` document (by authUid) and show HomeShell.
class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key, this.firebaseAvailable = true});

  final bool firebaseAvailable;

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  final _notificationService = NotificationService();
  bool _justVerified = false;
  String? _tokenRegisteredForMemberId;
  // Tracked alongside the member id so a live admin demotion (marker
  // deleted while the app stays open) re-runs push registration too — not
  // just a change of member — and unsubscribes the device from the
  // `admins` FCM topic right away instead of on the next app open.
  bool? _tokenRegisteredIsAdmin;

  // Streams cached, not created in build(). A fresh stream on every rebuild
  // snaps its StreamBuilder back to the "waiting" state, which here renders
  // SplashScreen for a frame — that destroys and rebuilds the whole shell,
  // throwing the user back to the Home tab and re-loading everything. That's
  // exactly what happens on a real device when the member doc changes (e.g.
  // right after login, when the FCM token is written to it).
  late final Stream<User?> _authStream = _authService.authStateChanges;
  Stream<QuerySnapshot<Map<String, dynamic>>>? _memberStream;
  String? _memberStreamUid;

  Stream<QuerySnapshot<Map<String, dynamic>>> _memberDocs(String uid) {
    if (_memberStreamUid != uid || _memberStream == null) {
      _memberStreamUid = uid;
      _memberStream = _firestoreService.watchMemberByAuthUid(uid);
    }
    return _memberStream!;
  }

  /// Registers this device's FCM token against the member doc and
  /// subscribes it to that member's personal topic and (if admin) the
  /// `admins` topic. Re-runs when the member changes OR when their admin
  /// status changes — not just once per member — so a live promotion or
  /// demotion updates the topic subscription in this same session instead
  /// of waiting for the next app open.
  Future<void> _registerPushToken(Member member, {required bool isAdmin}) async {
    if (_tokenRegisteredForMemberId == member.id &&
        _tokenRegisteredIsAdmin == isAdmin) {
      return;
    }
    _tokenRegisteredForMemberId = member.id;
    _tokenRegisteredIsAdmin = isAdmin;

    // An unlinked account has no member document to write a token onto and
    // no personal topic to subscribe to. It still gets broadcast notices
    // via the `all_members` topic below.
    final isLinked = member.id.isNotEmpty;
    // Device-side meeting reminders, kept in step with the notices list for
    // as long as the app is running.
    unawaited(MeetingReminderService.instance.start());

    final token = await _notificationService.init(
      memberId: isLinked ? member.id : null,
      isAdmin: isAdmin,
    );
    if (token != null && isLinked) {
      await _firestoreService.updateDoc(
        FirestorePaths.members,
        member.id,
        {'fcmToken': token},
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.firebaseAvailable) {
      return const Scaffold(
        body: Center(
          child: Text('Unable to connect to Firebase. Please restart the app.'),
        ),
      );
    }

    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          _justVerified = false;
          _tokenRegisteredForMemberId = null;
          _tokenRegisteredIsAdmin = null;
          _memberStream = null;
          _memberStreamUid = null;
          AdminSession.clear();
          // Not const: a const instance is canonicalised, so it wouldn't
          // rebuild when the app re-renders on a language change and the
          // login page would stay in the old language.
          // ignore: prefer_const_constructors
          return LoginScreen();
        }

        if (!user.emailVerified && !_justVerified) {
          return EmailVerificationScreen(
            onVerified: () => setState(() => _justVerified = true),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _memberDocs(user.uid),
          builder: (context, memberSnapshot) {
            // A lighter loader than the launch splash for the brief post-login
            // wait. Only on the very first load — once we have data, keep the
            // shell mounted through any transient "waiting" so it's never torn
            // down (which would reset the tab and scroll).
            if (memberSnapshot.connectionState == ConnectionState.waiting &&
                !memberSnapshot.hasData) {
              return const AuthLoadingView();
            }
            final docs = memberSnapshot.data?.docs ?? [];

            // Admin status comes from the `admins/{uid}` marker, not from a
            // member record's `role`. That matters for a super admin, who
            // deliberately has no member document at all so they stay out
            // of the directory — reading `role` there would find nothing
            // and drop them into the ordinary member shell.
            //
            // Watched live (not read once) so demoting an admin — deleting
            // their marker — drops their app out of the admin panel within
            // seconds, without them having to log out and back in.
            return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: AdminSession.watch(user.uid),
              builder: (context, adminSnapshot) {
                if (adminSnapshot.connectionState == ConnectionState.waiting &&
                    !adminSnapshot.hasData) {
                  return const AuthLoadingView();
                }
                final isMarkerAdmin = adminSnapshot.data?.exists ?? false;
                final isSuper = isMarkerAdmin &&
                    adminSnapshot.data?.data()?['superAdmin'] == true;
                // Keep the global notifiers other screens read in sync, but
                // after this frame — setting them mid-build would try to mark
                // already-built listeners dirty during build.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  AdminSession.set(admin: isMarkerAdmin, superAdmin: isSuper);
                });

                // Not linked to a member record. Rather than locking the
                // app behind the linking screen, run the normal shell with
                // a placeholder profile: the directory, notices and polls
                // are association-wide and there's no reason to withhold
                // them. Only payment data is withheld, because there
                // genuinely isn't any until an admin approves the link.
                if (docs.isEmpty) {
                  final placeholder = Member(
                    id: '',
                    name: user.displayName?.trim().isNotEmpty == true
                        ? user.displayName!.trim()
                        : (user.email ?? ''),
                    email: user.email ?? '',
                    phone: user.phoneNumber ?? '',
                    authUid: user.uid,
                    status: 'approved',
                    role: isMarkerAdmin ? 'admin' : 'member',
                  );
                  _registerPushToken(placeholder, isAdmin: isMarkerAdmin);
                  return isMarkerAdmin
                      ? AdminShell(member: placeholder)
                      : HomeShell(member: placeholder, isLinked: false);
                }

                final member = Member.fromDoc(docs.first);

                // First Google sign-in: the record exists but is bare, so
                // send them to complete their profile (school, phone, etc.)
                // before entering the app. Cleared on their first save.
                if (member.needsProfileSetup) {
                  return EditProfileScreen(member: member, isInitialSetup: true);
                }

                final effectiveAdmin = member.isAdmin || isMarkerAdmin;
                _registerPushToken(member, isAdmin: effectiveAdmin);
                if (effectiveAdmin) {
                  return AdminShell(member: member);
                }
                return HomeShell(member: member);
              },
            );
          },
        );
      },
    );
  }
}
