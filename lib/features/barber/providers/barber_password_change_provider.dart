import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/auth/services/auth_service.dart';
import 'package:cutline/shared/services/auth_session_storage.dart';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';

class BarberPasswordChangeProvider extends ChangeNotifier {
  BarberPasswordChangeProvider({
    required AuthProvider authProvider,
    AuthService? authService,
    FirebaseFirestore? firestore,
    AuthSessionStorage? sessionStorage,
  })  : _authProvider = authProvider,
        _authService = authService ?? AuthService(),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _sessionStorage = sessionStorage ?? AuthSessionStorage();

  final AuthProvider _authProvider;
  final AuthService _authService;
  final FirebaseFirestore _firestore;
  final AuthSessionStorage _sessionStorage;

  bool _isSaving = false;
  String? _error;

  bool get isSaving => _isSaving;
  String? get error => _error;

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _authProvider.currentUser;
    final email = user?.email?.trim() ?? '';
    if (user == null || email.isEmpty) {
      _setError('Please sign in again.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      final profile = await _authProvider.fetchUserProfile(user.uid);
      final ownerId = ((profile?['ownerId'] as String?) ?? '').trim();

      await _authService.reauthenticateWithPassword(
        email: email,
        password: currentPassword,
      );
      await _authService.updateCurrentPassword(newPassword);

      final batch = _firestore.batch();
      batch.set(
        _firestore.collection('users').doc(user.uid),
        {
          'mustChangePassword': false,
          'passwordChangedAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );

      if (ownerId.isNotEmpty) {
        batch.set(
          _firestore
              .collection('salons')
              .doc(ownerId)
              .collection('barber_credentials')
              .doc(user.uid),
          {
            'uid': user.uid,
            'ownerId': ownerId,
            'email': email,
            'temporaryPassword': '',
            'passwordVisibleToOwner': false,
            'mustChangePassword': false,
            'passwordChangedAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }

      await batch.commit();

      final remembered = await _sessionStorage.getRememberedCredentials();
      if (remembered != null &&
          remembered.email.trim().toLowerCase() == email.toLowerCase()) {
        await _sessionStorage.setRememberedCredentials(
          email: email,
          password: newPassword,
        );
      }

      await _authProvider.refreshCurrentUser();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapAuthError(e));
      return false;
    } catch (_) {
      _setError('Could not change password. Please try again.');
      return false;
    } finally {
      _setSaving(false);
    }
  }

  String _mapAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Current password is incorrect.';
      case 'weak-password':
        return 'New password is too weak.';
      case 'requires-recent-login':
        return 'Please sign in again, then change the password.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      default:
        return e.message ?? 'Could not change password.';
    }
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
}
