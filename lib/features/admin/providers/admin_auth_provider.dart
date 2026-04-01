import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:cutline/features/auth/services/auth_service.dart';

class AdminAuthProvider extends ChangeNotifier {
  AdminAuthProvider({
    AuthService? authService,
  }) : _authService = authService ?? AuthService() {
    _currentUser = _authService.currentUser;
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) {
        _currentUser = user;
        unawaited(_refreshClaims());
      },
    );
    unawaited(_refreshClaims());
  }

  final AuthService _authService;
  StreamSubscription<User?>? _authSubscription;

  User? _currentUser;
  bool _isLoading = false;
  bool _isCheckingClaims = true;
  bool _isSuperadmin = false;
  String? _lastError;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isCheckingClaims => _isCheckingClaims;
  bool get isSuperadmin => _isSuperadmin;
  bool get isAuthenticated => _currentUser != null;
  String? get lastError => _lastError;

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final credential = await _authService.signIn(
        email: email.trim(),
        password: password,
      );
      _currentUser = credential.user;
      final allowed = await _refreshClaims(forceRefresh: true);
      if (!allowed) {
        _setError('This account is not allowed to access CutLine Admin.');
        return false;
      }
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
      return false;
    } catch (_) {
      _setError('Unable to sign in right now. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> signOut() async {
    _setError(null);
    _isSuperadmin = false;
    notifyListeners();
    await _authService.signOut();
  }

  Future<bool> _refreshClaims({bool forceRefresh = false}) async {
    final user = _currentUser;
    if (user == null) {
      _isCheckingClaims = false;
      _isSuperadmin = false;
      notifyListeners();
      return false;
    }

    _isCheckingClaims = true;
    notifyListeners();
    try {
      final token = await user.getIdTokenResult(forceRefresh);
      final allowed = token.claims?['superadmin'] == true;
      _isSuperadmin = allowed;
      if (!allowed) {
        await _authService.signOut();
        _currentUser = null;
      }
      return allowed;
    } catch (_) {
      _isSuperadmin = false;
      _setError('Could not verify admin access. Please sign in again.');
      return false;
    } finally {
      _isCheckingClaims = false;
      notifyListeners();
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return 'Unable to sign in right now.';
    }
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _lastError = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
