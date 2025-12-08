import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
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
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final profile = await _fetchProfile(uid);
      if (profile == null) {
        _setError('Could not load your profile.');
        return;
      }
      _profile = profile;
      _salonOpen = await _fetchSalonOpen(profile.ownerId);
      _salonName = await _fetchSalonName(profile.ownerId);
      _isAvailable = await _fetchAvailability(profile);
      if (_salonOpen) {
        _startQueueListener(profile);
      } else {
        _queue = [];
      }
    } catch (_) {
      _setError('Failed to load data. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  Future<BarberProfile?> _fetchProfile(String uid) async {
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      if (!snap.exists) return null;
      final data = snap.data() ?? {};
      final ownerId = data['ownerId'] as String?;
      if (ownerId == null || ownerId.isEmpty) return null;
      return BarberProfile(
        uid: uid,
        ownerId: ownerId,
        name: (data['name'] as String?) ?? '',
        photoUrl: (data['photoUrl'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  void _startQueueListener(BarberProfile profile) {
    _queueSubscription?.cancel();
    try {
      _queueSubscription = _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('queue')
          .snapshots()
          .listen((snapshot) {
        _queue = snapshot.docs
            .where((doc) => _isForBarber(doc.data(), profile))
            .map((doc) => _mapQueue(doc.id, doc.data(), profile))
            .whereType<BarberQueueItem>()
            .toList()
          ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
        notifyListeners();
      }, onError: (_) {
        // Fallback to top-level queue collection
        _queueSubscription = _firestore
            .collection('queue')
            .snapshots()
            .listen((snapshot) {
          _queue = snapshot.docs
              .where((doc) => _isForBarber(doc.data(), profile))
              .map((doc) => _mapQueue(doc.id, doc.data(), profile))
              .whereType<BarberQueueItem>()
              .toList()
            ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
          notifyListeners();
        }, onError: (_) {
          _setError('Failed to load queue. Pull to refresh.');
        });
      });
    } catch (_) {
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
    if (ownerId.isEmpty) return true;
    try {
      final doc = await _firestore.collection('salons').doc(ownerId).get();
      if (!doc.exists) return true;
      final data = doc.data() ?? {};
      final isOpen = data['isOpen'];
      if (isOpen is bool) return isOpen;
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<String?> _fetchSalonName(String ownerId) async {
    if (ownerId.isEmpty) return null;
    try {
      final doc = await _firestore.collection('salons').doc(ownerId).get();
      if (!doc.exists) return null;
      final data = doc.data() ?? {};
      return data['name'] as String?;
    } catch (_) {
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