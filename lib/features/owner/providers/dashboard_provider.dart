import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  DashboardMetrics _metrics = DashboardMetrics.empty();
  List<ServicePerformance> _services = [];
  List<BarberPerformance> _barbers = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  DashboardMetrics get metrics => _metrics;
  List<ServicePerformance> get services => _services;
  List<BarberPerformance> get barbers => _barbers;

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final bookingsSnap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('bookings')
          .get();
      final queueSnap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('queue')
          .get();

      final bookings =
          bookingsSnap.docs.map((d) => _mapBooking(d.data())).toList();
      final queue = queueSnap.docs.map((d) => _mapQueue(d.data())).toList();

      _computeMetrics(bookings, queue);
      _services = _computeServicePerformance(bookings);
      _barbers = _computeBarberPerformance(queue);
    } catch (_) {
      _setError('Failed to load dashboard. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  OwnerBooking? _mapBooking(Map<String, dynamic> data) {
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
      id: (data['id'] as String?) ?? '',
      customerName: (data['customerName'] as String?) ?? 'Customer',
      customerAvatar: '',
      salonName: (data['salonName'] as String?) ?? '',
      service: (data['service'] as String?) ?? 'Service',
      price: (data['price'] as num?)?.toInt() ?? 0,
      dateTime: dateTime,
      status: status,
      paymentMethod: (data['paymentMethod'] as String?) ?? 'Cash',
    );
  }

  OwnerQueueItem _mapQueue(Map<String, dynamic> data) {
    final statusString = (data['status'] as String?) ?? 'waiting';
    final status = _queueStatusFromString(statusString);
    return OwnerQueueItem(
      id: (data['id'] as String?) ?? '',
      customerName: (data['customerName'] as String?) ?? 'Customer',
      service: (data['service'] as String?) ?? 'Service',
      barberName: (data['barberName'] as String?) ?? 'Barber',
      price: (data['price'] as num?)?.toInt() ?? 0,
      status: status,
      waitMinutes: (data['waitMinutes'] as num?)?.toInt() ?? 0,
      slotLabel: (data['slotLabel'] as String?) ?? '',
      customerPhone: (data['customerPhone'] as String?) ?? '',
      note: data['note'] as String?,
    );
  }

  void _computeMetrics(
      List<OwnerBooking?> bookings, List<OwnerQueueItem> queue) {
    final filtered = bookings.whereType<OwnerBooking>().toList();
    final totalBookings = filtered.length;
    final totalRevenue = filtered.fold<int>(0, (acc, b) => acc + b.price);
    final cancelled =
        filtered.where((b) => b.status == OwnerBookingStatus.cancelled).length;
    final uniqueCustomers = filtered.map((b) => b.customerName).toSet().length;
    final manualWalkIns =
        queue.where((q) => q.status == OwnerQueueStatus.waiting).length;
    final bookingsByHour = <int, int>{};
    for (final b in filtered) {
      final hour = b.dateTime.hour;
      bookingsByHour[hour] = (bookingsByHour[hour] ?? 0) + 1;
    }
    final peakHour = bookingsByHour.entries.isNotEmpty
        ? bookingsByHour.entries
            .reduce((a, b) => a.value >= b.value ? a : b)
            .key
        : null;
    final peakLabel = peakHour != null
        ? '${peakHour.toString().padLeft(2, '0')}:00 - ${((peakHour + 1) % 24).toString().padLeft(2, '0')}:00'
        : 'N/A';

    _metrics = DashboardMetrics(
      totalCustomers: uniqueCustomers,
      totalRevenue: totalRevenue,
      totalBookings: totalBookings,
      manualWalkIns: manualWalkIns,
      cancelledBookings: cancelled,
      newCustomers: uniqueCustomers, // placeholder
      returningCustomers: 0,
      peakHour: peakLabel,
    );
    notifyListeners();
  }

  List<ServicePerformance> _computeServicePerformance(
      List<OwnerBooking?> bookings) {
    final counts = <String, int>{};
    for (final b in bookings.whereType<OwnerBooking>()) {
      counts[b.service] = (counts[b.service] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => ServicePerformance(
              name: e.key,
              count: e.value,
              detail: '',
              icon: Icons.content_cut,
              accent: const Color(0xFF2563EB),
            ))
        .toList();
  }

  List<BarberPerformance> _computeBarberPerformance(
      List<OwnerQueueItem> queue) {
    final counts = <String, int>{};
    for (final q in queue) {
      counts[q.barberName] = (counts[q.barberName] ?? 0) + 1;
    }
    return counts.entries
        .map((e) => BarberPerformance(
              name: e.key,
              served: e.value,
              satisfaction: '—',
            ))
        .toList();
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

  OwnerQueueStatus _queueStatusFromString(String status) {
    switch (status) {
      case 'serving':
        return OwnerQueueStatus.serving;
      case 'done':
      case 'completed':
        return OwnerQueueStatus.done;
      default:
        return OwnerQueueStatus.waiting;
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

class DashboardMetrics {
  final int totalCustomers;
  final int totalRevenue;
  final int totalBookings;
  final int manualWalkIns;
  final int cancelledBookings;
  final int newCustomers;
  final int returningCustomers;
  final String peakHour;

  const DashboardMetrics({
    required this.totalCustomers,
    required this.totalRevenue,
    required this.totalBookings,
    required this.manualWalkIns,
    required this.cancelledBookings,
    required this.newCustomers,
    required this.returningCustomers,
    required this.peakHour,
  });

  factory DashboardMetrics.empty() => const DashboardMetrics(
        totalCustomers: 0,
        totalRevenue: 0,
        totalBookings: 0,
        manualWalkIns: 0,
        cancelledBookings: 0,
        newCustomers: 0,
        returningCustomers: 0,
        peakHour: 'N/A',
      );
}

class ServicePerformance {
  final String name;
  final int count;
  final String detail;
  final IconData icon;
  final Color accent;

  const ServicePerformance({
    required this.name,
    required this.count,
    required this.detail,
    required this.icon,
    required this.accent,
  });
}

class BarberPerformance {
  final String name;
  final int served;
  final String satisfaction;

  const BarberPerformance({
    required this.name,
    required this.served,
    required this.satisfaction,
  });
}
