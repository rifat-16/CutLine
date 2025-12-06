import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/services/owner_queue_service.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class ManageQueueProvider extends ChangeNotifier {
  ManageQueueProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
    OwnerQueueService? queueService,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _queueService =
            queueService ?? OwnerQueueService(firestore: firestore) {
    _queueSubscription = _queueService.onChanged.listen((_) {
      _refreshSilent();
    });
  }

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  final OwnerQueueService _queueService;
  StreamSubscription<void>? _queueSubscription;

  bool _isLoading = false;
  String? _error;
  List<OwnerQueueItem> _queue = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<OwnerQueueItem> get queue => _queue;

  Future<void> load() async {
    await _fetchQueue(showLoading: true);
  }

  Future<void> updateStatus(String id, OwnerQueueStatus status) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    try {
      await _queueService.updateStatus(ownerId: ownerId, id: id, status: status);
    } catch (_) {
      // ignore for now
    }

    _queue = _queue
        .map((item) => item.id == id ? item.copyWith(status: status) : item)
        .toList();
    notifyListeners();
  }

  Future<void> _fetchQueue({bool showLoading = false}) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    if (showLoading) {
      _setLoading(true);
      _setError(null);
    }
    try {
      _queue = await _queueService.loadQueue(ownerId);
    } catch (_) {
      if (showLoading) _setError('Failed to load queue.');
    } finally {
      if (showLoading) _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> _refreshSilent() => _fetchQueue(showLoading: false);

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
