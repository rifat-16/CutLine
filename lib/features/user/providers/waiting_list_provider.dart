import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class WaitingListProvider extends ChangeNotifier {
  WaitingListProvider({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  bool _isLoading = false;
  String? _error;
  List<WaitingCustomer> _customers = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WaitingCustomer> get customers => _customers;

  Future<void> load() async {
    _subscription?.cancel();
    _setLoading(true);
    _setError(null);
    try {
      _subscription = _firestore
          .collectionGroup('queue')
          .snapshots()
          .listen((snap) {
        _customers = snap.docs
            .map((doc) => _map(doc.id, doc.data()))
            .whereType<WaitingCustomer>()
            .where((c) => c.status != WaitingStatus.done)
            .toList()
          ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
        notifyListeners();
        _setLoading(false);
      }, onError: (_) {
        _customers = [];
        _setError('Failed to load waiting list.');
        _setLoading(false);
      });
    } catch (_) {
      _customers = [];
      _setError('Failed to load waiting list.');
      _setLoading(false);
    }
  }

  WaitingCustomer? _map(String id, Map<String, dynamic> data) {
    final statusString = (data['status'] as String?) ?? 'waiting';
    final status = _statusFromString(statusString);
    return WaitingCustomer(
      id: id,
      name: (data['customerName'] as String?) ?? 'Customer',
      barber: (data['barberName'] as String?) ?? '',
      service: (data['service'] as String?) ?? 'Service',
      waitMinutes: (data['waitMinutes'] as num?)?.toInt() ?? 0,
      status: status,
      avatar: (data['avatar'] as String?) ?? '',
    );
  }

  WaitingStatus _statusFromString(String status) {
    switch (status) {
      case 'serving':
      case 'serving soon':
        return WaitingStatus.servingSoon;
      case 'done':
      case 'completed':
        return WaitingStatus.done;
      default:
        return WaitingStatus.waiting;
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

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

class WaitingCustomer {
  final String id;
  final String name;
  final String barber;
  final String service;
  final int waitMinutes;
  final WaitingStatus status;
  final String avatar;

  const WaitingCustomer({
    required this.id,
    required this.name,
    required this.barber,
    required this.service,
    required this.waitMinutes,
    required this.status,
    required this.avatar,
  });
}

enum WaitingStatus { waiting, servingSoon, done }
