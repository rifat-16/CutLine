import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';

class WorkHistoryProvider extends ChangeNotifier {
  WorkHistoryProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  List<WorkHistoryItem> _items = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WorkHistoryItem> get items => _items;

  Future<void> load() async {
    final uid = _authProvider.currentUser?.uid;
    if (uid == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final userSnap = await _firestore.collection('users').doc(uid).get();
      final ownerId = (userSnap.data() ?? {})['ownerId'] as String?;
      if (ownerId == null || ownerId.isEmpty) {
        _setError('Owner not found for this account.');
        _items = [];
        return;
      }
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _firestore
            .collection('salons')
            .doc(ownerId)
            .collection('queue')
            .where('barberId', isEqualTo: uid)
            .get();
      } catch (_) {
        snap = await _firestore.collection('queue').get();
      }
      _items = snap.docs
          .map((doc) => _mapItem(doc.data()))
          .where((item) => item != null)
          .cast<WorkHistoryItem>()
          .where((item) => item.status == 'completed' || item.status == 'done')
          .toList()
        ..sort((a, b) => b.time.compareTo(a.time));
    } catch (_) {
      _setError('Failed to load history. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  WorkHistoryItem? _mapItem(Map<String, dynamic> data) {
    final ts = data['updatedAt'] ?? data['timestamp'] ?? data['time'];
    DateTime time;
    if (ts is Timestamp) {
      time = ts.toDate();
    } else {
      time = DateTime.now();
    }
    return WorkHistoryItem(
      service: (data['service'] as String?) ?? 'Service',
      client: (data['customerName'] as String?) ?? 'Client',
      price: (data['price'] as num?)?.toInt() ?? 0,
      status: (data['status'] as String?) ?? 'completed',
      time: time,
    );
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

class WorkHistoryItem {
  final String service;
  final String client;
  final int price;
  final String status;
  final DateTime time;

  const WorkHistoryItem({
    required this.service,
    required this.client,
    required this.price,
    required this.status,
    required this.time,
  });
}
