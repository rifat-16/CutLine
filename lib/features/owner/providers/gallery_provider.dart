import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/shared/services/firestore_cache.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class GalleryProvider extends ChangeNotifier {
  GalleryProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  bool _isLoading = false;
  bool _isUploadingCover = false;
  bool _isUploadingGallery = false;
  bool _isEditMode = false;
  String? _error;
  String? _coverPhotoUrl;
  final List<String> _galleryUrls = [];

  bool get isLoading => _isLoading;
  bool get isUploadingCover => _isUploadingCover;
  bool get isUploadingGallery => _isUploadingGallery;
  bool get isEditMode => _isEditMode;
  String? get error => _error;
  String? get coverPhotoUrl => _coverPhotoUrl;
  List<String> get galleryUrls => List.unmodifiable(_galleryUrls);

  void toggleEditMode() {
    _isEditMode = !_isEditMode;
    notifyListeners();
  }

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final doc =
          await FirestoreCache.getDoc(_firestore.collection('salons').doc(ownerId));
      if (doc.exists) {
        final data = doc.data() ?? {};
        _coverPhotoUrl = (data['coverImageUrl'] as String?) ??
            (data['coverPhoto'] as String?) ??
            (data['coverPhotoUrl'] as String?) ??
            '';
      }
      await _loadGallery(ownerId);
    } catch (_) {
      _setError('Failed to load gallery. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> uploadCoverPhoto() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (file == null) return;

    _isUploadingCover = true;
    _setError(null);
    notifyListeners();
    try {
      // Delete old photo if exists
      final previousUrl = _coverPhotoUrl;
      if (previousUrl != null && previousUrl.isNotEmpty) {
        await _deleteOldPhoto(previousUrl);
      }
      
      final url = await _uploadFile(
        ownerId: ownerId,
        file: file,
        path: 'cover/cover_${DateTime.now().millisecondsSinceEpoch}.${_ext(file.name)}',
      );
      _coverPhotoUrl = url;
      await _firestore.collection('salons').doc(ownerId).set(
        {
          'coverPhoto': url,
          'coverPhotoUrl': url,
          'coverImageUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await _firestore.collection('salons_summary').doc(ownerId).set(
        {
          'coverImageUrl': url,
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      _setError('Failed to upload cover photo. Try again.');
    } finally {
      _isUploadingCover = false;
      notifyListeners();
    }
  }

  Future<void> changeCoverPhoto() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (file == null) return;

    _isUploadingCover = true;
    _setError(null);
    notifyListeners();
    try {
      // Delete old photo if exists
      final previousUrl = _coverPhotoUrl;
      if (previousUrl != null && previousUrl.isNotEmpty) {
        await _deleteOldPhoto(previousUrl);
      }
      
      final url = await _uploadFile(
        ownerId: ownerId,
        file: file,
        path: 'cover/cover_${DateTime.now().millisecondsSinceEpoch}.${_ext(file.name)}',
      );
      _coverPhotoUrl = url;
      await _firestore.collection('salons').doc(ownerId).set(
        {
          'coverPhoto': url,
          'coverPhotoUrl': url,
          'coverImageUrl': url,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await _firestore.collection('salons_summary').doc(ownerId).set(
        {
          'coverImageUrl': url,
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      _setError('Failed to change cover photo. Try again.');
    } finally {
      _isUploadingCover = false;
      notifyListeners();
    }
  }

  Future<void> changeGalleryPhoto(int index) async {
    if (index < 0 || index >= _galleryUrls.length) return;
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (file == null) return;

    _isUploadingGallery = true;
    _setError(null);
    notifyListeners();
    try {
      // Delete old photo
      final previousUrl = _galleryUrls[index];
      if (previousUrl.isNotEmpty) {
        await _deleteOldPhoto(previousUrl);
      }
      
      final url = await _uploadFile(
        ownerId: ownerId,
        file: file,
        path:
            'gallery/gallery_${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode}.${_ext(file.name)}',
      );
      _galleryUrls[index] = url;
      await _syncGalleryPhotos(ownerId);
    } catch (_) {
      _setError('Failed to change photo. Try again.');
    } finally {
      _isUploadingGallery = false;
      notifyListeners();
    }
  }

  Future<void> uploadGalleryPhotos() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    final files = await _picker.pickMultiImage(
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (files.isEmpty) return;

    final remaining = 10 - _galleryUrls.length;
    final toUpload =
        remaining <= 0 ? <XFile>[] : files.take(remaining).toList();
    if (toUpload.isEmpty) {
      _setError('You can upload up to 10 gallery photos.');
      return;
    }

    _isUploadingGallery = true;
    _setError(null);
    notifyListeners();
    try {
      for (final file in toUpload) {
        final url = await _uploadFile(
          ownerId: ownerId,
          file: file,
          path:
              'gallery/gallery_${DateTime.now().millisecondsSinceEpoch}_${file.name.hashCode}.${_ext(file.name)}',
        );
        _galleryUrls.add(url);
      }
      await _syncGalleryPhotos(ownerId);
    } catch (_) {
      _setError('Failed to upload some photos. Try again.');
    } finally {
      _isUploadingGallery = false;
      notifyListeners();
    }
  }

  Future<void> deleteCoverPhoto() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;

    final url = _coverPhotoUrl;
    _coverPhotoUrl = null;
    notifyListeners();

    try {
      await _firestore.collection('salons').doc(ownerId).set(
        {
          'coverPhoto': FieldValue.delete(),
          'coverPhotoUrl': FieldValue.delete(),
          'coverImageUrl': FieldValue.delete(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      await _firestore.collection('salons_summary').doc(ownerId).set(
        {
          'coverImageUrl': FieldValue.delete(),
        },
        SetOptions(merge: true),
      );
      // Optionally delete from storage
      if (url != null && url.isNotEmpty) {
        try {
          final ref = _storage.refFromURL(url);
          await ref.delete();
        } catch (_) {
          // Ignore storage deletion errors
        }
      }
    } catch (_) {
      _coverPhotoUrl = url;
      notifyListeners();
      _setError('Failed to delete cover photo. Try again.');
    }
  }

  Future<void> deleteGalleryPhoto(int index) async {
    if (index < 0 || index >= _galleryUrls.length) return;
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;

    final url = _galleryUrls[index];
    _galleryUrls.removeAt(index);
    notifyListeners();

    try {
      await _syncGalleryPhotos(ownerId);
      // Optionally delete from storage
      try {
        final ref = _storage.refFromURL(url);
        await ref.delete();
      } catch (_) {
        // Ignore storage deletion errors
      }
    } catch (_) {
      _galleryUrls.insert(index, url);
      notifyListeners();
      _setError('Failed to delete photo. Try again.');
    }
  }

  Future<String> _uploadFile({
    required String ownerId,
    required XFile file,
    required String path,
  }) async {
    final ref = _storage.ref().child('salons').child(ownerId).child(path);
    final uploadTask = ref.putFile(File(file.path));
    final snap = await uploadTask.whenComplete(() {});
    return snap.ref.getDownloadURL();
  }

  String _ext(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'jpg';
    return name.substring(dot + 1);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  Future<void> _deleteOldPhoto(String url) async {
    try {
      final ref = _storage.refFromURL(url);
      await ref.delete();
    } catch (_) {
      // Ignore cleanup failures
    }
  }

  Future<void> _loadGallery(String ownerId) async {
    try {
      final query = _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('photos')
          .orderBy('order');
      final snap = await FirestoreCache.getQuery(query);
      final urls = snap.docs
          .map((doc) => (doc.data()['url'] as String?)?.trim() ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
      _galleryUrls
        ..clear()
        ..addAll(urls);
    } catch (_) {
      try {
        final snap = await FirestoreCache.getQuery(_firestore
            .collection('salons')
            .doc(ownerId)
            .collection('photos'));
        final urls = snap.docs
            .map((doc) => (doc.data()['url'] as String?)?.trim() ?? '')
            .where((url) => url.isNotEmpty)
            .toList();
        _galleryUrls
          ..clear()
          ..addAll(urls);
      } catch (_) {
        _galleryUrls.clear();
      }
    }
  }

  Future<void> _syncGalleryPhotos(String ownerId) async {
    final collection =
        _firestore.collection('salons').doc(ownerId).collection('photos');
    final existing = await FirestoreCache.getQuery(collection);
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (var i = 0; i < _galleryUrls.length; i++) {
      final url = _galleryUrls[i].trim();
      if (url.isEmpty) continue;
      batch.set(collection.doc(), {
        'url': url,
        'order': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
    await _firestore.collection('salons').doc(ownerId).set(
      {
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
  }
}
