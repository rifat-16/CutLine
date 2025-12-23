import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/services/barber_service.dart';
import 'package:cutline/features/owner/services/salon_service.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

enum SetupStep { basics, hours, services, photos, barbers }

class BarberInput {
  final String name;
  final String specialization;
  final String email;
  final String phone;
  final String password;

  const BarberInput({
    required this.name,
    required this.specialization,
    required this.email,
    required this.phone,
    required this.password,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name.trim(),
      'specialization': specialization.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
    };
  }
}

class SalonSetupProvider extends ChangeNotifier {
  SalonSetupProvider({
    required AuthProvider authProvider,
    SalonService? salonService,
    BarberService? barberService,
  })  : _authProvider = authProvider,
        _salonService = salonService ?? SalonService(),
        _barberService = barberService ?? BarberService() {
    _workingHours = {
      'Monday': _defaultDayTime(true, 9, 21),
      'Tuesday': _defaultDayTime(true, 9, 21),
      'Wednesday': _defaultDayTime(true, 9, 21),
      'Thursday': _defaultDayTime(true, 9, 21),
      'Friday': _defaultDayTime(true, 9, 21),
      'Saturday': _defaultDayTime(true, 10, 22),
      'Sunday': _defaultDayTime(false, 10, 20),
    };
    _services = [];
  }

  final AuthProvider _authProvider;
  final SalonService _salonService;
  final BarberService _barberService;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final ImagePicker _picker = ImagePicker();

  late Map<String, Map<String, dynamic>> _workingHours;
  late List<OwnerServiceInfo> _services;
  List<BarberInput> _barbers = [];
  String? _coverPhotoUrl;
  final List<String> _galleryUrls = [];
  bool _uploadingCover = false;
  bool _uploadingGallery = false;
  bool _isSaving = false;
  String? _error;
  SetupStep _currentStep = SetupStep.basics;
  final Set<SetupStep> _completed = {};

  Map<String, Map<String, dynamic>> get workingHours => _workingHours;
  List<OwnerServiceInfo> get services => _services;
  List<BarberInput> get barbers => _barbers;
  String? get coverPhotoUrl => _coverPhotoUrl;
  List<String> get galleryUrls => List.unmodifiable(_galleryUrls);
  bool get isUploadingCover => _uploadingCover;
  bool get isUploadingGallery => _uploadingGallery;
  bool get isSaving => _isSaving;
  String? get error => _error;
  SetupStep get currentStep => _currentStep;
  Set<SetupStep> get completedSteps => _completed;

  void updateWorkingHours(String day,
      {bool? open, TimeOfDay? openTime, TimeOfDay? closeTime}) {
    final existing = _workingHours[day];
    if (existing == null) return;
    _workingHours = {
      ..._workingHours,
      day: {
        'open': open ?? existing['open'] as bool,
        'openTime': openTime ?? existing['openTime'] as TimeOfDay,
        'closeTime': closeTime ?? existing['closeTime'] as TimeOfDay,
      },
    };
    notifyListeners();
  }

  void updateServices(List<OwnerServiceInfo> services) {
    _services = services;
    notifyListeners();
  }

  void updateBarbers(List<BarberInput> barbers) {
    _barbers = barbers;
    notifyListeners();
  }

  void goToStep(SetupStep step) {
    _currentStep = step;
    notifyListeners();
  }

  void markCurrentComplete() {
    _completed.add(_currentStep);
    notifyListeners();
  }

  bool nextStep() {
    if (_currentStep == SetupStep.barbers) return false;
    _currentStep = SetupStep.values[_currentStep.index + 1];
    notifyListeners();
    return true;
  }

  Future<bool> saveSalon({
    required String name,
    required String address,
    required GeoPoint location,
    required String geohash,
    required String contact,
    required String email,
  }) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again to continue.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    try {
      List<Map<String, dynamic>>? barberData;
      if (_barbers.isNotEmpty) {
        final results = await _barberService.createBarbers(
          ownerId: ownerId,
          barbers: _barbers,
        );
        final failures = results
            .where((r) => !r.isSuccess)
            .map((r) => r.error)
            .whereType<String>()
            .toList();
        if (failures.isNotEmpty) {
          _setError(failures.join('\n'));
          _setSaving(false);
          return false;
        }
        barberData = results
            .where((r) => r.isSuccess)
            .map((r) => {
                  'uid': r.uid,
                  ...r.input.toMap(),
                  'ownerId': ownerId,
                })
            .toList();
      }

      await _salonService.saveSalon(
        ownerId: ownerId,
        name: name,
        address: address,
        location: location,
        geohash: geohash,
        contact: contact,
        email: email,
        workingHours: _mapWorkingHours(),
        services: _mapServices(),
        barbers: barberData ?? _mapBarbers(),
        coverPhotoUrl: _coverPhotoUrl,
        galleryPhotos: _galleryUrls,
      );
      return true;
    } catch (_) {
      _setError('Could not save salon. Please try again.');
      return false;
    } finally {
      _setSaving(false);
    }
  }

  Map<String, dynamic> _mapWorkingHours() {
    return _workingHours.map((day, data) {
      final openTime = data['openTime'] as TimeOfDay;
      final closeTime = data['closeTime'] as TimeOfDay;
      return MapEntry(day, {
        'open': data['open'] as bool,
        'openTime': _formatTime(openTime),
        'closeTime': _formatTime(closeTime),
      });
    });
  }

  List<Map<String, dynamic>> _mapServices() {
    final source = _services.isEmpty ? kOwnerDefaultServices : _services;
    return source
        .map((service) => {
              'name': service.name,
              'price': service.price,
              'durationMinutes': service.durationMinutes,
            })
        .toList();
  }

  List<Map<String, dynamic>> _mapBarbers() {
    return _barbers.map((b) => b.toMap()).toList();
  }

  Future<void> uploadCoverPhoto() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again to upload photos.');
      return;
    }
    final file = await _picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
      maxWidth: 1800,
    );
    if (file == null) return;

    _uploadingCover = true;
    notifyListeners();
    try {
      final url = await _uploadFile(
        ownerId: ownerId,
        file: file,
        path:
            'cover/cover_${DateTime.now().millisecondsSinceEpoch}.${_ext(file.name)}',
      );
      _coverPhotoUrl = url;
    } catch (_) {
      _setError('Failed to upload cover photo. Try again.');
    } finally {
      _uploadingCover = false;
      notifyListeners();
    }
  }

  Future<void> uploadGalleryPhotos() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again to upload photos.');
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

    _uploadingGallery = true;
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
    } catch (_) {
      _setError('Failed to upload some photos. Try again.');
    } finally {
      _uploadingGallery = false;
      notifyListeners();
    }
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  Map<String, dynamic> _defaultDayTime(bool open, int openHour, int closeHour) {
    return {
      'open': open,
      'openTime': TimeOfDay(hour: openHour, minute: 0),
      'closeTime': TimeOfDay(hour: closeHour, minute: 0),
    };
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
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
}
