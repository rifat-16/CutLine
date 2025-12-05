import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _firebaseAuth;

  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();
  User? get currentUser => _firebaseAuth.currentUser;

  Future<User?> reloadCurrentUser() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) return null;
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

  Future<void> signOut() {
    return _firebaseAuth.signOut();
  }
}
