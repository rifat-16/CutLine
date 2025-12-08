import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalonDetailsProvider extends ChangeNotifier {
  SalonDetailsProvider({
    required this.salonId,
    required this.salonName,
    this.userId = '',
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String salonId;
  final String salonName;
  final String userId;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  SalonDetailsData? _details;
  List<SalonBarber> _barbers = [];
  List<SalonQueueEntry> _queue = [];
  bool _isFavorite = false;
  
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _queueSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bookingSubscription;
  String? _currentSalonId;

  bool get isLoading => _isLoading;
  String? get error => _error;
  SalonDetailsData? get details => _details;
  List<SalonBarber> get barbers => _barbers;
  List<SalonQueueEntry> get queue => _queue;
  bool get isFavorite => _isFavorite;

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    try {
      final doc = await _fetchSalonDoc();
      if (doc == null || !doc.exists) {
        _details = null;
        _setError('Salon details not found.');
      } else {
        final waitMinutes = await _estimateWaitMinutes(doc.id);
        _barbers = await _loadBarbers(doc.id);
        await _hydrateBarberAvatars(_barbers);
        _queue = await _loadQueue(doc.id);
        await _hydrateQueueAvatars(_queue);
        _details =
            _mapSalon(doc.id, doc.data() ?? {}, waitMinutes, _queue);
        await _loadFavorite(doc.id);
        _currentSalonId = doc.id;
        _startRealtimeQueueUpdates(doc.id);
      }
    } catch (_) {
      _details = null;
      _setError('Could not load salon details. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _fetchSalonDoc() async {
    DocumentSnapshot<Map<String, dynamic>>? doc;
    if (salonId.isNotEmpty) {
      doc = await _firestore.collection('salons').doc(salonId).get();
      if (doc.exists) return doc;
    }
    if (salonName.isNotEmpty) {
      final query = await _firestore
          .collection('salons')
          .where('name', isEqualTo: salonName)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first;
      }
    }
    return null;
  }

  SalonDetailsData _mapSalon(String id, Map<String, dynamic> data,
      int waitMinutes, List<SalonQueueEntry> queue) {
    final services = _mapServices(data['services']);
    final combos = _mapCombos(data['combos']);
    final workingHours = _mapWorkingHours(data['workingHours']);
    final topServicesFromServices = services.map((s) => s.name).toList();
    final topServicesField = data['topServices'];
    final topServices = _parseTopServices(topServicesField);
    // Try multiple field names for gallery photos
    final galleryPhotosRaw = data['galleryPhotos'] ?? 
        data['gallery'] ?? 
        data['photos'] ?? 
        data['galleryImages'];
    
    List<String> galleryPhotos = [];
    if (galleryPhotosRaw is List) {
      galleryPhotos = galleryPhotosRaw
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    } else if (galleryPhotosRaw is Map) {
      // Handle map format if needed
      galleryPhotos = galleryPhotosRaw.values
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return SalonDetailsData(
      id: id,
      name: (data['name'] as String?) ?? salonName,
      address: (data['address'] as String?) ?? 'Address unavailable',
      contact: (data['contact'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 4.6,
      reviews: (data['reviews'] as num?)?.toInt() ?? 120,
      isOpen: (data['isOpen'] as bool?) ?? true,
      waitMinutes: waitMinutes,
      coverImageUrl: (data['coverImageUrl'] as String?) ??
          (data['coverPhoto'] as String?),
      galleryPhotos: galleryPhotos,
      services: services,
      combos: combos,
      workingHours: workingHours,
      topServices: topServices.isNotEmpty
          ? topServices
          : topServicesFromServices.take(3).toList(),
      barbers: _barbers,
      queue: queue,
    );
  }

  Future<List<SalonBarber>> _loadBarbers(String salonId) async {
    try {
      final snap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('barbers')
          .get();
      final docs = snap.docs
          .map((doc) => _mapBarber(doc.id, doc.data()))
          .whereType<SalonBarber>()
          .toList();
      if (docs.isNotEmpty) return docs;

      // Fallback: read embedded array "barbers" from salon document
      final salonDoc =
          await _firestore.collection('salons').doc(salonId).get();
      final data = salonDoc.data() ?? {};
      final barbersField = data['barbers'];
      if (barbersField is List) {
        return barbersField
            .whereType<Map>()
            .map((e) => _mapBarber(
                  (e['uid'] as String?) ?? '',
                  e.cast<String, dynamic>(),
                ))
            .whereType<SalonBarber>()
            .toList();
      }
      return const [];
    } catch (_) {
      return const [];
    }
  }

  Future<void> _loadFavorite(String id) async {
    if (userId.isEmpty) return;
    try {
      final favDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .doc(id)
          .get();
      _isFavorite = favDoc.exists;
    } catch (_) {
      _isFavorite = false;
    }
    notifyListeners();
  }

  Future<void> toggleFavorite() async {
    if (userId.isEmpty || _details == null) return;
    final favRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .doc(_details!.id);
    try {
      if (_isFavorite) {
        await favRef.delete();
        _isFavorite = false;
      } else {
        await favRef.set({
          'salonId': _details!.id,
          'addedAt': FieldValue.serverTimestamp(),
        });
        _isFavorite = true;
      }
      notifyListeners();
    } catch (_) {
      // swallow for now; could set error state
    }
  }

  SalonBarber? _mapBarber(String id, Map<String, dynamic> data) {
    // Try to get uid from data, fallback to id
    final barberUid = (data['uid'] as String?) ?? 
        (data['barberUid'] as String?) ??
        (id.isNotEmpty ? id : null);
    return SalonBarber(
      id: id,
      uid: barberUid,
      name: (data['name'] as String?) ?? 'Barber',
      skills: _parseSkills(data['skills']),
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      isAvailable: (data['isAvailable'] as bool?) ?? true,
      waitingClients: (data['waitingClients'] as num?)?.toInt() ?? 0,
      avatarUrl: (data['avatarUrl'] as String?) ??
          (data['photoUrl'] as String?),
    );
  }

  String _parseSkills(dynamic skills) {
    if (skills is List) {
      return skills.whereType<String>().take(3).join(' • ');
    }
    if (skills is String) return skills;
    return 'Fade • Trim • Beard';
  }

  List<SalonService> _mapServices(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((raw) {
          final map = raw.cast<String, dynamic>();
          return SalonService(
            name: (map['name'] as String?) ?? 'Service',
            price: (map['price'] as num?)?.toInt() ?? 0,
            durationMinutes: (map['durationMinutes'] as num?)?.toInt() ?? 0,
          );
        })
        .toList();
  }

  List<SalonCombo> _mapCombos(dynamic data) {
    if (data is! List) return [];
    return data
        .whereType<Map>()
        .map((raw) {
          final map = raw.cast<String, dynamic>();
          return SalonCombo(
            name: (map['name'] as String?) ?? 'Combo',
            services: (map['services'] as String?) ?? '',
            highlight: (map['highlight'] as String?) ?? '',
            price: (map['price'] as num?)?.toInt() ?? 0,
            emoji: (map['emoji'] as String?) ?? '✨',
          );
        })
        .toList();
  }

  List<SalonWorkingHour> _mapWorkingHours(dynamic data) {
    final List<String> days = const [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday'
    ];
    final defaults = <String, Map<String, dynamic>>{
      'Monday': {'open': true, 'openTime': '09:00', 'closeTime': '21:00'},
      'Tuesday': {'open': true, 'openTime': '09:00', 'closeTime': '21:00'},
      'Wednesday': {'open': true, 'openTime': '09:00', 'closeTime': '21:00'},
      'Thursday': {'open': true, 'openTime': '09:00', 'closeTime': '21:00'},
      'Friday': {'open': true, 'openTime': '09:00', 'closeTime': '21:00'},
      'Saturday': {'open': true, 'openTime': '10:00', 'closeTime': '22:00'},
      'Sunday': {'open': false, 'openTime': '10:00', 'closeTime': '20:00'},
    };
    return days.map((day) {
      final entry =
          data is Map<String, dynamic> ? data[day] as Map<String, dynamic>? : null;
      final source = entry ?? defaults[day]!;
      final openTime = _parseTime(source['openTime'] as String?);
      final closeTime = _parseTime(source['closeTime'] as String?);
      return SalonWorkingHour(
        day: day,
        isOpen: source['open'] == true,
        openTime: openTime,
        closeTime: closeTime,
      );
    }).toList();
  }

  List<String> _parseTopServices(dynamic field) {
    if (field is List) {
      return field
          .map((e) => e is String
              ? e.trim()
              : e is Map<String, dynamic>
                  ? (e['name'] as String?)?.trim() ?? ''
                  : '')
          .where((e) => e.isNotEmpty)
          .take(3)
          .toList();
    }
    return [];
  }

  TimeOfDay? _parseTime(String? value) {
    if (value == null || !value.contains(':')) return null;
    final parts = value.split(':');
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  Future<int> _estimateWaitMinutes(String id) async {
    try {
      final snap = await _firestore
          .collection('salons')
          .doc(id)
          .collection('queue')
          .where('status', isEqualTo: 'waiting')
          .get();
      if (snap.docs.isEmpty) return 0;
      var collected = 0;
      var items = 0;
      for (final doc in snap.docs) {
        final wait = (doc.data()['waitMinutes'] as num?)?.toInt();
        if (wait != null && wait > 0) {
          collected += wait;
          items++;
        }
      }
      if (items > 0) return (collected / items).ceil();
      return snap.size * 10;
    } catch (_) {
      return 0;
    }
  }

  Future<List<SalonQueueEntry>> _loadQueue(String salonId) async {
    try {
      // Only load active queue items (waiting or serving)
      final queueSnap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .where('status', whereIn: ['waiting', 'serving'])
          .get();
      final bookingSnap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .where('status', whereIn: ['waiting', 'serving'])
          .get();

      final queueEntries = queueSnap.docs
          .map((doc) => _mapQueue(doc.id, doc.data()))
          .whereType<SalonQueueEntry>()
          .where((e) => e.isWaiting || e.isServing) // Additional filter
          .toList();
      final bookingEntries = bookingSnap.docs
          .map((doc) => _mapBooking(doc.id, doc.data()))
          .whereType<SalonQueueEntry>()
          .where((e) => e.isWaiting || e.isServing) // Additional filter
          .toList();

      final merged = _mergeQueue(queueEntries, bookingEntries)..sort(_queueComparator);
      await _hydrateQueueAvatars(merged);
      return merged;
    } catch (_) {
      // Fallback: try without status filter if query fails
      try {
        final queueSnap = await _firestore
            .collection('salons')
            .doc(salonId)
            .collection('queue')
            .get();
        final bookingSnap = await _firestore
            .collection('salons')
            .doc(salonId)
            .collection('bookings')
            .get();

        final queueEntries = queueSnap.docs
            .map((doc) => _mapQueue(doc.id, doc.data()))
            .whereType<SalonQueueEntry>()
            .where((e) => e.isWaiting || e.isServing)
            .toList();
        final bookingEntries = bookingSnap.docs
            .map((doc) => _mapBooking(doc.id, doc.data()))
            .whereType<SalonQueueEntry>()
            .where((e) => e.isWaiting || e.isServing)
            .toList();

        final merged = _mergeQueue(queueEntries, bookingEntries)..sort(_queueComparator);
        await _hydrateQueueAvatars(merged);
        return merged;
      } catch (_) {
        return const [];
      }
    }
  }

  void _startRealtimeQueueUpdates(String salonId) {
    // Cancel existing subscriptions
    _queueSubscription?.cancel();
    _bookingSubscription?.cancel();

    // Listen to queue collection - only active items
    try {
      _queueSubscription = _firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .where('status', whereIn: ['waiting', 'serving'])
          .snapshots()
          .listen((snapshot) async {
        await _updateQueueFromStream(salonId);
      }, onError: (_) {
        // Fallback: listen to all queue items and filter
        _queueSubscription?.cancel();
        _queueSubscription = _firestore
            .collection('salons')
            .doc(salonId)
            .collection('queue')
            .snapshots()
            .listen((snapshot) async {
          await _updateQueueFromStream(salonId);
        }, onError: (_) {});
      });
    } catch (_) {
      // Fallback: listen without filter
      _queueSubscription = _firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .snapshots()
          .listen((snapshot) async {
        await _updateQueueFromStream(salonId);
      }, onError: (_) {});
    }

    // Listen to bookings collection - only active items
    try {
      _bookingSubscription = _firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .where('status', whereIn: ['waiting', 'serving'])
          .snapshots()
          .listen((snapshot) async {
        await _updateQueueFromStream(salonId);
      }, onError: (_) {
        // Fallback: listen to all bookings and filter
        _bookingSubscription?.cancel();
        _bookingSubscription = _firestore
            .collection('salons')
            .doc(salonId)
            .collection('bookings')
            .snapshots()
            .listen((snapshot) async {
          await _updateQueueFromStream(salonId);
        }, onError: (_) {});
      });
    } catch (_) {
      // Fallback: listen without filter
      _bookingSubscription = _firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .snapshots()
          .listen((snapshot) async {
        await _updateQueueFromStream(salonId);
      }, onError: (_) {});
    }
  }

  Future<void> _updateQueueFromStream(String salonId) async {
    if (_currentSalonId != salonId) return;
    try {
      _queue = await _loadQueue(salonId);
      if (_details != null) {
        final waitMinutes = await _estimateWaitMinutes(salonId);
        _details = _details!.copyWith(
          waitMinutes: waitMinutes,
          queue: _queue,
        );
      }
      notifyListeners();
    } catch (_) {
      // Ignore errors, will retry on next stream update
    }
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _bookingSubscription?.cancel();
    super.dispose();
  }

  int _queueComparator(SalonQueueEntry a, SalonQueueEntry b) {
    const order = {'serving': 0, 'waiting': 1, 'done': 2};
    final statusCompare = (order[a.status] ?? 9).compareTo(order[b.status] ?? 9);
    if (statusCompare != 0) return statusCompare;
    final aKey = _scheduleKey(a);
    final bKey = _scheduleKey(b);
    if (aKey != null && bKey != null) return aKey.compareTo(bKey);
    if (aKey != null) return -1;
    if (bKey != null) return 1;
    return a.waitMinutes.compareTo(b.waitMinutes);
  }

  DateTime? _scheduleKey(SalonQueueEntry entry) {
    if (entry.dateTime != null) return entry.dateTime;
    return _combineDateAndTime(entry.date, entry.time);
  }

  List<SalonQueueEntry> _mergeQueue(
    List<SalonQueueEntry> queue,
    List<SalonQueueEntry> bookings,
  ) {
    final Map<String, SalonQueueEntry> map = {
      for (final item in queue) item.id: item
    };
    for (final booking in bookings) {
      final existing = map[booking.id];
      map[booking.id] = existing == null ? booking : _combineEntries(existing, booking);
    }
    return map.values.toList();
  }

  Future<void> _hydrateBarberAvatars(List<SalonBarber> barbers) async {
    final missing = barbers
        .where((b) =>
            (b.avatarUrl == null || b.avatarUrl!.isEmpty) &&
            (b.uid?.isNotEmpty == true))
        .map((b) => b.uid!)
        .whereType<String>()
        .toSet()
        .toList();
    if (missing.isEmpty) return;
    final photos = await _fetchUserPhotos(missing);
    if (photos.isEmpty) return;
    _barbers = barbers
        .map((b) {
          if (b.avatarUrl != null && b.avatarUrl!.isNotEmpty) return b;
          final url = b.uid != null ? photos[b.uid!] : null;
          if (url == null || url.isEmpty) return b;
          return b.copyWith(avatarUrl: url);
        })
        .toList();
    notifyListeners();
  }

  Future<void> _hydrateQueueAvatars(List<SalonQueueEntry> entries) async {
    final missing = entries
        .where((e) =>
            (e.avatarUrl == null || e.avatarUrl!.isEmpty) &&
            (e.customerUid?.isNotEmpty == true))
        .map((e) => e.customerUid!)
        .toSet()
        .toList();
    if (missing.isEmpty) return;
    final photos = await _fetchUserPhotos(missing);
    if (photos.isEmpty) return;
    _queue = entries
        .map((e) {
          if (e.avatarUrl != null && e.avatarUrl!.isNotEmpty) return e;
          final url = e.customerUid != null ? photos[e.customerUid!] : null;
          if (url == null || url.isEmpty) return e;
          return e.copyWith(avatarUrl: url);
        })
        .toList()
      ..sort(_queueComparator);
    notifyListeners();
  }

  Future<Map<String, String>> _fetchUserPhotos(List<String> uids) async {
    final Map<String, String> result = {};
    const int chunkSize = 10;
    for (var i = 0; i < uids.length; i += chunkSize) {
      final chunk = uids.skip(i).take(chunkSize).toList();
      try {
        final snap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final url = (data['photoUrl'] as String?) ??
              (data['avatarUrl'] as String?) ??
              (data['coverPhoto'] as String?);
          if (url != null && url.isNotEmpty) {
            result[doc.id] = url;
          }
        }
      } catch (_) {
        // ignore partial failures
      }
    }
    return result;
  }

  SalonQueueEntry _combineEntries(SalonQueueEntry primary, SalonQueueEntry fallback) {
    return primary.copyWith(
      customerName: primary.customerName.isNotEmpty
          ? primary.customerName
          : fallback.customerName,
      barberName: primary.barberName.isNotEmpty
          ? primary.barberName
          : fallback.barberName,
      service: primary.service.isNotEmpty ? primary.service : fallback.service,
      status: primary.status.isNotEmpty ? primary.status : fallback.status,
      waitMinutes: primary.waitMinutes != 0 ? primary.waitMinutes : fallback.waitMinutes,
      date: primary.date ?? fallback.date,
      time: primary.time ?? fallback.time,
      dateTime: primary.dateTime ?? fallback.dateTime,
      avatarUrl: primary.avatarUrl ?? fallback.avatarUrl,
      customerUid: primary.customerUid ?? fallback.customerUid,
    );
  }

  SalonQueueEntry? _mapQueue(String id, Map<String, dynamic> data) {
    final status = _normalizeStatus((data['status'] as String?) ?? 'waiting');
    final wait = (data['waitMinutes'] as num?)?.toInt() ?? 0;
    final date =
        _extractDateString(data['date'] ?? data['bookingDate']);
    final time =
        _extractTimeString(data['time'] ?? data['bookingTime'] ?? data['slotLabel']);
    final dateTime = _parseDateTime(data['dateTime']) ??
        _combineDateAndTime(date, time) ??
        _parseDateTime(data['createdAt']);
    final serviceLabel = _serviceFrom(data);
    final avatarUrl = (data['customerAvatar'] as String?) ??
        (data['avatar'] as String?) ??
        (data['photoUrl'] as String?);
    final customerUid = (data['customerUid'] as String?)?.trim();
    return SalonQueueEntry(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      barberName: (data['barberName'] as String?) ?? 'Barber',
      service: serviceLabel,
      status: status,
      waitMinutes: wait,
      date: date,
      time: time,
      dateTime: dateTime,
      avatarUrl: avatarUrl,
      customerUid: customerUid,
    );
  }

  SalonQueueEntry? _mapBooking(String id, Map<String, dynamic> data) {
    final status = _normalizeStatus((data['status'] as String?) ?? 'waiting');
    final wait = (data['durationMinutes'] as num?)?.toInt() ??
        (data['waitMinutes'] as num?)?.toInt() ??
        0;
    final date =
        _extractDateString(data['date'] ?? data['bookingDate']);
    final time =
        _extractTimeString(data['time'] ?? data['bookingTime'] ?? data['slotLabel']);
    final dateTime = _parseDateTime(data['dateTime']) ??
        _combineDateAndTime(date, time) ??
        _parseDateTime(data['createdAt']);
    final serviceLabel = _serviceFrom(data);
    final avatarUrl = (data['customerAvatar'] as String?) ??
        (data['avatar'] as String?) ??
        (data['photoUrl'] as String?);
    final customerUid = (data['customerUid'] as String?)?.trim();
    return SalonQueueEntry(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      barberName: (data['barberName'] as String?) ?? 'Barber',
      service: serviceLabel,
      status: status,
      waitMinutes: wait,
      date: date,
      time: time,
      dateTime: dateTime,
      avatarUrl: avatarUrl,
      customerUid: customerUid,
    );
  }

  String _normalizeStatus(String value) {
    final lower = value.toLowerCase();
    if (lower.contains('serv')) return 'serving';
    if (lower.contains('wait')) return 'waiting';
    // Treat completed/done as waiting for display so cards still show.
    return 'waiting';
  }

  String _serviceFrom(Map<String, dynamic> data) {
    final service = (data['service'] as String?)?.trim();
    if (service != null && service.isNotEmpty) return service;
    final services = data['services'];
    if (services is List) {
      final names = services
          .map((e) {
            if (e is Map<String, dynamic>) {
              final name = (e['name'] as String?)?.trim();
              if (name != null && name.isNotEmpty) return name;
            } else if (e is String && e.trim().isNotEmpty) {
              return e.trim();
            }
            return null;
          })
          .whereType<String>()
          .toList();
      if (names.isNotEmpty) return names.join(', ');
    }
    return 'Service';
  }

  String? _extractDateString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is Timestamp) {
      return DateFormat('yyyy-MM-dd').format(value.toDate());
    }
    return null;
  }

  String? _extractTimeString(dynamic value) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    if (value is Timestamp) {
      return DateFormat('h:mm a').format(value.toDate());
    }
    return null;
  }

  DateTime? _parseDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is String && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  DateTime? _combineDateAndTime(String? date, String? time) {
    if (date == null ||
        date.isEmpty ||
        time == null ||
        time.isEmpty) {
      return null;
    }
    try {
      final parsedDate = DateTime.parse(date);
      final parsedTime = DateFormat.jm().parse(time);
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
          parsedTime.hour, parsedTime.minute);
    } catch (_) {
      return null;
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

class SalonDetailsData {
  final String id;
  final String name;
  final String address;
  final String contact;
  final String email;
  final double rating;
  final int reviews;
  final bool isOpen;
  final int waitMinutes;
  final String? coverImageUrl;
  final List<String> galleryPhotos;
  final List<String> topServices;
  final List<SalonService> services;
  final List<SalonCombo> combos;
  final List<SalonWorkingHour> workingHours;
  final List<SalonBarber> barbers;
  final List<SalonQueueEntry> queue;

  const SalonDetailsData({
    required this.id,
    required this.name,
    required this.address,
    required this.contact,
    required this.email,
    required this.rating,
    required this.reviews,
    required this.isOpen,
    required this.waitMinutes,
    required this.coverImageUrl,
    required this.galleryPhotos,
    required this.topServices,
    required this.services,
    required this.combos,
    required this.workingHours,
    required this.barbers,
    required this.queue,
  });

  String get locationLabel {
    final parts = address.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return address;
  }

  SalonDetailsData copyWith({
    String? id,
    String? name,
    String? address,
    String? contact,
    String? email,
    double? rating,
    int? reviews,
    bool? isOpen,
    int? waitMinutes,
    String? coverImageUrl,
    List<String>? galleryPhotos,
    List<String>? topServices,
    List<SalonService>? services,
    List<SalonCombo>? combos,
    List<SalonWorkingHour>? workingHours,
    List<SalonBarber>? barbers,
    List<SalonQueueEntry>? queue,
  }) {
    return SalonDetailsData(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      contact: contact ?? this.contact,
      email: email ?? this.email,
      rating: rating ?? this.rating,
      reviews: reviews ?? this.reviews,
      isOpen: isOpen ?? this.isOpen,
      waitMinutes: waitMinutes ?? this.waitMinutes,
      coverImageUrl: coverImageUrl ?? this.coverImageUrl,
      galleryPhotos: galleryPhotos ?? this.galleryPhotos,
      topServices: topServices ?? this.topServices,
      services: services ?? this.services,
      combos: combos ?? this.combos,
      workingHours: workingHours ?? this.workingHours,
      barbers: barbers ?? this.barbers,
      queue: queue ?? this.queue,
    );
  }
}

class SalonService {
  final String name;
  final int price;
  final int durationMinutes;

  const SalonService({
    required this.name,
    required this.price,
    required this.durationMinutes,
  });
}

class SalonBarber {
  final String id;
  final String? uid;
  final String name;
  final String skills;
  final double rating;
  final bool isAvailable;
  final int waitingClients;
  final String? avatarUrl;

  const SalonBarber({
    required this.id,
    this.uid,
    required this.name,
    required this.skills,
    required this.rating,
    required this.isAvailable,
    required this.waitingClients,
    required this.avatarUrl,
  });

  SalonBarber copyWith({
    String? id,
    String? uid,
    String? name,
    String? skills,
    double? rating,
    bool? isAvailable,
    int? waitingClients,
    String? avatarUrl,
  }) {
    return SalonBarber(
      id: id ?? this.id,
      uid: uid ?? this.uid,
      name: name ?? this.name,
      skills: skills ?? this.skills,
      rating: rating ?? this.rating,
      isAvailable: isAvailable ?? this.isAvailable,
      waitingClients: waitingClients ?? this.waitingClients,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}

class SalonQueueEntry {
  final String id;
  final String customerName;
  final String barberName;
  final String service;
  final String status;
  final int waitMinutes;
  final String? date;
  final String? time;
  final DateTime? dateTime;
  final String? avatarUrl;
  final String? customerUid;

  const SalonQueueEntry({
    required this.id,
    required this.customerName,
    required this.barberName,
    required this.service,
    required this.status,
    required this.waitMinutes,
    this.date,
    this.time,
    this.dateTime,
    this.avatarUrl,
    this.customerUid,
  });

  bool get isWaiting => status == 'waiting';
  bool get isServing => status == 'serving';

  String? get _formattedDate {
    final raw = date?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    if (dateTime != null) return DateFormat('yyyy-MM-dd').format(dateTime!);
    return null;
  }

  String? get _formattedTime {
    final raw = time?.trim();
    if (raw != null && raw.isNotEmpty) return raw;
    if (dateTime != null) return DateFormat('h:mm a').format(dateTime!);
    return null;
  }

  String get dateLabel => _formattedDate ?? 'Date not set';

  String get timeLabel => _formattedTime ?? 'Time not set';

  SalonQueueEntry copyWith({
    String? customerName,
    String? barberName,
    String? service,
    String? status,
    int? waitMinutes,
    String? date,
    String? time,
    DateTime? dateTime,
    String? avatarUrl,
    String? customerUid,
  }) {
    return SalonQueueEntry(
      id: id,
      customerName: customerName ?? this.customerName,
      barberName: barberName ?? this.barberName,
      service: service ?? this.service,
      status: status ?? this.status,
      waitMinutes: waitMinutes ?? this.waitMinutes,
      date: date ?? this.date,
      time: time ?? this.time,
      dateTime: dateTime ?? this.dateTime,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      customerUid: customerUid ?? this.customerUid,
    );
  }
}

class SalonCombo {
  final String name;
  final String services;
  final String highlight;
  final int price;
  final String emoji;

  const SalonCombo({
    required this.name,
    required this.services,
    required this.highlight,
    required this.price,
    required this.emoji,
  });
}

class SalonWorkingHour {
  final String day;
  final bool isOpen;
  final TimeOfDay? openTime;
  final TimeOfDay? closeTime;

  const SalonWorkingHour({
    required this.day,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  String get timeRangeLabel {
    if (!isOpen) return 'Closed';
    final openLabel = _formatTime(openTime);
    final closeLabel = _formatTime(closeTime);
    if (openLabel == null || closeLabel == null) return 'Schedule unavailable';
    return '$openLabel – $closeLabel';
  }

  String? _formatTime(TimeOfDay? time) {
    if (time == null) return null;
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }
}
