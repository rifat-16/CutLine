import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class EditSalonProvider extends ChangeNotifier {
  EditSalonProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isSaving = false;
  bool _uploadingPhoto = false;
  String? _error;

  String salonName = '';
  String ownerName = '';
  String email = '';
  String phone = '';
  String address = '';
  String about = '';
  String? photoUrl;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isUploadingPhoto => _uploadingPhoto;
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
      photoUrl = (data['photoUrl'] as String?)?.trim();
      final userDoc = await _firestore.collection('users').doc(ownerId).get();
      final userData = userDoc.data() ?? {};
      final userEmail = (_authProvider.currentUser?.email ??
              userData['email'] as String?)
          ?.trim();
      final displayName =
          (_authProvider.currentUser?.displayName ?? '').trim();
      final profileName = (userData['name'] as String?)?.trim() ?? '';
      final pickedName = ownerName.isNotEmpty
          ? ownerName
          : (profileName.isNotEmpty
              ? profileName
              : (displayName.isNotEmpty && displayName != userEmail
                  ? displayName
                  : ''));

      ownerName = pickedName;
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
      // keep existing photoUrl as-is
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

  Future<void> uploadProfilePhoto() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    final previousUrl = photoUrl;
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1200,
    );
    if (file == null) return;
    _uploadingPhoto = true;
    notifyListeners();
    try {
      final url = await _uploadFile(
        ownerId,
        file,
        'profile/profile_${DateTime.now().millisecondsSinceEpoch}.${_ext(file.name)}',
      );
      photoUrl = url;
      await _firestore
          .collection('salons')
          .doc(ownerId)
          .set({'photoUrl': url, 'updatedAt': FieldValue.serverTimestamp()},
              SetOptions(merge: true));
      // Delete old photo if it exists and is different from the new one
      if (previousUrl != null && previousUrl.isNotEmpty && previousUrl != url) {
        await _deleteOldPhoto(previousUrl);
      }
    } catch (_) {
      _setError('Could not upload photo. Try again.');
    } finally {
      _uploadingPhoto = false;
      notifyListeners();
    }
  }

  Future<String> _uploadFile(String ownerId, XFile file, String path) async {
    final ref = _storage.ref().child('owners').child(ownerId).child(path);
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
}
