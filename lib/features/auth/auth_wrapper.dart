import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/constants/firestore_paths.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/meeting_reminder_service.dart';
import '../../core/services/notification_service.dart';
import '../../models/member.dart';
import '../admin/admin_shell.dart';
import '../home/home_shell.dart';
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

  /// Registers this device's FCM token against the member doc and
  /// subscribes it to that member's personal topic, once per member (not
  /// on every rebuild).
  Future<void> _registerPushToken(Member member) async {
    if (_tokenRegisteredForMemberId == member.id) return;
    _tokenRegisteredForMemberId = member.id;

    // An unlinked account has no member document to write a token onto and
    // no personal topic to subscribe to. It still gets broadcast notices
    // via the `all_members` topic below.
    final isLinked = member.id.isNotEmpty;
    // Device-side meeting reminders, kept in step with the notices list for
    // as long as the app is running.
    unawaited(MeetingReminderService.instance.start());

    final token = await _notificationService.init(
      memberId: isLinked ? member.id : null,
      isAdmin: member.isAdmin,
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
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        final user = snapshot.data;
        if (user == null) {
          _justVerified = false;
          return const LoginScreen();
        }

        if (!user.emailVerified && !_justVerified) {
          return EmailVerificationScreen(
            onVerified: () => setState(() => _justVerified = true),
          );
        }

        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _firestoreService.watchMemberByAuthUid(user.uid),
          builder: (context, memberSnapshot) {
            if (memberSnapshot.connectionState == ConnectionState.waiting) {
              return const SplashScreen();
            }
            final docs = memberSnapshot.data?.docs ?? [];

            // Not linked to a member record yet. Rather than locking the
            // app behind the linking screen, run the normal member shell
            // with a placeholder profile: the directory, notices and polls
            // are association-wide and there's no reason to withhold them.
            // Only payment data is withheld, because there genuinely isn't
            // any until an admin approves the link.
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
              );
              _registerPushToken(placeholder);
              return HomeShell(member: placeholder, isLinked: false);
            }

            final member = Member.fromDoc(docs.first);
            _registerPushToken(member);
            if (member.isAdmin) {
              return AdminShell(member: member);
            }
            return HomeShell(member: member);
          },
        );
      },
    );
  }
}
