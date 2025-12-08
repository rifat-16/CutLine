import 'dart:async';
import 'dart:io';

import 'package:cutline/features/auth/models/user_model.dart';
import 'package:cutline/features/auth/models/user_role.dart';
import 'package:cutline/features/auth/services/auth_service.dart';
import 'package:cutline/features/auth/services/user_profile_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
      _currentUser = user;
      _loadProfile();
      notifyListeners();
    });
  }

  final AuthService _authService;
  final UserProfileService _userProfileService;
  StreamSubscription<User?>? _authSubscription;
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

  Future<bool> signIn({
    required String email,
    required String password,
  }) async {
    return _runAuthFlow(() async {
      await _authService.signIn(email: email.trim(), password: password);
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
        await _userProfileService.createUserProfile(
          uid: uid,
          email: email,
          name: name,
          phone: phone,
          role: role,
        );
      }
    });
  }

  Future<bool> sendPasswordReset(String email) async {
    return _runAuthFlow(() async {
      await _authService.sendPasswordReset(email.trim());
    });
  }

  Future<void> signOut() {
    _profile = null;
    return _authService.signOut();
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
    await _userProfileService.setProfileComplete(uid, value);
    await _loadProfile();
  }

  Future<void> refreshCurrentUser() async {
    try {
      final user = await _authService.reloadCurrentUser();
      _currentUser = user;
      await _loadProfile();
      notifyListeners();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found' || e.code == 'user-disabled') {
        await _authService.signOut();
        _currentUser = null;
        notifyListeners();
        return;
      }
      _setError(_mapFirebaseError(e));
    }
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
      return;
    }
    final data = await fetchUserProfile(uid);
    if (data != null) {
      _profile = CutlineUser.fromMap(data);
    } else {
      _profile = null;
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
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No user found for that email.';
      case 'wrong-password':
        return 'Incorrect password. Try again.';
      case 'email-already-in-use':
        return 'An account already exists for that email.';
      case 'weak-password':
        return 'Choose a stronger password.';
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

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}
