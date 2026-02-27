import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/shared/services/firestore_cache.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  int get totalTips => _items.fold<int>(0, (acc, item) => acc + item.tipAmount);

  Future<void> load() async {
    final uid = _authProvider.currentUser?.uid;
    if (uid == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final userSnap = await FirestoreCache.getDocCacheFirst(
          _firestore.collection('users').doc(uid));
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
        final salonDoc = await FirestoreCache.getDocCacheFirst(
            _firestore.collection('salons').doc(ownerId));
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

      final bookingsRef =
          _firestore.collection('salons').doc(ownerId).collection('bookings');
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await FirestoreCache.getQuery(bookingsRef
            .where('barberId', isEqualTo: uid)
            .where('status', whereIn: ['completed', 'done'])
            .orderBy('dateTime', descending: true)
            .limit(200));
      } catch (_) {
        try {
          snap = await FirestoreCache.getQuery(bookingsRef
              .where('barberUid', isEqualTo: uid)
              .where('status', whereIn: ['completed', 'done'])
              .orderBy('dateTime', descending: true)
              .limit(200));
        } catch (_) {
          try {
            if (barberName.isNotEmpty) {
              snap = await FirestoreCache.getQuery(bookingsRef
                  .where('barberName', isEqualTo: barberName)
                  .where('status', whereIn: ['completed', 'done'])
                  .orderBy('dateTime', descending: true)
                  .limit(200));
            } else {
              snap = await FirestoreCache.getQuery(
                  bookingsRef.orderBy('dateTime', descending: true).limit(200));
            }
          } catch (_) {
            snap = await FirestoreCache.getQuery(
                bookingsRef.orderBy('dateTime', descending: true).limit(200));
          }
        }
      }

      _items = snap.docs
          .map((doc) => _mapItem(doc.data(), uid, barberName, nameToIdMap))
          .whereType<WorkHistoryItem>()
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

    final time = _parseBookingTime(data);

    final tipAmount = (data['tipAmount'] as num?)?.toInt() ?? 0;
    final total = (data['total'] as num?)?.toInt() ??
        (data['price'] as num?)?.toInt() ??
        0;
    final serviceCharge = (data['serviceCharge'] as num?)?.toInt() ?? 0;
    final basePrice =
        (data['price'] as num?)?.toInt() ?? (total - tipAmount - serviceCharge);

    return WorkHistoryItem(
      service: (data['service'] as String?) ?? 'Service',
      client: (data['customerName'] as String?) ?? 'Client',
      price: basePrice < 0 ? 0 : basePrice,
      total: total,
      tipAmount: tipAmount,
      status: (data['status'] as String?) ?? 'completed',
      time: time,
    );
  }

  DateTime _parseBookingTime(Map<String, dynamic> data) {
    final ts = data['completedAt'] ?? data['dateTime'] ?? data['createdAt'];
    if (ts is Timestamp) return ts.toDate();
    final dateStr = (data['date'] as String?) ?? '';
    final timeStr = (data['time'] as String?) ?? '';
    if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(dateStr);
        final parsedTime = DateFormat('h:mm a').parse(timeStr);
        return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
            parsedTime.hour, parsedTime.minute);
      } catch (_) {
        // fall through
      }
    }
    return DateTime.now();
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
  final int total;
  final int tipAmount;
  final String status;
  final DateTime time;

  const WorkHistoryItem({
    required this.service,
    required this.client,
    required this.price,
    required this.total,
    required this.tipAmount,
    required this.status,
    required this.time,
  });
}
