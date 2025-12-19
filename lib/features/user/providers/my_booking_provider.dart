import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cutline/shared/services/booking_reminder_service.dart';

class MyBookingProvider extends ChangeNotifier {
  MyBookingProvider({
    required this.userId,
    this.userEmail = '',
    this.userPhone = '',
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String userId;
  final String userEmail;
  final String userPhone;
  final BookingReminderService _reminderService = BookingReminderService();

  bool _isLoading = false;
  String? _error;
  List<UserBooking> _upcoming = [];
  List<UserBooking> _completed = [];
  List<UserBooking> _cancelled = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserBooking> get upcoming => _upcoming;
  List<UserBooking> get completed => _completed;
  List<UserBooking> get cancelled => _cancelled;

  Future<void> load() async {
    if (userId.isEmpty) {
      _setError('Please sign in to view your bookings.');
      _upcoming = [];
      _completed = [];
      _cancelled = [];
      _setLoading(false);
      return;
    }

    _setLoading(true);
    _setError(null);
    try {
      await _loadWithFilter();
    } catch (e) {
      // fall back to client-side filter to avoid missing index issues
      try {
        await _loadWithFallback();
      } catch (e2) {
        _setError('Failed to load bookings. Pull to refresh.');
        _upcoming = [];
        _completed = [];
        _cancelled = [];
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> cancelBooking(UserBooking booking) async {
    _updateLocalStatus(booking.id, booking.salonId, 'cancelled');
    try {
      await _firestore
          .collection('salons')
          .doc(booking.salonId)
          .collection('bookings')
          .doc(booking.id)
          .set({'status': 'cancelled'}, SetOptions(merge: true));

      // Cancel the reminder notification for this booking
      await _reminderService.cancelReminder(booking.id);
    } catch (_) {
      _setError('Could not cancel booking.');
    }
  }

  UserBooking? _mapBooking(QueryDocumentSnapshot<Map<String, dynamic>> snapshot,
      Map<String, String?> coverCache) {
    try {
      final data = snapshot.data();
      final parent = snapshot.reference.parent.parent;
      final salonId = parent?.id ?? '';


      // Try multiple field names for customer UID
      final customerUid = (data['customerUid'] as String?)?.trim() ??
          (data['userId'] as String?)?.trim() ??
          (data['userUid'] as String?)?.trim() ??
          '';

      final dateStr = (data['date'] as String?)?.trim() ?? '';
      final timeStr = (data['time'] as String?)?.trim() ?? '';


      if (dateStr.isEmpty || timeStr.isEmpty) {
        return null;
      }

      final dateTime = _parseDateTime(dateStr, timeStr);
      if (dateTime == null) {
        return null;
      }

      final salonCover = (data['coverImageUrl'] as String?)?.trim() ??
          (data['coverPhoto'] as String?)?.trim() ??
          coverCache[salonId];

      final booking = UserBooking(
        id: snapshot.id,
        salonId: salonId,
        salonName: (data['salonName'] as String?)?.trim() ?? 'Salon',
        customerUid: customerUid,
        customerEmail: (data['customerEmail'] as String?)?.trim() ??
            (data['email'] as String?)?.trim() ??
            '',
        customerPhone: (data['customerPhone'] as String?)?.trim() ??
            (data['phone'] as String?)?.trim() ??
            '',
        coverImageUrl: salonCover,
        services: (data['services'] as List?)
                ?.map((e) {
                  if (e is Map && e['name'] is String) {
                    return (e['name'] as String).trim();
                  }
                  if (e is String) return e.trim();
                  return '';
                })
                .where((e) => e.isNotEmpty)
                .toList() ??
            const [],
        barberName: (data['barberName'] as String?)?.trim() ?? '',
        dateTime: dateTime,
        status: (data['status'] as String?)?.trim() ?? 'upcoming',
      );

      return booking;
    } catch (e, stackTrace) {
      return null;
    }
  }

  void _categorize(List<UserBooking> items) {
    final upcoming = <UserBooking>[];
    final completed = <UserBooking>[];
    final cancelled = <UserBooking>[];
    for (final item in items) {
      final status = item.status.toLowerCase();
      if (status == 'cancelled') {
        cancelled.add(item.copyWith(status: 'cancelled'));
      } else if (status == 'completed') {
        completed.add(item.copyWith(status: 'completed'));
      } else {
        upcoming.add(item.copyWith(status: 'upcoming'));
      }
    }
    _upcoming = upcoming..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    _completed = completed..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    _cancelled = cancelled..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    notifyListeners();
  }

  DateTime? _parseDateTime(String date, String time) {
    if (date.isEmpty || time.isEmpty) return null;
    try {
      final parsedDate = DateTime.parse(date);
      final parsedTime = DateFormat('h:mm a').parse(time);
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
          parsedTime.hour, parsedTime.minute);
    } catch (_) {
      return null;
    }
  }

  void _updateLocalStatus(String id, String salonId, String status) {
    void update(List<UserBooking> list) {
      final index = list.indexWhere((b) => b.id == id && b.salonId == salonId);
      if (index != -1) {
        list[index] = list[index].copyWith(status: status);
      }
    }

    update(_upcoming);
    update(_completed);
    update(_cancelled);
    _categorize([..._upcoming, ..._completed, ..._cancelled]);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  Future<void> _loadWithFilter() async {
    try {

      // Try customerUid first
      try {
        final snap = await _firestore
            .collectionGroup('bookings')
            .where('customerUid', isEqualTo: userId)
            .get();


        if (snap.docs.isNotEmpty) {
          final coverCache = await _loadCoverCache(snap.docs);

          final items = snap.docs
              .map((doc) => _mapBooking(doc, coverCache))
              .whereType<UserBooking>()
              .where(_isCurrentUser)
              .toList();

          _categorize(items);

          if (items.isEmpty) {
          }
          return;
        }
      } catch (e) {
      }

      // Fallback: try userId field
      try {
        final snap = await _firestore
            .collectionGroup('bookings')
            .where('userId', isEqualTo: userId)
            .get();


        final coverCache = await _loadCoverCache(snap.docs);
        final items = snap.docs
            .map((doc) => _mapBooking(doc, coverCache))
            .whereType<UserBooking>()
            .where(_isCurrentUser)
            .toList();

        _categorize(items);

        if (items.isEmpty) {
        }
        return;
      } catch (e) {
        rethrow;
      }
    } catch (e, stackTrace) {
      rethrow;
    }
  }

  Future<void> _loadWithFallback() async {
    try {

      // Method 1: Try collectionGroup without filter
      try {
        final snap = await _firestore.collectionGroup('bookings').get();


        final coverCache = await _loadCoverCache(snap.docs);

        final allItems = snap.docs
            .map((doc) => _mapBooking(doc, coverCache))
            .whereType<UserBooking>()
            .toList();


        final items = allItems.where(_isCurrentUser).toList();

        if (items.isNotEmpty) {
          _categorize(items);
          _setError(null);
          return;
        }
      } catch (e) {
      }

      // Method 2: Load all salons and query each salon's bookings individually
      try {
        final salonsSnap = await _firestore
            .collection('salons')
            .where('verificationStatus', isEqualTo: 'verified')
            .get();

        final allBookings = <UserBooking>[];
        final coverCache = <String, String?>{};

        // Load cover images
        for (final salonDoc in salonsSnap.docs) {
          final salonId = salonDoc.id;
          final salonData = salonDoc.data();
          coverCache[salonId] = (salonData['coverImageUrl'] as String?) ??
              (salonData['coverPhoto'] as String?);
        }


        // Query bookings from each salon
        for (final salonDoc in salonsSnap.docs) {
          try {
            final salonId = salonDoc.id;

            // Try with customerUid filter
            try {
              final bookingsSnap = await _firestore
                  .collection('salons')
                  .doc(salonId)
                  .collection('bookings')
                  .where('customerUid', isEqualTo: userId)
                  .get();


              for (final doc in bookingsSnap.docs) {
                final booking = _mapBooking(doc, coverCache);
                if (booking != null && _isCurrentUser(booking)) {
                  allBookings.add(booking);
                }
              }
            } catch (e) {
              // Try without filter
              try {
                final bookingsSnap = await _firestore
                    .collection('salons')
                    .doc(salonId)
                    .collection('bookings')
                    .get();


                for (final doc in bookingsSnap.docs) {
                  final booking = _mapBooking(doc, coverCache);
                  if (booking != null && _isCurrentUser(booking)) {
                    allBookings.add(booking);
                  }
                }
              } catch (e2) {
              }
            }
          } catch (e) {
            continue;
          }
        }


        if (allBookings.isNotEmpty) {
          _categorize(allBookings);
          _setError(null);
          return;
        }
      } catch (e) {
      }

      // If both methods fail
      _setError('No bookings found for this account.');
      _upcoming = [];
      _completed = [];
      _cancelled = [];
    } catch (e, stackTrace) {

      String errorMessage = 'Failed to load bookings. Pull to refresh.';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          errorMessage =
              'Permission denied. Please check Firestore rules are deployed.';
        } else if (e.code == 'unavailable') {
          errorMessage = 'Network error. Check your connection.';
        } else if (e.code == 'failed-precondition') {
          errorMessage =
              'Database query failed. Please ensure Firestore indexes are created.';
        } else {
          errorMessage = 'Firebase error: ${e.message ?? e.code}';
        }
      }

      _setError(errorMessage);
      _upcoming = [];
      _completed = [];
      _cancelled = [];
    }
  }

  bool _isCurrentUser(UserBooking booking) {
    if (booking.customerUid == userId) return true;
    if (userEmail.isNotEmpty &&
        booking.customerEmail.isNotEmpty &&
        booking.customerEmail.toLowerCase() == userEmail.toLowerCase()) {
      return true;
    }
    if (userPhone.isNotEmpty &&
        booking.customerPhone.isNotEmpty &&
        booking.customerPhone == userPhone) {
      return true;
    }
    return false;
  }

  Future<Map<String, String?>> _loadCoverCache(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final ids = docs
        .map((doc) => doc.reference.parent.parent?.id)
        .whereType<String>()
        .toSet()
        .toList();
    final Map<String, String?> cache = {};
    for (final id in ids) {
      try {
        final snap = await _firestore.collection('salons').doc(id).get();
        final data = snap.data();
        if (data != null) {
          cache[id] = (data['coverImageUrl'] as String?) ??
              (data['coverPhoto'] as String?);
        }
      } catch (_) {
        // ignore
      }
    }
    return cache;
  }
}

class UserBooking {
  final String id;
  final String salonId;
  final String salonName;
  final String customerUid;
  final String customerEmail;
  final String customerPhone;
  final String? coverImageUrl;
  final List<String> services;
  final String barberName;
  final DateTime dateTime;
  final String status;

  const UserBooking({
    required this.id,
    required this.salonId,
    required this.salonName,
    required this.customerUid,
    required this.customerEmail,
    required this.customerPhone,
    required this.coverImageUrl,
    required this.services,
    required this.barberName,
    required this.dateTime,
    required this.status,
  });

  String get dateLabel => DateFormat('EEE, dd MMM yyyy').format(dateTime);
  String get timeLabel => DateFormat('h:mm a').format(dateTime);

  UserBooking copyWith({String? status}) {
    return UserBooking(
      id: id,
      salonId: salonId,
      salonName: salonName,
      customerUid: customerUid,
      customerEmail: customerEmail,
      customerPhone: customerPhone,
      coverImageUrl: coverImageUrl,
      services: services,
      barberName: barberName,
      dateTime: dateTime,
      status: status ?? this.status,
    );
  }
}
