import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';

class EditSalonProvider extends ChangeNotifier {
  EditSalonProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  String salonName = '';
  String ownerName = '';
  String email = '';
  String phone = '';
  String address = '';
  String about = '';

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final doc = await _firestore.collection('salons').doc(ownerId).get();
      final data = doc.data() ?? {};
      salonName = (data['name'] as String?) ?? '';
      ownerName = (data['ownerName'] as String?) ?? '';
      email = (data['email'] as String?) ?? '';
      phone = (data['contact'] as String?) ?? '';
      address = (data['address'] as String?) ?? '';
      about = (data['description'] as String?) ?? '';
      final userDoc = await _firestore.collection('users').doc(ownerId).get();
      final userData = userDoc.data() ?? {};
      final userEmail =
          (_authProvider.currentUser?.email ?? userData['email'] as String?)
              ?.trim();
      final userName = (_authProvider.currentUser?.displayName ??
              userData['name'] as String?)
          ?.trim();

      ownerName = ownerName.isEmpty ? (userName ?? ownerName) : ownerName;
      // Always prefer user email for owner profile display
      if (userEmail != null && userEmail.isNotEmpty) {
        email = userEmail;
      }
    } catch (e) {
      _setError('Failed to load salon info.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> save({
    required String salonName,
    required String ownerName,
    required String email,
    required String phone,
    required String address,
    required String about,
  }) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return false;
    }
    _setSaving(true);
    _setError(null);
    try {
      await _firestore.collection('salons').doc(ownerId).set({
        'name': salonName,
        'ownerName': ownerName,
        'email': email,
        'contact': phone,
        'address': address,
        'description': about,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      this.salonName = salonName;
      this.ownerName = ownerName;
      this.email = email;
      this.phone = phone;
      this.address = address;
      this.about = about;
      return true;
    } catch (e) {
      _setError('Failed to save salon info.');
      return false;
    } finally {
      _setSaving(false);
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

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
}
