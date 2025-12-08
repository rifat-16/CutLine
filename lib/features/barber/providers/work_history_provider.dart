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
      final userData = userSnap.data() ?? {};
      final ownerId = userData['ownerId'] as String?;
      final barberName = (userData['name'] as String?) ?? '';
      
      if (ownerId == null || ownerId.isEmpty) {
        _setError('Owner not found for this account.');
        _items = [];
        return;
      }

      // Fetch salon barbers list for name-to-ID mapping
      Map<String, String> nameToIdMap = {};
      try {
        final salonDoc =
            await _firestore.collection('salons').doc(ownerId).get();
        final salonData = salonDoc.data() ?? {};
        final barbersList = salonData['barbers'] as List?;
        if (barbersList != null) {
          for (final barber in barbersList) {
            if (barber is Map) {
              final id = barber['id'] as String?;
              final name = barber['name'] as String?;
              if (id != null && name != null) {
                nameToIdMap[name.toLowerCase()] = id;
              }
            }
          }
        }
      } catch (_) {
        // Ignore errors in fetching barbers list
      }

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

      _items = snap.docs
          .map((doc) => _mapItem(doc.data(), uid, barberName, nameToIdMap))
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

  bool _matchesBarber(Map<String, dynamic> data, String barberId,
      String barberName, Map<String, String> nameToIdMap) {
    // Check by barber ID (most reliable)
    final itemBarberId = data['barberId'] ?? data['barberUid'];
    if (itemBarberId is String && itemBarberId == barberId) {
      return true;
    }

    // Check by barber name (case-insensitive)
    final itemBarberName =
        (data['barberName'] as String?) ?? (data['barber'] as String?);
    if (itemBarberName != null &&
        barberName.isNotEmpty &&
        itemBarberName.toLowerCase() == barberName.toLowerCase()) {
      return true;
    }

    // Check via salon barbers list (name to ID mapping)
    if (itemBarberName != null &&
        barberName.isNotEmpty &&
        nameToIdMap.containsKey(itemBarberName.toLowerCase()) &&
        nameToIdMap[itemBarberName.toLowerCase()] == barberId) {
      return true;
    }

    return false;
  }

  WorkHistoryItem? _mapItem(Map<String, dynamic> data, String barberId,
      String barberName, Map<String, String> nameToIdMap) {
    if (!_matchesBarber(data, barberId, barberName, nameToIdMap)) {
      return null;
    }

    // Prioritize completedAt for completed items
    DateTime time;
    if (data['completedAt'] != null && data['completedAt'] is Timestamp) {
      time = (data['completedAt'] as Timestamp).toDate();
    } else if (data['startedAt'] != null && data['startedAt'] is Timestamp) {
      time = (data['startedAt'] as Timestamp).toDate();
    } else {
      final ts = data['updatedAt'] ?? data['timestamp'] ?? data['time'];
      if (ts is Timestamp) {
        time = ts.toDate();
      } else {
        time = DateTime.now();
      }
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
