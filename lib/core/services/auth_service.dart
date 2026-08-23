import 'package:firebase_auth/firebase_auth.dart';

/// Email/Password auth (switched from Phone OTP to avoid Firebase Blaze
/// billing requirement). Login supports either email or phone as the
/// identifier — phone-based login is resolved to the matching email by
/// FirestoreService.findEmailByPhone() at the screen layer before this
/// service is called.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();
  bool get isLoggedIn => _auth.currentUser != null;
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
    await result.user?.sendEmailVerification();
    return result;
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email.trim(), password: password);
  }

  Future<void> resendVerificationEmail() async {
    await _auth.currentUser?.sendEmailVerification();
  }

  /// Refreshes the current user's data from Firebase (needed to pick up
  /// emailVerified changes after the user clicks the link in their inbox).
  Future<bool> reloadAndCheckVerified() async {
    await _auth.currentUser?.reload();
    return _auth.currentUser?.emailVerified ?? false;
  }

  Future<void> signOut() => _auth.signOut();

  String friendlyError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'এই ইমেইল দিয়ে আগে থেকেই একাউন্ট আছে';
      case 'invalid-email':
        return 'সঠিক ইমেইল দিন';
      case 'weak-password':
        return 'পাসওয়ার্ড কমপক্ষে ৬ ক্যারেক্টার হতে হবে';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'ইমেইল/ফোন অথবা পাসওয়ার্ড ভুল';
      case 'too-many-requests':
        return 'অনেকবার চেষ্টা হয়েছে, একটু পর আবার চেষ্টা করুন';
      default:
        return 'কিছু একটা সমস্যা হয়েছে, আবার চেষ্টা করুন';
    }
  }
}