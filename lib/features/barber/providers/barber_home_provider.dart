import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';

class BarberHomeProvider extends ChangeNotifier {
  BarberHomeProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  BarberProfile? _profile;
  List<BarberQueueItem> _queue = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  BarberProfile? get profile => _profile;
  List<BarberQueueItem> get queue => _queue;

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
      _queue = await _fetchQueue(profile);
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
      );
    } catch (_) {
      return null;
    }
  }

  Future<List<BarberQueueItem>> _fetchQueue(BarberProfile profile) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('queue')
          .get();
    } catch (_) {
      snap = await _firestore.collection('queue').get();
    }

    return snap.docs
        .where((doc) => _isForBarber(doc.data(), profile))
        .map((doc) => _mapQueue(doc.id, doc.data(), profile))
        .whereType<BarberQueueItem>()
        .toList()
      ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
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
    );
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
      await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('queue')
          .doc(id)
          .set({'status': status.name}, SetOptions(merge: true));
    } catch (_) {
      // ignore write failures for now
    }
    final index = _queue.indexWhere((item) => item.id == id);
    if (index != -1) {
      _queue[index] = _queue[index].copyWith(status: status);
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
}

class BarberProfile {
  final String uid;
  final String ownerId;
  final String name;

  const BarberProfile({
    required this.uid,
    required this.ownerId,
    required this.name,
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
  });

  BarberQueueItem copyWith({BarberQueueStatus? status}) {
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
    );
  }
}

enum BarberQueueStatus { waiting, serving, done }
