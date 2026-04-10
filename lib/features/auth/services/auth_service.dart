import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> reloadCurrentUser({bool forceRefreshIdToken = false}) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
    // Optionally force-refresh the ID token so server-side account
    // deletion/disablement is detected quickly (otherwise cached tokens may
    // remain valid for a while).
    await user.getIdToken(forceRefreshIdToken);
    await user.reload();
    return _firebaseAuth.currentUser;
  }

  Future<UserCredential> signUp({
    required String email,
    required String password,
    String? displayName,
    String? phoneNumber,
  }) async {
    final credential = await _firebaseAuth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final trimmedName = displayName?.trim();
    final user = credential.user;
    if (user != null && trimmedName != null && trimmedName.isNotEmpty) {
      await user.updateDisplayName(trimmedName);
    }

    return credential;
  }

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _firebaseAuth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<void> sendPasswordReset(String email) {
    return _firebaseAuth.sendPasswordResetEmail(email: email);
  }

  Future<void> reauthenticateWithPassword({
    required String email,
    required String password,
  }) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in user found.',
      );
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );
    await user.reauthenticateWithCredential(credential);
  }

  Future<void> updateCurrentPassword(String newPassword) async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'user-not-found',
        message: 'No signed-in user found.',
      );
    }
    await user.updatePassword(newPassword);
  }

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}
