import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/dashboard_period.dart';
import 'package:cutline/features/owner/services/owner_queue_service.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
    OwnerQueueService? queueService,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _queueService = queueService ?? OwnerQueueService(firestore: firestore);

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  final OwnerQueueService _queueService;

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
    // Reload data when period changes
    load();
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
      final periodFilter = _getPeriodFilter(_period);
      final statsAggregate = await _loadStatsAggregate(ownerId, periodFilter);

      // Load bookings (period-filtered when possible)
      List<OwnerBooking> bookings = [];
      try {
        bookings = await _loadBookingsForPeriod(ownerId, periodFilter);
      } catch (e) {
        // Continue with empty bookings
      }

      // Load queue using OwnerQueueService (includes completed items)
      List<OwnerQueueItem> queue = [];
      try {
        queue = await _queueService.loadQueue(ownerId);
      } catch (e) {
        // Continue with empty queue
      }

      // Filter bookings and queue by selected period BEFORE computing metrics
      final filteredBookings = _filterBookingsByPeriod(bookings, periodFilter);
      final filteredQueue = _filterQueueByPeriod(queue, periodFilter);

      // Dashboard "Recent bookings" should reflect only completed bookings.
      _bookings = filteredBookings
          .where((b) => b.status == OwnerBookingStatus.completed)
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

      // Compute metrics and performance data using FILTERED data
      try {
        _computeMetrics(filteredBookings, filteredQueue, statsAggregate);
        _services = _computeServicePerformance(filteredBookings);
        _barbers = _computeBarberPerformance(filteredBookings);
        _bookingStatusCounts = _countBookings(filteredBookings);
        _queueStatusCounts = _countQueue(filteredQueue);
      } catch (e, stackTrace) {}

      notifyListeners();
    } catch (e, stackTrace) {
      String errorMessage = 'Failed to load dashboard. Pull to refresh.';
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
    } finally {
      _setLoading(false);
    }
  }

  OwnerBooking? _mapBooking(String id, Map<String, dynamic> data) {
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

      return OwnerBooking(
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
            '',
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
    } catch (e, stackTrace) {
      return null;
    }
  }

  /// Filter bookings by the selected period
  List<OwnerBooking> _filterBookingsByPeriod(
      List<OwnerBooking> bookings, PeriodFilter filter) {
    return bookings.where((booking) {
      return booking.dateTime.isAfter(filter.start) &&
          booking.dateTime.isBefore(filter.end);
    }).toList();
  }

  /// Filter queue items by the selected period
  /// Note: Active queue items (waiting/serving) are always shown as they represent current state
  /// Completed items are filtered - OwnerQueueService currently only loads today's completed items
  /// For other periods, completed queue items will be limited to today only
  List<OwnerQueueItem> _filterQueueByPeriod(
      List<OwnerQueueItem> queue, PeriodFilter filter) {
    // For active items (waiting/serving), always include them as they're current state
    // For completed items, OwnerQueueService._loadCompletedToday only loads today's items
    // So if period is today, include all completed items; otherwise, exclude them
    if (_period == DashboardPeriod.today) {
      return queue; // Include all items including today's completed
    } else {
      // For other periods, only show active queue items
      // (Completed items are only available for today due to service limitation)
      return queue
          .where((item) => item.status != OwnerQueueStatus.done)
          .toList();
    }
  }

  /// Get date range filter based on selected period
  PeriodFilter _getPeriodFilter(DashboardPeriod period) {
    final now = DateTime.now();
    DateTime start;
    DateTime end;

    switch (period) {
      case DashboardPeriod.today:
        start = DateTime(now.year, now.month, now.day);
        end = start.add(const Duration(days: 1));
        break;
      case DashboardPeriod.week:
        final weekday = now.weekday;
        start = DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: weekday - 1));
        end = start.add(const Duration(days: 7));
        break;
      case DashboardPeriod.month:
        start = DateTime(now.year, now.month, 1);
        end = DateTime(now.year, now.month + 1, 1);
        break;
      case DashboardPeriod.year:
        start = DateTime(now.year, 1, 1);
        end = DateTime(now.year + 1, 1, 1);
        break;
    }

    return PeriodFilter(start: start, end: end);
  }

  void _computeMetrics(
    List<OwnerBooking> bookings,
    List<OwnerQueueItem> queue,
    _StatsAggregate? stats,
  ) {
    final completedBookings = bookings
        .where((b) => b.status == OwnerBookingStatus.completed)
        .toList();
    final statsAvailable = stats != null && stats.hasData;
    final totalBookings =
        statsAvailable ? stats.completedBookings : completedBookings.length;
    final totalRevenue = statsAvailable
        ? stats.revenue
        : completedBookings.fold<int>(0, (acc, b) => acc + b.total);
    final totalTips = statsAvailable
        ? stats.tips
        : completedBookings.fold<int>(0, (acc, b) => acc + b.tipAmount);
    final totalPlatformFees = statsAvailable
        ? stats.serviceCharge
        : completedBookings.fold<int>(0, (acc, b) => acc + b.serviceCharge);
    final cancelled =
        bookings.where((b) => b.status == OwnerBookingStatus.cancelled).length;
    final uniqueCustomers = completedBookings
        .map((b) => b.customerUid.isNotEmpty ? b.customerUid : b.customerName)
        .toSet()
        .length;
    final manualWalkIns =
        queue.where((q) => q.status == OwnerQueueStatus.waiting).length;
    final bookingsByHour = <int, int>{};
    for (final b in completedBookings) {
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
      totalTips: totalTips,
      totalPlatformFees: totalPlatformFees,
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
    final completed =
        bookings.where((b) => b.status == OwnerBookingStatus.completed);
    final counts = <String, int>{};
    for (final b in completed) {
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
      List<OwnerBooking> bookings) {
    final counts = <String, int>{};
    final tips = <String, int>{};
    // Count completed bookings per barber
    for (final booking in bookings) {
      if (booking.status == OwnerBookingStatus.completed &&
          booking.barberName.isNotEmpty) {
        counts[booking.barberName] = (counts[booking.barberName] ?? 0) + 1;
        tips[booking.barberName] =
            (tips[booking.barberName] ?? 0) + booking.tipAmount;
      }
    }

    final barberList = counts.entries
        .map((e) => BarberPerformance(
              name: e.key,
              served: e.value,
              tipAmount: tips[e.key] ?? 0,
            ))
        .toList()
      ..sort((a, b) =>
          b.served.compareTo(a.served)); // Sort by served count descending

    return barberList;
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

  Future<_StatsAggregate> _loadStatsAggregate(
      String ownerId, PeriodFilter filter) async {
    final startKey = DateFormat('yyyy-MM-dd').format(filter.start);
    final endKey = DateFormat('yyyy-MM-dd').format(filter.end);
    try {
      final snap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('stats')
          .where('dateKey', isGreaterThanOrEqualTo: startKey)
          .where('dateKey', isLessThan: endKey)
          .get();

      int totalBookings = 0;
      int completedBookings = 0;
      int revenue = 0;
      int tips = 0;
      int serviceCharge = 0;

      for (final doc in snap.docs) {
        final data = doc.data();
        totalBookings += (data['totalBookings'] as num?)?.toInt() ?? 0;
        completedBookings += (data['completedBookings'] as num?)?.toInt() ?? 0;
        revenue += (data['revenue'] as num?)?.toInt() ?? 0;
        tips += (data['tips'] as num?)?.toInt() ?? 0;
        serviceCharge += (data['serviceCharge'] as num?)?.toInt() ?? 0;
      }

      return _StatsAggregate(
        totalBookings: totalBookings,
        completedBookings: completedBookings,
        revenue: revenue,
        tips: tips,
        serviceCharge: serviceCharge,
        hasData: snap.docs.isNotEmpty,
      );
    } catch (_) {
      return const _StatsAggregate.empty();
    }
  }

  Future<List<OwnerBooking>> _loadBookingsForPeriod(
      String ownerId, PeriodFilter filter) async {
    final collection =
        _firestore.collection('salons').doc(ownerId).collection('bookings');
    final startTs = Timestamp.fromDate(filter.start);
    final endTs = Timestamp.fromDate(filter.end);
    try {
      final snap = await collection
          .where('dateTime', isGreaterThanOrEqualTo: startTs)
          .where('dateTime', isLessThan: endTs)
          .get();
      return snap.docs
          .map((d) => _mapBooking(d.id, d.data()))
          .whereType<OwnerBooking>()
          .toList()
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    } catch (_) {
      final startKey = DateFormat('yyyy-MM-dd').format(filter.start);
      final endKey = DateFormat('yyyy-MM-dd').format(filter.end);
      try {
        final snap = await collection
            .where('date', isGreaterThanOrEqualTo: startKey)
            .where('date', isLessThan: endKey)
            .get();
        return snap.docs
            .map((d) => _mapBooking(d.id, d.data()))
            .whereType<OwnerBooking>()
            .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      } catch (_) {
        final snap = await collection
            .orderBy('dateTime', descending: true)
            .limit(200)
            .get();
        return snap.docs
            .map((d) => _mapBooking(d.id, d.data()))
            .whereType<OwnerBooking>()
            .toList()
          ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
      }
    }
  }
}

/// Helper class for period filtering
class PeriodFilter {
  final DateTime start;
  final DateTime end;

  PeriodFilter({required this.start, required this.end});
}

class DashboardMetrics {
  final int totalCustomers;
  final int totalRevenue;
  final int totalTips;
  final int totalPlatformFees;
  final int totalBookings;
  final int manualWalkIns;
  final int cancelledBookings;
  final int newCustomers;
  final int returningCustomers;
  final String peakHour;

  const DashboardMetrics({
    required this.totalCustomers,
    required this.totalRevenue,
    required this.totalTips,
    required this.totalPlatformFees,
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
        totalTips: 0,
        totalPlatformFees: 0,
        totalBookings: 0,
        manualWalkIns: 0,
        cancelledBookings: 0,
        newCustomers: 0,
        returningCustomers: 0,
        peakHour: 'N/A',
      );
}

class _StatsAggregate {
  final int totalBookings;
  final int completedBookings;
  final int revenue;
  final int tips;
  final int serviceCharge;
  final bool hasData;

  const _StatsAggregate({
    required this.totalBookings,
    required this.completedBookings,
    required this.revenue,
    required this.tips,
    required this.serviceCharge,
    required this.hasData,
  });

  const _StatsAggregate.empty()
      : totalBookings = 0,
        completedBookings = 0,
        revenue = 0,
        tips = 0,
        serviceCharge = 0,
        hasData = false;
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
  final int tipAmount;

  const BarberPerformance({
    required this.name,
    required this.served,
    required this.tipAmount,
  });
}
