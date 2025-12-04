import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/barber/providers/barber_profile_provider.dart';
import 'package:flutter/material.dart';

class BarberEditProfileProvider extends ChangeNotifier {
  BarberEditProfileProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  BarberProfile? _profile;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;
  BarberProfile? get profile => _profile;

  Future<void> load() async {
    final uid = _authProvider.currentUser?.uid;
    if (uid == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      if (!snap.exists) {
        _setError('Profile not found.');
        return;
      }
      final data = snap.data() ?? {};
      _profile = BarberProfile(
        uid: uid,
        ownerId: (data['ownerId'] as String?) ?? '',
        name: (data['name'] as String?) ?? '',
        specialization: (data['specialization'] as String?) ?? '',
        phone: (data['phone'] as String?) ?? '',
        email: (data['email'] as String?) ?? '',
      );
    } catch (_) {
      _setError('Failed to load profile.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> save({
    required String name,
    required String specialization,
    required String phone,
  }) async {
    final uid = _authProvider.currentUser?.uid;
    if (uid == null) {
      _setError('Please log in again.');
      return false;
    }
    _setSaving(true);
    _setError(null);
    try {
      await _firestore.collection('users').doc(uid).set({
        'name': name.trim(),
        'specialization': specialization.trim(),
        'phone': phone.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (_profile != null) {
        _profile = BarberProfile(
          uid: uid,
          ownerId: _profile!.ownerId,
          name: name,
          specialization: specialization,
          phone: phone,
          email: _profile!.email,
        );
      }
      _setSaving(false);
      return true;
    } catch (_) {
      _setError('Could not save profile. Try again.');
      _setSaving(false);
      return false;
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }
}
