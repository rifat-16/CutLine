import 'dart:async';
import 'dart:io';

import 'package:cutline/features/auth/models/user_model.dart';
import 'package:cutline/features/auth/models/user_role.dart';
import 'package:cutline/features/auth/services/auth_service.dart';
import 'package:cutline/features/auth/services/user_profile_service.dart';
import 'package:cutline/shared/services/auth_session_storage.dart';
import 'package:cutline/shared/services/fcm_token_service.dart';
import 'package:cutline/shared/services/notification_service.dart';
import 'package:cutline/shared/services/session_debug.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({
    AuthService? authService,
    UserProfileService? userProfileService,
  })  : _authService = authService ?? AuthService(),
        _userProfileService = userProfileService ?? UserProfileService() {
    _currentUser = _authService.currentUser;
    _authSubscription = _authService.authStateChanges.listen((user) {
      if (!_authReady.isCompleted) _authReady.complete();
      _onAuthState(user);
    });
    // Apply the synchronous snapshot quickly, but treat the first stream event
    // as the "ready" signal for slow OEM devices.
    _onAuthState(_currentUser);
  }

  final AuthService _authService;
  final UserProfileService _userProfileService;
  final FcmTokenService _fcmTokenService = FcmTokenService();
  final AuthSessionStorage _sessionStorage = AuthSessionStorage();
  final Completer<void> _authReady = Completer<void>();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;
  String? _tokenRefreshUserId;
  int _authGeneration = 0;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  User? _currentUser;
  CutlineUser? _profile;
  bool _isLoading = false;
  String? _lastError;
  bool _uploadingPhoto = false;

  User? get currentUser => _currentUser;
  CutlineUser? get profile => _profile;
  bool get isAuthenticated => _currentUser != null;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;
  bool get isUploadingPhoto => _uploadingPhoto;

  Future<void> waitForAuthReady({Duration timeout = const Duration(seconds: 6)}) {
    if (_authReady.isCompleted) return Future<void>.value();
    return _authReady.future.timeout(timeout);
  }

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    return _runAuthFlow(() async {
      await _authService.signIn(email: email.trim(), password: password);
      // Make `currentUser` available synchronously after sign-in so callers can
      // route immediately without waiting for the authStateChanges event.
      _currentUser = _authService.currentUser;
      final uid = _currentUser?.uid;
      if (uid != null) {
        try {
          await _sessionStorage.setLastSignedInUid(uid);
        } catch (e, st) {
          SessionDebug.log('Failed to persist last signed-in uid (signIn)',
              error: e, stackTrace: st);
        }
      }
      if (_currentUser != null) {
        _onAuthState(_currentUser);
      }
    });
  }

  Future<bool> signUp({
    required String name,
    required String email,
    required String password,
    String phone = '',
    required UserRole role,
  }) async {
    return _runAuthFlow(() async {
      final credential = await _authService.signUp(
        email: email.trim(),
        password: password,
        displayName: name.trim(),
        phoneNumber: phone.trim().isEmpty ? null : phone.trim(),
      );

      final uid = credential.user?.uid;
      if (uid != null) {
        _currentUser = credential.user;
        try {
          await _sessionStorage.setLastSignedInUid(uid);
        } catch (e, st) {
          SessionDebug.log('Failed to persist last signed-in uid (signUp)',
              error: e, stackTrace: st);
        }
        await _userProfileService.createUserProfile(
          uid: uid,
          email: email,
          name: name,
          phone: phone,
          role: role,
        );
        // Ensure the freshly-created profile is reflected in app state.
        _onAuthState(_currentUser);
      }
    });
  }

  Future<bool> sendPasswordReset(String email) async {
    return _runAuthFlow(() async {
      await _authService.sendPasswordReset(email.trim());
    });
  }

  Future<void> signOut() {
    final uid = _currentUser?.uid;
    _profile = null;
    notificationService.setUserRole(null);
    unawaited(_stopTokenRefresh());
    if (uid != null) {
      unawaited(_removeCurrentDeviceTokenFromUser(uid));
    }
    unawaited(_sessionStorage.clearLastSignedInUid());
    unawaited(_sessionStorage.clearRememberedCredentials());
    // Clear local auth state immediately so routing/UI can't use a stale user
    // while FirebaseAuth completes sign-out.
    _currentUser = null;
    notifyListeners();
    return _authService.signOut();
  }

  Future<void> _removeCurrentDeviceTokenFromUser(String uid) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) return;
      await _fcmTokenService.removeToken(uid, token);
    } catch (e, st) {
      SessionDebug.log('Failed to remove FCM token on sign out',
          error: e, stackTrace: st);
    }
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    try {
      return await _userProfileService.fetchUserProfile(uid);
    } on FirebaseException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<void> setProfileComplete(bool value) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    try {
      await _userProfileService
          .setProfileComplete(uid, value)
          .timeout(const Duration(seconds: 8));
    } catch (_) {
      // Best effort; don't block routing if Firestore/auth is unavailable.
    }
    try {
      final generation = _authGeneration;
      await _loadProfileForUid(uid: uid, generation: generation);
      if (_authGeneration == generation) {
        notifyListeners();
      }
    } catch (_) {
      // Best effort.
    }
  }

  Future<void> refreshCurrentUser() async {
    try {
      final user = await _authService.reloadCurrentUser();
      _currentUser = user;
      await _loadProfile();
      notifyListeners();
    } on FirebaseAuthException catch (e, st) {
      SessionDebug.log(
        'refreshCurrentUser failed: ${e.code}',
        error: e.message,
        stackTrace: st,
      );
      final shouldForceSignOut = e.code == 'user-not-found' ||
          e.code == 'user-disabled' ||
          e.code == 'invalid-user-token' ||
          e.code == 'user-token-expired' ||
          _isStaleAuthSessionError(e);
      if (shouldForceSignOut) {
        _setError(_mapFirebaseError(e));
        await signOut();
        _currentUser = null;
        notifyListeners();
        return;
      }
      _setError(_mapFirebaseError(e));
    }
  }

  bool _isStaleAuthSessionError(FirebaseAuthException e) {
    // Some platform implementations surface account deletion/disablement as an
    // `unknown`/`internal-error` with a descriptive message. Treat those as a
    // hard sign-out so the app doesn't keep routing with a stale session.
    final msg = (e.message ?? '').toLowerCase();
    if (msg.isEmpty) return false;

    final looksDeleted = msg.contains('has been deleted') ||
        msg.contains('user has been deleted') ||
        msg.contains('no user record') ||
        msg.contains('user record') && msg.contains('not found') ||
        msg.contains('user not found') ||
        msg.contains('account has been deleted');

    final looksRevoked = msg.contains('invalid user token') ||
        msg.contains('user token') && msg.contains('expired') ||
        msg.contains('token is no longer valid') ||
        msg.contains('revoked');

    final looksAuthApiBlocked =
        msg.contains('securetoken.googleapis.com') && msg.contains('blocked') ||
            msg.contains('securetoken') && msg.contains('granttoken') ||
            msg.contains('identitytoolkit') && msg.contains('blocked');

    return looksDeleted || looksRevoked || looksAuthApiBlocked;
  }

  Future<void> updateProfile({
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
  }) async {
    final uid = _currentUser?.uid;
    if (uid == null) return;
    _setLoading(true);
    try {
      await _userProfileService.updateUserProfile(
        uid: uid,
        name: name,
        email: email,
        phone: phone,
        photoUrl: photoUrl,
      );
      // Update displayName locally for quick UI reflection.
      if (name != null && name.trim().isNotEmpty) {
        await _currentUser?.updateDisplayName(name.trim());
      }
      if (photoUrl != null && photoUrl.trim().isNotEmpty) {
        await _currentUser?.updatePhotoURL(photoUrl.trim());
      }
      await _loadProfile();
    } catch (e) {
      _setError('Failed to update profile. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> uploadProfilePhoto() async {
    final uid = _currentUser?.uid;
    if (uid == null) {
      _setError('Please sign in again.');
      return;
    }
    final previousUrl = _profile?.photoUrl ?? _currentUser?.photoURL;
    final picked = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (picked == null) return;
    _uploadingPhoto = true;
    notifyListeners();
    try {
      final url = await _uploadFile(
        uid: uid,
        file: picked,
        path: 'users/$uid/profile/profile_${DateTime.now().millisecondsSinceEpoch}.${_ext(picked.name)}',
      );
      await updateProfile(photoUrl: url);
      if (previousUrl != null && previousUrl != url) {
        await _deleteOldPhoto(previousUrl);
      }
    } catch (_) {
      _setError('Could not upload photo. Try again.');
    } finally {
      _uploadingPhoto = false;
      notifyListeners();
    }
  }

  Future<String> _uploadFile({
    required String uid,
    required XFile file,
    required String path,
  }) async {
    final ref = _storage.ref().child(path);
    final uploadTask = ref.putFile(File(file.path));
    final snap = await uploadTask.whenComplete(() {});
    return snap.ref.getDownloadURL();
  }

  String _ext(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'jpg';
    return name.substring(dot + 1);
  }

  Future<void> _deleteOldPhoto(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // Ignore cleanup failures.
    }
  }

  Future<void> _loadProfile() async {
    final uid = _currentUser?.uid;
    if (uid == null) {
      _profile = null;
      notificationService.setUserRole(null);
      return;
    }
    await _loadProfileForUid(uid: uid, generation: _authGeneration);
  }

  void _onAuthState(User? user) {
    final generation = ++_authGeneration;
    unawaited(_applyAuthState(user, generation));
  }

  Future<void> _applyAuthState(User? user, int generation) async {
    final previousUid = _currentUser?.uid;
    final newUid = user?.uid;

    // If the user changes, clear any user-scoped state immediately.
    if (previousUid != newUid) {
      _profile = null;
      notificationService.setUserRole(null);
      await _stopTokenRefresh();
    }

    _currentUser = user;
    if (_authGeneration != generation) return;
    notifyListeners();

    if (user == null) {
      return;
    }

    try {
      await _sessionStorage.setLastSignedInUid(user.uid);
    } catch (e, st) {
      SessionDebug.log('Failed to persist last signed-in uid',
          error: e, stackTrace: st);
    }

    await _loadProfileForUid(uid: user.uid, generation: generation);
    if (_authGeneration != generation) return;

    await _ensureFcmTokenWired(user.uid);
    if (_authGeneration != generation) return;

    notifyListeners();
  }

  Future<void> _loadProfileForUid({
    required String uid,
    required int generation,
  }) async {
    try {
      final data = await fetchUserProfile(uid);
      if (_authGeneration != generation) return;
      // If the auth user changed while we were fetching, ignore this result.
      if (_currentUser?.uid != uid) return;

      if (data != null) {
        _profile = CutlineUser.fromMap(data);
        notificationService.setUserRole(_profile?.role ?? UserRole.customer);
      } else {
        _profile = null;
        notificationService.setUserRole(null);
      }
    } catch (_) {
      if (_authGeneration != generation) return;
      if (_currentUser?.uid != uid) return;
      _profile = null;
      notificationService.setUserRole(null);
    }
  }

  Future<bool> _runAuthFlow(Future<void> Function() action) async {
    _setLoading(true);
    _setError(null);

    try {
      await action();
      return true;
    } on FirebaseAuthException catch (e) {
      _setError(_mapFirebaseError(e));
      return false;
    } on FirebaseException catch (e) {
      _setError(
          e.message ?? 'Unable to complete the request. Please try again.');
      return false;
    } catch (e) {
      _setError('Something went wrong. Please try again.');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'missing-email':
        return 'Please enter your email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'invalid-credential':
      case 'invalid-login-credentials':
        return 'Incorrect email or password. Try again.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Choose a stronger password.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this project.';
      case 'internal-error':
      case 'unknown':
        final msg = (e.message ?? '').toLowerCase();
        if (msg.contains('identitytoolkit') && msg.contains('blocked')) {
          return 'Firebase Auth API is blocked for this project. In Google Cloud Console, enable Identity Toolkit API and remove API key restrictions for it.';
        }
        if (msg.contains('securetoken') && msg.contains('blocked')) {
          return 'Firebase token API is blocked for this project. In Google Cloud Console, remove API key restrictions for securetoken.googleapis.com (Secure Token) and ensure Firebase Auth works.';
        }
        return 'Unable to complete the request. Please try again.';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        // TODO: Add phone/social sign-in when billing plan allows.
        return 'Unable to complete the request. Please try again.';
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _lastError = message;
    notifyListeners();
  }

  /// Save FCM token for the current user
  Future<void> _ensureFcmTokenWired(String userId) async {
    if (_tokenRefreshUserId == userId && _tokenRefreshSubscription != null) {
      return;
    }
    try {
      final token = await _fcmTokenService.initializeToken();
      if (token != null) {
        await _fcmTokenService.saveToken(userId, token);
        // Listen for token refresh
        await _stopTokenRefresh();
        _tokenRefreshUserId = userId;
        _tokenRefreshSubscription =
            _fcmTokenService.listenToTokenRefresh(userId, (_) {});
      }
    } catch (e) {
      // Don't throw - token saving is best effort
    }
  }

  Future<void> _stopTokenRefresh() async {
    final sub = _tokenRefreshSubscription;
    _tokenRefreshSubscription = null;
    _tokenRefreshUserId = null;
    await sub?.cancel();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    unawaited(_stopTokenRefresh());
    super.dispose();
  }
}
