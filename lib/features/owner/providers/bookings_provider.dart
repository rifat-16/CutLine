import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'dart:async';
import 'package:flutter/foundation.dart';
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

  Future<void> _hydrateCustomerAvatars() async {
    final bookingsNeedingAvatars = _bookings
        .where((b) => b.customerAvatar.isEmpty && b.customerUid.isNotEmpty)
        .toList();
    if (bookingsNeedingAvatars.isEmpty) return;

    final batchSize = 10;
    for (int i = 0; i < bookingsNeedingAvatars.length; i += batchSize) {
      final batch = bookingsNeedingAvatars.skip(i).take(batchSize).toList();
      final uids = batch.map((b) => b.customerUid).toList();

      try {
        final snap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: uids)
            .get();

        final avatarMap = <String, String>{};
        for (final doc in snap.docs) {
          final data = doc.data();
          final photoUrl = (data['photoUrl'] as String?) ??
              (data['avatarUrl'] as String?) ??
              (data['customerAvatar'] as String?) ??
              '';
          if (photoUrl.isNotEmpty) {
            avatarMap[doc.id] = photoUrl;
          }
        }

        for (int j = 0; j < batch.length; j++) {
          final booking = batch[j];
          final avatar = avatarMap[booking.customerUid];
          if (avatar != null && avatar.isNotEmpty) {
            final index = _bookings.indexWhere((b) => b.id == booking.id);
            if (index != -1) {
              _bookings[index] = OwnerBooking(
                id: _bookings[index].id,
                customerName: _bookings[index].customerName,
                customerAvatar: avatar,
                customerUid: _bookings[index].customerUid,
                salonName: _bookings[index].salonName,
                service: _bookings[index].service,
                price: _bookings[index].price,
                serviceCharge: _bookings[index].serviceCharge,
                tipAmount: _bookings[index].tipAmount,
                total: _bookings[index].total,
                dateTime: _bookings[index].dateTime,
                status: _bookings[index].status,
                paymentMethod: _bookings[index].paymentMethod,
                barberName: _bookings[index].barberName,
              );
            }
          }
        }
      } catch (_) {
        // Ignore errors in avatar fetching
      }
    }
    notifyListeners();
  }

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
      await _loadFromSalonCollection(ownerId);
    } catch (e, stackTrace) {
      _bookings = [];
      String errorMessage = 'Failed to load bookings. Pull to refresh.';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          errorMessage =
              'Permission denied. Please check Firestore rules are deployed.';
        } else if (e.code == 'unavailable') {
          errorMessage = 'Network error. Check your connection.';
        } else {
          errorMessage = 'Firebase error: ${e.message ?? e.code}';
        }
      }
      _setError(errorMessage);
      _setLoading(false);
    }
  }

  Future<void> _loadFromSalonCollection(String ownerId) async {
    try {
      _subscription?.cancel();

      _subscription = _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('bookings')
          .snapshots()
          .listen((snap) {
        final items = snap.docs
            .map((doc) => _mapBooking(
                  doc.id,
                  doc.data(),
                  ownerId,
                ))
            .whereType<OwnerBooking>()
            .toList();

        _bookings = items;
        _hydrateCustomerAvatars();
        notifyListeners();
        _setLoading(false);
      }, onError: (e) {
        _bookings = [];
        String errorMessage = 'Failed to load bookings. Pull to refresh.';
        if (e is FirebaseException) {
          if (e.code == 'permission-denied') {
            errorMessage =
                'Permission denied. Please check Firestore rules are deployed.';
          } else if (e.code == 'unavailable') {
            errorMessage = 'Network error. Check your connection.';
          } else {
            errorMessage = 'Firebase error: ${e.message ?? e.code}';
          }
        }
        _setError(errorMessage);
        _setLoading(false);
      });
    } catch (e, stackTrace) {
      _bookings = [];
      _setError('Failed to load bookings. Pull to refresh.');
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
    try {
      final statusString = (data['status'] as String?)?.trim() ?? 'upcoming';
      final status = _statusFromString(statusString);

      final dateTime = _parseDateTime(data);
      if (dateTime == null) {
        return null;
      }

      final services = (data['services'] as List?)
              ?.map((e) {
                if (e is Map && e['name'] is String) {
                  return (e['name'] as String).trim();
                }
                if (e is String) return e.trim();
                return '';
              })
              .whereType<String>()
              .where((e) => e.isNotEmpty)
              .toList() ??
          const [];

      final serviceLabel = services.isNotEmpty
          ? services.join(', ')
          : (data['service'] as String?)?.trim();

      final tipAmount = (data['tipAmount'] as num?)?.toInt() ?? 0;
      final serviceCharge = (data['serviceCharge'] as num?)?.toInt() ?? 0;
      final totalAmount = (data['total'] as num?)?.toInt() ??
          (data['price'] as num?)?.toInt() ??
          0;
      final basePrice = (data['price'] as num?)?.toInt() ??
          (totalAmount - tipAmount - serviceCharge);

      final booking = OwnerBooking(
        id: id,
        customerName: (data['customerName'] as String?)?.trim() ?? 'Customer',
        customerAvatar: (data['customerAvatar'] as String?)?.trim() ??
            (data['customerPhotoUrl'] as String?)?.trim() ??
            (data['photoUrl'] as String?)?.trim() ??
            '',
        customerUid: (data['customerUid'] as String?)?.trim() ??
            (data['customerId'] as String?)?.trim() ??
            (data['userId'] as String?)?.trim() ??
            (data['uid'] as String?)?.trim() ??
            '',
        salonName: (data['salonName'] as String?)?.trim() ??
            (data['salon'] as String?)?.trim() ??
            parentSalonId ??
            'Salon',
        service: serviceLabel ?? 'Service',
        price: basePrice < 0 ? 0 : basePrice,
        serviceCharge: serviceCharge,
        tipAmount: tipAmount,
        total: totalAmount,
        dateTime: dateTime,
        status: status,
        paymentMethod: (data['paymentMethod'] as String?)?.trim() ??
            (data['payment'] as String?)?.trim() ??
            'Cash',
        barberName: (data['barberName'] as String?)?.trim() ?? '',
      );

      return booking;
    } catch (e, stackTrace) {
      return null;
    }
  }

  OwnerBookingStatus _statusFromString(String status) {
    switch (status) {
      case 'waiting':
      case 'arrived':
      case 'serving':
      case 'pending':
      case 'accepted':
        return OwnerBookingStatus.upcoming;
      case 'completed':
      case 'done':
        return OwnerBookingStatus.completed;
      case 'cancelled':
      case 'canceled':
      case 'no_show':
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
