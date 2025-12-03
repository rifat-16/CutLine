import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class ManageQueueProvider extends ChangeNotifier {
  ManageQueueProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  List<OwnerQueueItem> _queue = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<OwnerQueueItem> get queue => _queue;

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
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
      _queue = snap.docs
          .map((doc) => _mapQueue(doc.id, doc.data()))
          .whereType<OwnerQueueItem>()
          .toList();
    } catch (_) {
      _setError('Failed to load queue.');
    } finally {
      _setLoading(false);
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

  Future<void> updateStatus(String id, OwnerQueueStatus status) async {
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
      // ignore for now
    }
    _queue = _queue
        .map((item) => item.id == id ? item.copyWith(status: status) : item)
        .toList();
    notifyListeners();
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
