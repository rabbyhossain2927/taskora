import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../config.dart';

class AuthService {
  static final _auth = FirebaseAuth.instance;

  /// Shared with the Drive backup, which asks for an extra scope later.
  static final google = GoogleSignIn(serverClientId: Config.googleWebClientId, scopes: const ['email']);

  static User? get user => _auth.currentUser;

  static Future<void> signInWithGoogle() async {
    final acc = await google.signIn();
    if (acc == null) throw 'Sign-in cancelled';
    final a = await acc.authentication;
    await _auth.signInWithCredential(GoogleAuthProvider.credential(idToken: a.idToken, accessToken: a.accessToken));
  }

  static Future<void> signInWithEmail(String email, String pass) =>
      _auth.signInWithEmailAndPassword(email: email.trim(), password: pass);

  static Future<void> signUp(String name, String email, String pass) async {
    final c = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: pass);
    await c.user?.updateDisplayName(name.trim());
  }

  static Future<void> resetPassword(String email) => _auth.sendPasswordResetEmail(email: email.trim());

  static Future<void> updateName(String name) async {
    await _auth.currentUser?.updateDisplayName(name.trim());
    await _auth.currentUser?.reload();
  }

  static Future<void> signOut() async {
    try {
      await google.signOut();
    } catch (_) {}
    await _auth.signOut();
  }

  /// Turns Firebase error codes into short, friendly sentences.
  static String friendly(Object e) {
    if (e is FirebaseAuthException) {
      return switch (e.code) {
        'invalid-email' => 'That email doesn’t look right.',
        'user-not-found' || 'wrong-password' || 'invalid-credential' => 'Email or password is wrong.',
        'email-already-in-use' => 'An account with this email already exists.',
        'weak-password' => 'Use at least 6 characters for the password.',
        'network-request-failed' => 'No internet. Try again when you’re online.',
        _ => e.message ?? 'Something went wrong.',
      };
    }
    return e.toString();
  }
}
