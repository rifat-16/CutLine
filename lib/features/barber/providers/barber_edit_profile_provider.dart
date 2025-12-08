import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/barber/providers/barber_profile_provider.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'dart:io';

class BarberEditProfileProvider extends ChangeNotifier {
  BarberEditProfileProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  String? _error;
  BarberProfile? _profile;
  String? _photoUrl;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  bool get isUploadingPhoto => _isUploadingPhoto;
  String? get error => _error;
  BarberProfile? get profile => _profile;
  String? get photoUrl => _photoUrl;

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
      _photoUrl = (data['photoUrl'] as String?)?.trim();
      _profile = BarberProfile(
        uid: uid,
        ownerId: (data['ownerId'] as String?) ?? '',
        name: (data['name'] as String?) ?? '',
        specialization: (data['specialization'] as String?) ?? '',
        phone: (data['phone'] as String?) ?? '',
        email: (data['email'] as String?) ?? '',
        photoUrl: _photoUrl ?? '',
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
      final oldName = _profile?.name ?? '';
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
          photoUrl: _photoUrl ?? '',
        );
      }

      // Update queue items if name changed
      if (oldName.isNotEmpty && oldName != name.trim() && _profile != null) {
        await _updateQueueItems(_profile!.ownerId, uid, oldName, name.trim());
      }

      _setSaving(false);
      return true;
    } catch (_) {
      _setError('Could not save profile. Try again.');
      _setSaving(false);
      return false;
    }
  }

  Future<void> _updateQueueItems(
      String ownerId, String barberId, String oldName, String newName) async {
    try {
      final queueRef = _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('queue');
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await queueRef.get();
      } catch (_) {
        snap = await _firestore.collection('queue').get();
      }

      final batch = _firestore.batch();
      int batchCount = 0;
      const batchLimit = 500;

      for (final doc in snap.docs) {
        final data = doc.data();
        final itemBarberId = data['barberId'] ?? data['barberUid'];
        final itemBarberName = (data['barberName'] as String?) ?? '';

        final shouldUpdate = (itemBarberId is String &&
                itemBarberId.isNotEmpty &&
                itemBarberId == barberId) ||
            (itemBarberName.isNotEmpty &&
                itemBarberName.toLowerCase() == oldName.toLowerCase());

        if (shouldUpdate) {
          batch.update(doc.reference, {
            'barberId': barberId,
            'barberName': newName,
          });
          batchCount++;
          if (batchCount >= batchLimit) {
            await batch.commit();
            batchCount = 0;
          }
        }
      }

      if (batchCount > 0) {
        await batch.commit();
      }
    } catch (_) {
      // Ignore errors in queue update
    }
  }

  Future<String?> uploadProfilePhoto(File file) async {
    final uid = _authProvider.currentUser?.uid;
    if (uid == null) {
      _setError('Please log in again.');
      return null;
    }
    _setError(null);
    _isUploadingPhoto = true;
    notifyListeners();
    try {
      final ext = _ext(file.path);
      final path =
          'barbers/$uid/profile/profile_${DateTime.now().millisecondsSinceEpoch}.$ext';
      final ref = _storage.ref().child(path);
      final snap = await ref.putFile(file).whenComplete(() {});
      final url = await snap.ref.getDownloadURL();
      await _firestore.collection('users').doc(uid).set(
        {
          'photoUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      _photoUrl = url;
      _isUploadingPhoto = false;
      notifyListeners();
      return url;
    } catch (_) {
      _setError('Could not upload photo. Try again.');
      _isUploadingPhoto = false;
      notifyListeners();
      return null;
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

  String _ext(String path) {
    final dot = path.lastIndexOf('.');
    if (dot == -1 || dot == path.length - 1) return 'jpg';
    return path.substring(dot + 1);
  }
}
