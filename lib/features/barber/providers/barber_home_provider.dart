import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';

class BarberHomeProvider extends ChangeNotifier {
  BarberHomeProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _queueSubscription;

  bool _isLoading = false;
  String? _error;
  BarberProfile? _profile;
  List<BarberQueueItem> _queue = [];
  bool _salonOpen = true;
  bool _isAvailable = true;
  bool _isUpdatingAvailability = false;
  String? _salonName;

  bool get isLoading => _isLoading;
  String? get error => _error;
  BarberProfile? get profile => _profile;
  List<BarberQueueItem> get queue => _queue;
  bool get isSalonOpen => _salonOpen;
  bool get isAvailable => _isAvailable;
  bool get isUpdatingAvailability => _isUpdatingAvailability;
  String? get salonName => _salonName;

  int get waitingCount => _countStatus(BarberQueueStatus.waiting);
  int get servingCount => _countStatus(BarberQueueStatus.serving);
  int get completedCount => _countStatus(BarberQueueStatus.done);

  Future<void> load() async {
    final uid = _authProvider.currentUser?.uid;
    if (uid == null) {
      debugPrint('load: Barber UID is null');
      _setError('Please log in again.');
      return;
    }
    
    debugPrint('load: Starting for barber UID: $uid');
    _setLoading(true);
    _setError(null);
    
    try {
      // Verify user document exists and has barber role
      try {
        final userDoc = await _firestore.collection('users').doc(uid).get();
        if (!userDoc.exists) {
          debugPrint('load: User document does not exist for barber UID: $uid');
          _setError('User profile not found. Please contact the salon owner.');
          _setLoading(false);
          return;
        }
        final userData = userDoc.data();
        final userRole = userData?['role'] as String?;
        debugPrint('load: User role: $userRole');
        if (userRole != 'barber') {
          debugPrint('load: User role is not barber: $userRole');
          _setError('You do not have barber permissions.');
          _setLoading(false);
          return;
        }
      } catch (e, stackTrace) {
        debugPrint('load: Error verifying user document: $e');
        debugPrint('Stack trace: $stackTrace');
        if (e is FirebaseException && e.code == 'permission-denied') {
          _setError('Permission denied. Please check Firestore rules are deployed.');
          _setLoading(false);
          return;
        }
      }
      
      final profile = await _fetchProfile(uid);
      if (profile == null) {
        debugPrint('load: Could not load barber profile');
        _setError('Could not load your profile. Please contact the salon owner.');
        _setLoading(false);
        return;
      }
      
      debugPrint('load: Profile loaded - name: ${profile.name}, ownerId: ${profile.ownerId}');
      _profile = profile;
      
      try {
        _salonOpen = await _fetchSalonOpen(profile.ownerId);
        debugPrint('load: Salon open status: $_salonOpen');
      } catch (e) {
        debugPrint('load: Error loading salon open status: $e');
        _salonOpen = true; // Default to open
      }
      
      try {
        _salonName = await _fetchSalonName(profile.ownerId);
        debugPrint('load: Salon name: $_salonName');
      } catch (e) {
        debugPrint('load: Error loading salon name: $e');
      }
      
      try {
        _isAvailable = await _fetchAvailability(profile);
        debugPrint('load: Barber availability: $_isAvailable');
      } catch (e) {
        debugPrint('load: Error loading availability: $e');
        _isAvailable = true; // Default to available
      }
      
      if (_salonOpen) {
        _startQueueListener(profile);
        debugPrint('load: Queue listener started');
      } else {
        _queue = [];
        debugPrint('load: Salon is closed, queue cleared');
      }
      
      debugPrint('load: Completed successfully');
    } catch (e, stackTrace) {
      debugPrint('load: Error in load: $e');
      debugPrint('Stack trace: $stackTrace');
      String errorMessage = 'Failed to load data. Pull to refresh.';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          errorMessage = 'Permission denied. Please check Firestore rules are deployed.';
        } else if (e.code == 'unavailable') {
          errorMessage = 'Network error. Check your connection.';
        } else {
          errorMessage = 'Firebase error: ${e.message ?? e.code}';
        }
      }
      _setError(errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  Future<BarberProfile?> _fetchProfile(String uid) async {
    try {
      debugPrint('_fetchProfile: Fetching barber profile for UID: $uid');
      final snap = await _firestore.collection('users').doc(uid).get();
      if (!snap.exists) {
        debugPrint('_fetchProfile: User document does not exist for UID: $uid');
        return null;
      }
      final data = snap.data() ?? {};
      final ownerId = data['ownerId'] as String?;
      if (ownerId == null || ownerId.isEmpty) {
        debugPrint('_fetchProfile: ownerId is null or empty for barber UID: $uid');
        return null;
      }
      final profile = BarberProfile(
        uid: uid,
        ownerId: ownerId,
        name: (data['name'] as String?) ?? '',
        photoUrl: (data['photoUrl'] as String?) ?? '',
      );
      debugPrint('_fetchProfile: Profile loaded - name: ${profile.name}, ownerId: ${profile.ownerId}');
      return profile;
    } catch (e, stackTrace) {
      debugPrint('_fetchProfile: Error fetching barber profile: $e');
      debugPrint('Error code: ${e is FirebaseException ? e.code : "unknown"}');
      debugPrint('Stack trace: $stackTrace');
      if (e is FirebaseException && e.code == 'permission-denied') {
        debugPrint('_fetchProfile: PERMISSION DENIED - Check Firestore rules!');
      }
      return null;
    }
  }

  void _startQueueListener(BarberProfile profile) {
    _queueSubscription?.cancel();
    try {
      debugPrint('_startQueueListener: Starting queue listener for ownerId: ${profile.ownerId}');
      _queueSubscription = _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('queue')
          .snapshots()
          .listen((snapshot) {
        debugPrint('_startQueueListener: Queue snapshot received, ${snapshot.docs.length} documents');
        _queue = snapshot.docs
            .where((doc) => _isForBarber(doc.data(), profile))
            .map((doc) => _mapQueue(doc.id, doc.data(), profile))
            .whereType<BarberQueueItem>()
            .toList()
          ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
        debugPrint('_startQueueListener: Filtered queue items: ${_queue.length}');
        notifyListeners();
      }, onError: (e) {
        debugPrint('_startQueueListener: Error in nested queue listener: $e');
        debugPrint('Error code: ${e is FirebaseException ? e.code : "unknown"}');
        // Fallback to top-level queue collection
        try {
          debugPrint('_startQueueListener: Trying fallback to top-level queue collection');
          _queueSubscription = _firestore
              .collection('queue')
              .snapshots()
              .listen((snapshot) {
            debugPrint('_startQueueListener: Fallback queue snapshot received, ${snapshot.docs.length} documents');
            _queue = snapshot.docs
                .where((doc) => _isForBarber(doc.data(), profile))
                .map((doc) => _mapQueue(doc.id, doc.data(), profile))
                .whereType<BarberQueueItem>()
                .toList()
              ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
            debugPrint('_startQueueListener: Fallback filtered queue items: ${_queue.length}');
            notifyListeners();
          }, onError: (e2) {
            debugPrint('_startQueueListener: Error in fallback queue listener: $e2');
            _setError('Failed to load queue. Pull to refresh.');
          });
        } catch (e3) {
          debugPrint('_startQueueListener: Error setting up fallback listener: $e3');
          _setError('Failed to load queue. Pull to refresh.');
        }
      });
    } catch (e) {
      debugPrint('_startQueueListener: Error setting up queue listener: $e');
      _setError('Failed to load queue. Pull to refresh.');
    }
  }

  bool _isForBarber(Map<String, dynamic> data, BarberProfile profile) {
    final barberId = data['barberId'] ?? data['barberUid'];
    if (barberId is String && barberId.isNotEmpty && barberId == profile.uid) {
      return true;
    }
    final barberName =
        (data['barberName'] as String?) ?? (data['barber'] as String?);
    if (barberName != null &&
        profile.name.isNotEmpty &&
        barberName.toLowerCase() == profile.name.toLowerCase()) {
      return true;
    }
    // allow unassigned queue items to surface so barbers can claim them
    return barberId == null && barberName == null;
  }

  BarberQueueItem? _mapQueue(
      String id, Map<String, dynamic> data, BarberProfile profile) {
    final status = _statusFromString((data['status'] as String?) ?? 'waiting');
    DateTime? startedAt;
    DateTime? completedAt;
    if (data['startedAt'] != null) {
      final ts = data['startedAt'];
      if (ts is Timestamp) {
        startedAt = ts.toDate();
      }
    }
    if (data['completedAt'] != null) {
      final ts = data['completedAt'];
      if (ts is Timestamp) {
        completedAt = ts.toDate();
      }
    }
    return BarberQueueItem(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      service: (data['service'] as String?) ?? 'Service',
      barberName: (data['barberName'] as String?) ?? profile.name,
      price: (data['price'] as num?)?.toInt() ?? 0,
      status: status,
      waitMinutes: (data['waitMinutes'] as num?)?.toInt() ?? 0,
      slotLabel: (data['slotLabel'] as String?) ?? id,
      customerPhone: (data['customerPhone'] as String?) ?? '',
      note: data['note'] as String?,
      startedAt: startedAt,
      completedAt: completedAt,
    );
  }

  Future<bool> _fetchSalonOpen(String ownerId) async {
    if (ownerId.isEmpty) {
      debugPrint('_fetchSalonOpen: ownerId is empty');
      return true;
    }
    try {
      debugPrint('_fetchSalonOpen: Checking salon open status for ownerId: $ownerId');
      final doc = await _firestore.collection('salons').doc(ownerId).get();
      if (!doc.exists) {
        debugPrint('_fetchSalonOpen: Salon document does not exist');
        return true;
      }
      final data = doc.data() ?? {};
      final isOpen = data['isOpen'];
      if (isOpen is bool) {
        debugPrint('_fetchSalonOpen: Salon isOpen: $isOpen');
        return isOpen;
      }
      debugPrint('_fetchSalonOpen: isOpen field is not boolean, defaulting to true');
      return true;
    } catch (e) {
      debugPrint('_fetchSalonOpen: Error checking salon open status: $e');
      return true;
    }
  }

  Future<String?> _fetchSalonName(String ownerId) async {
    if (ownerId.isEmpty) {
      debugPrint('_fetchSalonName: ownerId is empty');
      return null;
    }
    try {
      debugPrint('_fetchSalonName: Fetching salon name for ownerId: $ownerId');
      final doc = await _firestore.collection('salons').doc(ownerId).get();
      if (!doc.exists) {
        debugPrint('_fetchSalonName: Salon document does not exist');
        return null;
      }
      final data = doc.data() ?? {};
      final name = data['name'] as String?;
      debugPrint('_fetchSalonName: Salon name: $name');
      return name;
    } catch (e) {
      debugPrint('_fetchSalonName: Error fetching salon name: $e');
      return null;
    }
  }

  Future<bool> _fetchAvailability(BarberProfile profile) async {
    try {
      final doc = await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('barbers')
          .doc(profile.uid)
          .get();
      if (!doc.exists) return true;
      final data = doc.data() ?? {};
      final available = data['isAvailable'];
      if (available is bool) return available;
    } catch (_) {
      // ignore
    }
    return true;
  }

  Future<void> setAvailability(bool value) async {
    final profile = _profile;
    if (profile == null) return;
    final previous = _isAvailable;
    _isAvailable = value;
    _isUpdatingAvailability = true;
    notifyListeners();
    try {
      await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('barbers')
          .doc(profile.uid)
          .set(
        {
          'isAvailable': value,
          'uid': profile.uid,
          'name': profile.name,
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      _isAvailable = previous;
      _setError('Could not update availability.');
    } finally {
      _isUpdatingAvailability = false;
      notifyListeners();
    }
  }

  BarberQueueStatus _statusFromString(String status) {
    switch (status) {
      case 'serving':
        return BarberQueueStatus.serving;
      case 'done':
      case 'completed':
        return BarberQueueStatus.done;
      default:
        return BarberQueueStatus.waiting;
    }
  }

  Future<void> updateStatus(String id, BarberQueueStatus status) async {
    final profile = _profile;
    if (profile == null) return;
    try {
      final statusString =
          status == BarberQueueStatus.done ? 'completed' : status.name;
      final updateData = <String, dynamic>{'status': status.name};
      
      if (status == BarberQueueStatus.serving) {
        updateData['startedAt'] = FieldValue.serverTimestamp();
      } else if (status == BarberQueueStatus.done) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }

      await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('queue')
          .doc(id)
          .set(updateData, SetOptions(merge: true));
      await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('bookings')
          .doc(id)
          .set({'status': statusString}, SetOptions(merge: true));
    } catch (_) {
      // ignore write failures for now
    }
    final index = _queue.indexWhere((item) => item.id == id);
    if (index != -1) {
      final now = DateTime.now();
      _queue[index] = _queue[index].copyWith(
        status: status,
        startedAt: status == BarberQueueStatus.serving ? now : _queue[index].startedAt,
        completedAt: status == BarberQueueStatus.done ? now : _queue[index].completedAt,
      );
      notifyListeners();
    }
  }

  int _countStatus(BarberQueueStatus status) {
    return _queue.where((item) => item.status == status).length;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }
}

class BarberProfile {
  final String uid;
  final String ownerId;
  final String name;
  final String photoUrl;

  const BarberProfile({
    required this.uid,
    required this.ownerId,
    required this.name,
    required this.photoUrl,
  });
}

class BarberQueueItem {
  final String id;
  final String customerName;
  final String service;
  final String barberName;
  final int price;
  final BarberQueueStatus status;
  final int waitMinutes;
  final String slotLabel;
  final String customerPhone;
  final String? note;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const BarberQueueItem({
    required this.id,
    required this.customerName,
    required this.service,
    required this.barberName,
    required this.price,
    required this.status,
    required this.waitMinutes,
    required this.slotLabel,
    required this.customerPhone,
    this.note,
    this.startedAt,
    this.completedAt,
  });

  BarberQueueItem copyWith({
    BarberQueueStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return BarberQueueItem(
      id: id,
      customerName: customerName,
      service: service,
      barberName: barberName,
      price: price,
      status: status ?? this.status,
      waitMinutes: waitMinutes,
      slotLabel: slotLabel,
      customerPhone: customerPhone,
      note: note,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

enum BarberQueueStatus { waiting, serving, done }