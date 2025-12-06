import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'dart:async';

import 'package:cutline/features/owner/services/owner_queue_service.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class OwnerHomeProvider extends ChangeNotifier {
  OwnerHomeProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
    OwnerQueueService? queueService,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _queueService =
            queueService ?? OwnerQueueService(firestore: firestore) {
    _queueSubscription = _queueService.onChanged.listen((_) {
      _refreshQueue();
    });
  }

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  final OwnerQueueService _queueService;
  StreamSubscription<void>? _queueSubscription;

  bool _isLoading = false;
  String? _error;
  String? _salonName;
  List<OwnerQueueItem> _queueItems = [];
  int _pendingRequests = 0;
  bool _isOpen = true;
  bool _isUpdatingStatus = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get salonName => _salonName;
  List<OwnerQueueItem> get queueItems => _queueItems;
  int get pendingRequests => _pendingRequests;
  bool get isOpen => _isOpen;
  bool get isUpdatingStatus => _isUpdatingStatus;

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
      final data = doc.data() ?? {};
      _salonName = data['name'] as String?;
      _isOpen = (data['isOpen'] as bool?) ?? _isOpen;
    }
  }

  Future<void> _loadQueue(String ownerId) async {
    _queueItems = await _queueService.loadQueue(ownerId);
    notifyListeners();
  }

  Future<void> _loadBookingRequests(String ownerId) async {
    final collection = _firestore
        .collection('salons')
        .doc(ownerId)
        .collection('bookings');
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await collection
            .where('status', whereIn: ['pending', 'upcoming'])
            .get();
      } catch (_) {
        snap = await collection.where('status', isEqualTo: 'upcoming').get();
      }
      _pendingRequests = snap.size;
    } catch (_) {
      _pendingRequests = 0;
    }
  }

  Future<void> setSalonOpen(bool value) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    final previous = _isOpen;
    _isOpen = value;
    _isUpdatingStatus = true;
    _setError(null);
    notifyListeners();
    try {
      await _firestore
          .collection('salons')
          .doc(ownerId)
          .set({'isOpen': value}, SetOptions(merge: true));
    } catch (_) {
      _isOpen = previous;
      _setError('Could not update status. Try again.');
    } finally {
      _isUpdatingStatus = false;
      notifyListeners();
    }
  }

  Future<void> updateQueueStatus(String id, OwnerQueueStatus status) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    try {
      await _queueService.updateStatus(ownerId: ownerId, id: id, status: status);
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

  Future<void> _refreshQueue() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    try {
      _queueItems = await _queueService.loadQueue(ownerId);
      notifyListeners();
    } catch (_) {
      // silent fail
    }
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }
}
