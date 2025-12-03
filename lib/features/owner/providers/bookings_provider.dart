import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class BookingsProvider extends ChangeNotifier {
  BookingsProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

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
    _setLoading(true);
    _setError(null);
    try {
      final snap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('bookings')
          .orderBy('dateTime', descending: true)
          .get();
      _bookings = snap.docs
          .map((doc) => _mapBooking(doc.id, doc.data()))
          .whereType<OwnerBooking>()
          .toList();
    } catch (_) {
      // fallback to default mock if Firestore fails
      _bookings = List.of(kOwnerBookings);
      _setError('Showing cached data. Pull to refresh.');
    } finally {
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

  OwnerBooking? _mapBooking(String id, Map<String, dynamic> data) {
    final statusString = (data['status'] as String?) ?? 'upcoming';
    final status = _statusFromString(statusString);
    final ts = data['dateTime'];
    DateTime dateTime;
    if (ts is Timestamp) {
      dateTime = ts.toDate();
    } else {
      dateTime = DateTime.now();
    }
    return OwnerBooking(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      customerAvatar: (data['customerAvatar'] as String?) ?? '',
      salonName: (data['salonName'] as String?) ?? '',
      service: (data['service'] as String?) ?? 'Service',
      price: (data['price'] as num?)?.toInt() ?? 0,
      dateTime: dateTime,
      status: status,
      paymentMethod: (data['paymentMethod'] as String?) ?? 'Cash',
    );
  }

  OwnerBookingStatus _statusFromString(String status) {
    switch (status) {
      case 'completed':
        return OwnerBookingStatus.completed;
      case 'cancelled':
        return OwnerBookingStatus.cancelled;
      default:
        return OwnerBookingStatus.upcoming;
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
