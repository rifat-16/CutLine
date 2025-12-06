import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/dashboard_period.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  List<OwnerBooking> _bookings = [];
  List<ServicePerformance> _services = [];
  List<BarberPerformance> _barbers = [];
  Map<OwnerBookingStatus, int> _bookingStatusCounts = const {};
  Map<OwnerQueueStatus, int> _queueStatusCounts = const {};
  DashboardPeriod _period = DashboardPeriod.today;

  bool get isLoading => _isLoading;
  String? get error => _error;
  DashboardMetrics get metrics => _metrics;
  List<OwnerBooking> get bookings => _bookings;
  List<ServicePerformance> get services => _services;
  List<BarberPerformance> get barbers => _barbers;
  Map<OwnerBookingStatus, int> get bookingStatusCounts => _bookingStatusCounts;
  Map<OwnerQueueStatus, int> get queueStatusCounts => _queueStatusCounts;
  DashboardPeriod get period => _period;

  void setPeriod(DashboardPeriod period) {
    if (_period == period) return;
    _period = period;
    notifyListeners();
  }

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

      final bookings = bookingsSnap.docs
          .map((d) => _mapBooking(d.id, d.data()))
          .whereType<OwnerBooking>()
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      final queue = queueSnap.docs.map((d) => _mapQueue(d.data())).toList();

      _bookings = bookings;
      _computeMetrics(bookings, queue);
      _services = _computeServicePerformance(bookings);
      _barbers = _computeBarberPerformance(queue);
      _bookingStatusCounts = _countBookings(bookings);
      _queueStatusCounts = _countQueue(queue);
      notifyListeners();
    } catch (_) {
      _setError('Failed to load dashboard. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  OwnerBooking? _mapBooking(String id, Map<String, dynamic> data) {
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
      customerAvatar: '',
      salonName: (data['salonName'] as String?) ??
          (data['salon'] as String?) ??
          '',
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
      List<OwnerBooking> bookings, List<OwnerQueueItem> queue) {
    final totalBookings = bookings.length;
    final totalRevenue = bookings.fold<int>(0, (acc, b) => acc + b.price);
    final cancelled =
        bookings.where((b) => b.status == OwnerBookingStatus.cancelled).length;
    final uniqueCustomers = bookings.map((b) => b.customerName).toSet().length;
    final manualWalkIns =
        queue.where((q) => q.status == OwnerQueueStatus.waiting).length;
    final bookingsByHour = <int, int>{};
    for (final b in bookings) {
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

  Map<OwnerBookingStatus, int> _countBookings(List<OwnerBooking> bookings) {
    final map = <OwnerBookingStatus, int>{
      OwnerBookingStatus.upcoming: 0,
      OwnerBookingStatus.completed: 0,
      OwnerBookingStatus.cancelled: 0,
    };
    for (final booking in bookings) {
      map[booking.status] = (map[booking.status] ?? 0) + 1;
    }
    return map;
  }

  Map<OwnerQueueStatus, int> _countQueue(List<OwnerQueueItem> queue) {
    final map = <OwnerQueueStatus, int>{
      OwnerQueueStatus.waiting: 0,
      OwnerQueueStatus.serving: 0,
      OwnerQueueStatus.done: 0,
    };
    for (final item in queue) {
      map[item.status] = (map[item.status] ?? 0) + 1;
    }
    return map;
  }

  List<ServicePerformance> _computeServicePerformance(
      List<OwnerBooking> bookings) {
    final counts = <String, int>{};
    for (final b in bookings) {
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
