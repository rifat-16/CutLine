import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cutline/shared/services/firestore_cache.dart';
import 'package:cutline/shared/services/local_ttl_cache.dart';

class BookingProvider extends ChangeNotifier {
  BookingProvider({
    required this.salonId,
    required this.salonName,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String salonId;
  final String salonName;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  List<BookingService> _services = [];
  List<BookingBarber> _barbers = [];
  List<String> _bookedSlots = [];
  int _currentWaiting = 0;
  String _address = '';
  double _rating = 4.6;
  String _workingHoursLabel = '9:00 AM - 9:00 PM';
  Map<String, dynamic> _workingHours = {};
  String? _coverImageUrl;
  List<String> _timeSlots = [];
  bool _isSalonOpen = false;
  Map<String, BarberQueueInsight> _queueInsights = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<BookingService> get services => _services;
  List<BookingBarber> get barbers => _barbers;
  List<String> get bookedSlots => _bookedSlots;
  List<String> get timeSlots => _timeSlots;
  bool isClosedOn(DateTime date) => _isDayClosed(date);
  int get currentWaiting => _currentWaiting;
  String get address => _address;
  double get rating => _rating;
  String get workingHoursLabel => _workingHoursLabel;
  String? get coverImageUrl => _coverImageUrl;
  bool get isSalonOpen => _isSalonOpen;

  Future<void> loadInitial(DateTime date) async {
    _setLoading(true);
    _setError(null);
    try {
      await _loadSalon();
      _updateTimeSlotsForDate(date, notify: false);
      await loadBookedSlots(date);
    } catch (_) {
      _setError('Could not load booking data.');
    } finally {
      _setLoading(false);
    }
  }

  BarberQueueInsight queueInsightForBarber({
    required String barberId,
    required String barberName,
  }) {
    final byId = _queueInsights[_insightKeyById(barberId)];
    if (byId != null) return byId;
    final byName = _queueInsights[_insightKeyByName(barberName)];
    if (byName != null) return byName;
    return BarberQueueInsight(
      barberId: barberId,
      barberName: barberName,
      waitingCount: 0,
      activeCount: 0,
      aheadWaitMinutes: 0,
      maxSerialNo: 0,
      nextSerial: 1,
    );
  }

  DateTime estimatedStartForBarber({
    required String barberId,
    required String barberName,
  }) {
    final insight = queueInsightForBarber(
      barberId: barberId,
      barberName: barberName,
    );
    return DateTime.now().add(Duration(minutes: insight.aheadWaitMinutes));
  }

  Future<void> refreshQueueInsights() async {
    await _loadQueueInsights();
    notifyListeners();
  }

  Future<void> loadBookedSlots(DateTime date, {String? barberName}) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    try {
      final normalizedBarber = barberName?.trim().toLowerCase();
      if (normalizedBarber == null || normalizedBarber.isEmpty) {
        _bookedSlots = [];
        notifyListeners();
        return;
      }

      final snap = await FirestoreCache.getQuery(_firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .where('date', isEqualTo: formattedDate));
      final slots = <String>{};
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] as String?)?.trim().toLowerCase() ?? '';
        // Cancelled/no-show bookings shouldn't block availability.
        if (status == 'cancelled' ||
            status == 'canceled' ||
            status == 'no_show' ||
            status == 'rejected') {
          continue;
        }

        final bookingBarber =
            (data['barberName'] as String?)?.trim().toLowerCase() ?? '';
        if (bookingBarber != normalizedBarber) continue;

        final slot = ((data['time'] as String?) ??
                (data['bookingTime'] as String?) ??
                (data['slotLabel'] as String?) ??
                '')
            .trim();
        if (slot.isNotEmpty) slots.add(slot);
      }
      _bookedSlots = slots.toList();
    } catch (_) {
      _bookedSlots = [];
    }
    notifyListeners();
  }

  Future<void> _loadSalon() async {
    try {
      final doc = await FirestoreCache.getDocCacheFirst(
        _firestore.collection('salons').doc(salonId),
      );
      final data = doc.data() ?? {};
      _services = await _loadServices();
      _barbers = await _loadBarbers(data);
      await _loadQueueInsights();
      _currentWaiting = await _estimateWaiting();
      _address = (data['address'] as String?) ?? '';
      _rating = (data['rating'] as num?)?.toDouble() ?? 4.6;
      _workingHours = _normalizeWorkingHours(data['workingHours']);
      _workingHoursLabel = _formatWorkingHours(_workingHours);
      _isSalonOpen = (data['isOpen'] as bool?) ?? false;
      _coverImageUrl =
          (data['coverImageUrl'] as String?) ?? (data['coverPhoto'] as String?);
    } catch (_) {
      _services = [];
      _barbers = [];
      _currentWaiting = 0;
      _isSalonOpen = false;
      _queueInsights = {};
    }
  }

  Future<List<BookingService>> _loadServices() async {
    try {
      final cached =
          await LocalTtlCache.get<List<dynamic>>('booking_services:$salonId');
      if (cached != null && cached.isNotEmpty) {
        return cached
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .map((map) => BookingService(
                  name: (map['name'] as String?) ?? 'Service',
                  price: (map['price'] as num?)?.toInt() ?? 0,
                  durationMinutes:
                      (map['durationMinutes'] as num?)?.toInt() ?? 30,
                ))
            .toList();
      }
      final query = _firestore
          .collection('salons')
          .doc(salonId)
          .collection('all_services')
          .orderBy('order');
      final snap = await FirestoreCache.getQueryCacheFirst(query);
      final services = snap.docs.map((doc) {
        final map = doc.data();
        return BookingService(
          name: (map['name'] as String?) ?? 'Service',
          price: (map['price'] as num?)?.toInt() ?? 0,
          durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
        );
      }).toList();
      if (services.isNotEmpty) {
        await LocalTtlCache.set(
          'booking_services:$salonId',
          services.map((s) {
            return {
              'name': s.name,
              'price': s.price,
              'durationMinutes': s.durationMinutes,
            };
          }).toList(),
          const Duration(hours: 24),
        );
      }
      if (services.isNotEmpty) return services;
    } catch (_) {
      // fall through to fallback
    }
    try {
      final snap = await FirestoreCache.getQueryCacheFirst(_firestore
          .collection('salons')
          .doc(salonId)
          .collection('all_services'));
      final services = snap.docs.map((doc) {
        final map = doc.data();
        return BookingService(
          name: (map['name'] as String?) ?? 'Service',
          price: (map['price'] as num?)?.toInt() ?? 0,
          durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 30,
        );
      }).toList();
      if (services.isNotEmpty) {
        await LocalTtlCache.set(
          'booking_services:$salonId',
          services.map((s) {
            return {
              'name': s.name,
              'price': s.price,
              'durationMinutes': s.durationMinutes,
            };
          }).toList(),
          const Duration(hours: 24),
        );
      }
      return services;
    } catch (_) {
      return [];
    }
  }

  Future<List<BookingBarber>> _loadBarbers(
      Map<String, dynamic> salonData) async {
    List<BookingBarber> cachedBarbers = const [];
    try {
      final cached =
          await LocalTtlCache.get<List<dynamic>>('booking_barbers:$salonId');
      if (cached != null && cached.isNotEmpty) {
        cachedBarbers = cached
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .map((data) => BookingBarber(
                  id: (data['id'] as String?) ?? '',
                  name: (data['name'] as String?) ?? 'Barber',
                  rating: (data['rating'] as num?)?.toDouble() ?? 4.8,
                  avatarUrl: (data['avatarUrl'] as String?),
                  uid: (data['uid'] as String?) ?? '',
                  isAvailable: (data['isAvailable'] as bool?) ?? true,
                  waitingClients:
                      (data['waitingClients'] as num?)?.toInt() ?? 0,
                ))
            .toList();
      }
    } catch (_) {
      cachedBarbers = const [];
    }

    try {
      final snap = await FirestoreCache.getQueryCacheFirst(
          _firestore.collection('salons').doc(salonId).collection('barbers'));
      final barbers = snap.docs.map((doc) {
        final data = doc.data();
        return BookingBarber(
          id: doc.id,
          name: (data['name'] as String?) ?? 'Barber',
          rating: (data['rating'] as num?)?.toDouble() ?? 4.8,
          avatarUrl:
              (data['avatarUrl'] as String?) ?? (data['photoUrl'] as String?),
          uid: (data['uid'] as String?) ?? doc.id,
          isAvailable: (data['isAvailable'] as bool?) ??
              (data['available'] as bool?) ??
              true,
          waitingClients: (data['waitingClients'] as num?)?.toInt() ??
              (data['waiting'] as num?)?.toInt() ??
              0,
        );
      }).toList();

      // Hydrate avatars from users collection if needed
      final hydratedBarbers = await _hydrateBarberAvatars(barbers);
      List<BookingBarber> hydratedEmbedded = const [];
      final embedded = salonData['barbers'];
      if (embedded is List) {
        final embeddedBarbers = embedded
            .whereType<Map>()
            .map((e) => BookingBarber(
                  id: (e['uid'] as String?) ?? '',
                  name: (e['name'] as String?) ?? 'Barber',
                  rating: (e['rating'] as num?)?.toDouble() ?? 4.8,
                  avatarUrl:
                      (e['avatarUrl'] as String?) ?? (e['photoUrl'] as String?),
                  uid: (e['uid'] as String?) ?? '',
                  isAvailable: (e['isAvailable'] as bool?) ??
                      (e['available'] as bool?) ??
                      true,
                  waitingClients: (e['waitingClients'] as num?)?.toInt() ??
                      (e['waiting'] as num?)?.toInt() ??
                      0,
                ))
            .toList();
        hydratedEmbedded = await _hydrateBarberAvatars(embeddedBarbers);
      }

      final merged = _mergeBarberSources(hydratedBarbers, hydratedEmbedded);
      if (merged.isNotEmpty) {
        await LocalTtlCache.set(
          'booking_barbers:$salonId',
          merged
              .map((b) => {
                    'id': b.id,
                    'uid': b.uid,
                    'name': b.name,
                    'rating': b.rating,
                    'avatarUrl': b.avatarUrl,
                    'isAvailable': b.isAvailable,
                    'waitingClients': b.waitingClients,
                  })
              .toList(),
          const Duration(hours: 6),
        );
        return merged;
      }
      if (cachedBarbers.isNotEmpty) {
        return cachedBarbers;
      }
      return const [];
    } catch (_) {
      if (cachedBarbers.isNotEmpty) {
        return cachedBarbers;
      }
      return [];
    }
  }

  Future<List<BookingBarber>> _hydrateBarberAvatars(
      List<BookingBarber> barbers) async {
    final missing = barbers
        .where((b) =>
            (b.avatarUrl == null || b.avatarUrl!.isEmpty) && b.uid.isNotEmpty)
        .map((b) => b.uid)
        .toSet()
        .toList();
    if (missing.isEmpty) return barbers;

    final avatarMap = <String, String>{};
    const int chunkSize = 10;
    for (var i = 0; i < missing.length; i += chunkSize) {
      final chunk = missing.skip(i).take(chunkSize).toList();
      try {
        final snap = await FirestoreCache.getQueryCacheFirst(_firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk));
        for (final doc in snap.docs) {
          final data = doc.data();
          final url =
              (data['photoUrl'] as String?) ?? (data['avatarUrl'] as String?);
          if (url != null && url.isNotEmpty) {
            avatarMap[doc.id] = url;
          }
        }
      } catch (_) {
        // Ignore errors
      }
    }

    // Return updated barbers with fetched avatars
    return barbers.map((barber) {
      if (barber.avatarUrl == null || barber.avatarUrl!.isEmpty) {
        final url = avatarMap[barber.uid];
        if (url != null && url.isNotEmpty) {
          return BookingBarber(
            id: barber.id,
            name: barber.name,
            rating: barber.rating,
            avatarUrl: url,
            uid: barber.uid,
            isAvailable: barber.isAvailable,
            waitingClients: barber.waitingClients,
          );
        }
      }
      return barber;
    }).toList();
  }

  List<BookingBarber> _mergeBarberSources(
    List<BookingBarber> primary,
    List<BookingBarber> secondary,
  ) {
    final merged = <String, BookingBarber>{};
    for (final barber in [...primary, ...secondary]) {
      final key = _barberMergeKey(barber);
      final existing = merged[key];
      if (existing == null) {
        merged[key] = barber;
        continue;
      }
      if ((existing.avatarUrl == null || existing.avatarUrl!.isEmpty) &&
          barber.avatarUrl != null &&
          barber.avatarUrl!.isNotEmpty) {
        merged[key] = BookingBarber(
          id: existing.id,
          name: existing.name,
          rating: existing.rating,
          avatarUrl: barber.avatarUrl,
          uid: existing.uid,
          isAvailable: existing.isAvailable,
          waitingClients: existing.waitingClients,
        );
      }
    }
    return merged.values.toList();
  }

  String _barberMergeKey(BookingBarber barber) {
    final uid = barber.uid.trim().toLowerCase();
    if (uid.isNotEmpty) return 'uid:$uid';
    final id = barber.id.trim().toLowerCase();
    if (id.isNotEmpty) return 'id:$id';
    return 'name:${barber.name.trim().toLowerCase()}';
  }

  Future<void> _loadQueueInsights() async {
    const activeStatuses = ['serving', 'waiting', 'arrived'];
    QuerySnapshot<Map<String, dynamic>>? snapshot;
    try {
      snapshot = await FirestoreCache.getQuery(_firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .where('status', whereIn: activeStatuses)
          .limit(400));
    } catch (_) {
      try {
        snapshot = await FirestoreCache.getQuery(_firestore
            .collection('salons')
            .doc(salonId)
            .collection('queue')
            .limit(600));
      } catch (_) {
        snapshot = null;
      }
    }

    if (snapshot == null) {
      _queueInsights = {};
      return;
    }

    final map = <String, _InsightAccumulator>{};
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] as String?)?.trim().toLowerCase() ?? '';
      if (!activeStatuses.contains(status)) continue;

      final barberId = ((data['barberId'] as String?) ??
              (data['barberUid'] as String?) ??
              '')
          .trim();
      final barberName =
          ((data['barberName'] as String?) ?? (data['barber'] as String?) ?? '')
              .trim();
      final serialBarberKey =
          (data['serialBarberKey'] as String?)?.trim().toLowerCase() ?? '';

      final key = barberId.isNotEmpty
          ? _insightKeyById(barberId)
          : (barberName.isNotEmpty
              ? _insightKeyByName(barberName)
              : (serialBarberKey.isNotEmpty ? 'id:$serialBarberKey' : ''));
      if (key.isEmpty) continue;

      final accumulator = map.putIfAbsent(
        key,
        () => _InsightAccumulator(
          barberId: barberId,
          barberName: barberName,
        ),
      );
      if (accumulator.barberId.isEmpty && barberId.isNotEmpty) {
        accumulator.barberId = barberId;
      }
      if (accumulator.barberName.isEmpty && barberName.isNotEmpty) {
        accumulator.barberName = barberName;
      }

      accumulator.activeCount += 1;
      if (status == 'waiting' || status == 'arrived') {
        accumulator.waitingCount += 1;
      }
      final wait = (data['waitMinutes'] as num?)?.toInt() ?? 0;
      accumulator.aheadWaitMinutes += wait > 0 ? wait : 30;
      final serialNo = (data['serialNo'] as num?)?.toInt() ?? 0;
      if (serialNo > accumulator.maxSerialNo) {
        accumulator.maxSerialNo = serialNo;
      }
    }

    _queueInsights = {
      for (final entry in map.entries)
        entry.key: BarberQueueInsight(
          barberId: entry.value.barberId,
          barberName: entry.value.barberName,
          waitingCount: entry.value.waitingCount,
          activeCount: entry.value.activeCount,
          aheadWaitMinutes: entry.value.aheadWaitMinutes,
          maxSerialNo: entry.value.maxSerialNo,
          nextSerial: entry.value.maxSerialNo > 0
              ? entry.value.maxSerialNo + 1
              : entry.value.activeCount + 1,
        ),
    };
    _barbers = _barbers.map(_withInsightWaitingCount).toList();
  }

  BookingBarber _withInsightWaitingCount(BookingBarber barber) {
    final insight = queueInsightForBarber(
      barberId: barber.uid,
      barberName: barber.name,
    );
    return BookingBarber(
      id: barber.id,
      name: barber.name,
      rating: barber.rating,
      avatarUrl: barber.avatarUrl,
      uid: barber.uid,
      isAvailable: barber.isAvailable,
      waitingClients: insight.waitingCount,
    );
  }

  String _insightKeyById(String barberId) {
    final normalized = barberId.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    return 'id:$normalized';
  }

  String _insightKeyByName(String barberName) {
    final normalized = barberName.trim().toLowerCase();
    if (normalized.isEmpty) return '';
    return 'name:$normalized';
  }

  Future<int> _estimateWaiting() async {
    try {
      final doc = await FirestoreCache.getDocCacheFirst(
        _firestore.collection('salons_summary').doc(salonId),
      );
      final data = doc.data();
      final value = data?['avgWaitMinutes'];
      if (value is num) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    } catch (_) {
      return 0;
    }
  }

  String _formatWorkingHours(dynamic workingHours) {
    if (workingHours is Map<String, dynamic>) {
      final today = DateFormat('EEEE').format(DateTime.now());
      final entry = workingHours[today];
      if (entry is Map<String, dynamic>) {
        final open = entry['open'] == true;
        if (!open) return 'Closed today';
        final openTime = entry['openTime'] as String? ?? '09:00';
        final closeTime = entry['closeTime'] as String? ?? '21:00';
        return '${_formatTime(openTime)} - ${_formatTime(closeTime)}';
      }
    }
    return '9:00 AM - 9:00 PM';
  }

  Map<String, dynamic> _normalizeWorkingHours(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    return {};
  }

  String _formatTime(String value) {
    try {
      final parts = value.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(2024, 1, 1, hour, minute);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return value;
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

  void updateTimeSlotsForDate(DateTime date) {
    _updateTimeSlotsForDate(date);
  }

  void _updateTimeSlotsForDate(DateTime date, {bool notify = true}) {
    final generated = _buildSlotsForDate(date);
    final hasWorkingHours = _workingHours.isNotEmpty;
    _timeSlots = generated.isNotEmpty
        ? generated
        : (hasWorkingHours ? [] : _defaultSlots);
    if (notify) notifyListeners();
  }

  List<String> _buildSlotsForDate(DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    final entry = _workingHours[dayName];
    if (entry is! Map<String, dynamic>) return [];
    final isOpen = entry['open'] != false;
    if (!isOpen) return [];

    final openTime = _parseTimeOfDay(entry['openTime'] as String? ?? '09:00');
    final closeTime = _parseTimeOfDay(entry['closeTime'] as String? ?? '21:00');
    if (openTime == null || closeTime == null) return [];

    final start = DateTime(
      date.year,
      date.month,
      date.day,
      openTime.hour,
      openTime.minute,
    );
    final lastStart = DateTime(
      date.year,
      date.month,
      date.day,
      closeTime.hour,
      closeTime.minute,
    ).subtract(const Duration(minutes: 30));

    if (lastStart.isBefore(start)) return [];

    final slots = <String>[];
    var current = start;
    final formatter = DateFormat('h:mm a');
    while (!current.isAfter(lastStart)) {
      slots.add(formatter.format(current));
      current = current.add(const Duration(minutes: 30));
    }
    return slots;
  }

  DateTime? _parseTimeOfDay(String value) {
    final trimmed = value.trim();
    try {
      if (trimmed.toLowerCase().contains('am') ||
          trimmed.toLowerCase().contains('pm')) {
        return DateFormat('h:mm a').parse(trimmed);
      }
      final parts = trimmed.split(':');
      if (parts.length < 2) return null;
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      return DateTime(0, 1, 1, hour, minute);
    } catch (_) {
      return null;
    }
  }

  bool _isDayClosed(DateTime date) {
    final dayName = DateFormat('EEEE').format(date);
    final entry = _workingHours[dayName];
    if (entry is! Map<String, dynamic>) return false;
    return entry['open'] == false;
  }

  static const List<String> _defaultSlots = [
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '1:00 PM',
    '1:30 PM',
    '2:00 PM',
    '2:30 PM',
    '3:00 PM',
    '3:30 PM',
    '4:00 PM',
    '4:30 PM',
    '5:00 PM',
    '5:30 PM',
    '6:00 PM',
    '6:30 PM',
    '7:00 PM',
    '7:30 PM',
  ];
}

class BookingService {
  final String name;
  final int price;
  final int durationMinutes;

  const BookingService({
    required this.name,
    required this.price,
    this.durationMinutes = 30,
  });
}

class BarberQueueInsight {
  final String barberId;
  final String barberName;
  final int waitingCount;
  final int activeCount;
  final int aheadWaitMinutes;
  final int maxSerialNo;
  final int nextSerial;

  const BarberQueueInsight({
    required this.barberId,
    required this.barberName,
    required this.waitingCount,
    required this.activeCount,
    required this.aheadWaitMinutes,
    required this.maxSerialNo,
    required this.nextSerial,
  });
}

class _InsightAccumulator {
  _InsightAccumulator({
    required this.barberId,
    required this.barberName,
  });

  String barberId;
  String barberName;
  int waitingCount = 0;
  int activeCount = 0;
  int aheadWaitMinutes = 0;
  int maxSerialNo = 0;
}

class BookingBarber {
  final String id;
  final String name;
  final double rating;
  final String? avatarUrl;
  final String uid;
  final bool isAvailable;
  final int waitingClients;

  const BookingBarber({
    required this.id,
    required this.name,
    required this.rating,
    required this.avatarUrl,
    required this.uid,
    this.isAvailable = true,
    this.waitingClients = 0,
  });
}
