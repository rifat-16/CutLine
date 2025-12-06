import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingsProvider extends ChangeNotifier {
  BookingsProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;

  bool _isLoading = false;
  String? _error;
  List<OwnerBooking> _bookings = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<OwnerBooking> get bookings => _bookings;

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    _subscription?.cancel();
    _setLoading(true);
    _setError(null);
    try {
      _subscription = _firestore
          .collectionGroup('bookings')
          .snapshots()
          .listen((snap) {
        final items = snap.docs
            .where((doc) {
              final parentId = doc.reference.parent.parent?.id;
              final data = doc.data();
              final salonId = (data['salonId'] as String?) ??
                  (data['salon'] as String?) ??
                  parentId;
              return salonId == ownerId;
            })
            .map((doc) => _mapBooking(
                  doc.id,
                  doc.data(),
                  doc.reference.parent.parent?.id,
                ))
            .whereType<OwnerBooking>()
            .toList();
        _bookings = items;
        notifyListeners();
        _setLoading(false);
      }, onError: (_) {
        _bookings = List.of(kOwnerBookings);
        _setError('Showing cached data. Pull to refresh.');
        _setLoading(false);
      });
    } catch (_) {
      _bookings = List.of(kOwnerBookings);
      _setError('Showing cached data. Pull to refresh.');
      _setLoading(false);
    }
  }

  Map<OwnerBookingStatus, List<OwnerBooking>> grouped() {
    final map = <OwnerBookingStatus, List<OwnerBooking>>{};
    for (final booking in _bookings) {
      map.putIfAbsent(booking.status, () => []).add(booking);
    }
    return map;
  }

  OwnerBooking? _mapBooking(
    String id,
    Map<String, dynamic> data,
    String? parentSalonId,
  ) {
    final statusString = (data['status'] as String?) ?? 'upcoming';
    final status = _statusFromString(statusString);
    final dateTime = _parseDateTime(data);
    if (dateTime == null) return null;
    final services = (data['services'] as List?)
            ?.map((e) =>
                (e is Map && e['name'] is String) ? e['name'] as String : '')
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    final serviceLabel =
        services.isNotEmpty ? services.join(', ') : (data['service'] as String?);
    return OwnerBooking(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      customerAvatar: (data['customerAvatar'] as String?) ?? '',
      salonName: (data['salonName'] as String?) ??
          (data['salon'] as String?) ??
          parentSalonId ??
          'Salon',
      service: serviceLabel ?? 'Service',
      price: (data['price'] as num?)?.toInt() ??
          (data['total'] as num?)?.toInt() ??
          0,
      dateTime: dateTime,
      status: status,
      paymentMethod: (data['paymentMethod'] as String?) ??
          (data['payment'] as String?) ??
          'Cash',
    );
  }

  OwnerBookingStatus _statusFromString(String status) {
    switch (status) {
      case 'waiting':
      case 'pending':
      case 'accepted':
        return OwnerBookingStatus.upcoming;
      case 'completed':
      case 'done':
        return OwnerBookingStatus.completed;
      case 'cancelled':
      case 'rejected':
        return OwnerBookingStatus.cancelled;
      default:
        return OwnerBookingStatus.upcoming;
    }
  }

  DateTime? _parseDateTime(Map<String, dynamic> data) {
    final ts = data['dateTime'];
    if (ts is Timestamp) return ts.toDate();
    final dateStr = (data['date'] as String?) ?? '';
    final timeStr = (data['time'] as String?) ?? '';
    if (dateStr.isEmpty || timeStr.isEmpty) return DateTime.now();
    try {
      final parsedDate = DateTime.parse(dateStr);
      final parsedTime = DateFormat('h:mm a').parse(timeStr);
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
          parsedTime.hour, parsedTime.minute);
    } catch (_) {
      return DateTime.now();
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
