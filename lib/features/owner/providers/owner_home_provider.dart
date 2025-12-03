import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class OwnerHomeProvider extends ChangeNotifier {
  OwnerHomeProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  String? _salonName;
  List<OwnerQueueItem> _queueItems = [];
  int _pendingRequests = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get salonName => _salonName;
  List<OwnerQueueItem> get queueItems => _queueItems;
  int get pendingRequests => _pendingRequests;

  Future<void> fetchAll() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      await Future.wait([
        _loadSalon(ownerId),
        _loadQueue(ownerId),
        _loadBookingRequests(ownerId),
      ]);
    } catch (e) {
      _setError('Failed to load data. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadSalon(String ownerId) async {
    final doc = await _firestore.collection('salons').doc(ownerId).get();
    if (doc.exists) {
      _salonName = (doc.data() ?? {})['name'] as String?;
    }
  }

  Future<void> _loadQueue(String ownerId) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('queue')
          .get();
    } catch (_) {
      snap = await _firestore.collection('queue').get();
    }
    _queueItems = snap.docs
        .map((doc) => _mapQueue(doc.id, doc.data()))
        .whereType<OwnerQueueItem>()
        .toList();
  }

  Future<void> _loadBookingRequests(String ownerId) async {
    try {
      final snap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('bookingRequests')
          .where('status', isEqualTo: 'pending')
          .get();
      _pendingRequests = snap.size;
    } catch (_) {
      _pendingRequests = 0;
    }
  }

  OwnerQueueItem? _mapQueue(String id, Map<String, dynamic> data) {
    final statusString = (data['status'] as String?) ?? 'waiting';
    final status = _statusFromString(statusString);
    return OwnerQueueItem(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      service: (data['service'] as String?) ?? 'Service',
      barberName: (data['barberName'] as String?) ?? 'Barber',
      price: (data['price'] as num?)?.toInt() ?? 0,
      status: status,
      waitMinutes: (data['waitMinutes'] as num?)?.toInt() ?? 0,
      slotLabel: (data['slotLabel'] as String?) ?? id,
      customerPhone: (data['customerPhone'] as String?) ?? '',
      note: data['note'] as String?,
    );
  }

  OwnerQueueStatus _statusFromString(String status) {
    switch (status) {
      case 'serving':
        return OwnerQueueStatus.serving;
      case 'done':
      case 'completed':
        return OwnerQueueStatus.done;
      default:
        return OwnerQueueStatus.waiting;
    }
  }

  Future<void> updateQueueStatus(String id, OwnerQueueStatus status) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    try {
      await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('queue')
          .doc(id)
          .set({'status': status.name}, SetOptions(merge: true));
    } catch (_) {
      // ignore write failures for now
    }
    final index = _queueItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      _queueItems[index] = _queueItems[index].copyWith(status: status);
      notifyListeners();
    }
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
