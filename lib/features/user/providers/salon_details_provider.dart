import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/shared/services/firestore_cache.dart';
import 'package:cutline/shared/services/local_ttl_cache.dart';
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
  bool _isQueueLoading = false;
  bool _queueLoaded = false;
  int? _summaryWaitMinutesCache;

  bool get isLoading => _isLoading;
  String? get error => _error;
  SalonDetailsData? get details => _details;
  List<SalonBarber> get barbers => _barbers;
  List<SalonQueueEntry> get queue => _queue;
  bool get isFavorite => _isFavorite;
  bool get isQueueLoading => _isQueueLoading;

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    try {
      final doc = await _fetchSalonDoc();
      if (doc == null || !doc.exists) {
        _details = null;
        _setError('Salon details not found.');
        return;
      }

      final summary = await _fetchSalonSummary(doc.id);
      _summaryWaitMinutesCache = _summaryWaitMinutes(summary);

      // Load data with error handling - continue even if some parts fail
      try {
        _barbers = await _loadBarbers(doc.id);
      } catch (e) {
        _barbers = [];
      }

      try {
        await _hydrateBarberAvatars(_barbers);
      } catch (e) {}

      List<SalonService> services = [];
      try {
        services = await _loadServices(doc.id);
      } catch (e) {
        services = [];
      }

      List<String> galleryPhotos = [];
      try {
        galleryPhotos = await _loadGalleryPhotos(doc.id);
      } catch (e) {
        galleryPhotos = [];
      }

      _queue = [];
      _queueLoaded = false;

      final waitMinutes =
          _summaryWaitMinutesCache ?? _computeWaitMinutes(_queue);
      _details = _mapSalon(
        doc.id,
        doc.data() ?? {},
        waitMinutes,
        _queue,
        services,
        galleryPhotos,
        summary?['topServices'],
      );

      try {
        await _loadFavorite(doc.id);
      } catch (e) {
        _isFavorite = false;
      }
    } catch (e, stackTrace) {
      _details = null;

      String errorMessage = 'Could not load salon details. Pull to refresh.';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          errorMessage = 'This salon is not available yet.';
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

  Future<void> loadQueue() async {
    if (_isQueueLoading || _queueLoaded) return;
    _isQueueLoading = true;
    notifyListeners();
    try {
      final entries = await _loadQueue(salonId);
      await _hydrateQueueAvatars(entries);
      _queue = entries;
      _queueLoaded = true;
      try {
        _updateBarberWaitingCounts(_barbers, _queue);
      } catch (_) {
        // ignore waiting count failures
      }
      final waitMinutes =
          _summaryWaitMinutesCache ?? _computeWaitMinutes(_queue);
      if (_details != null) {
        _details = _details!.copyWith(
          queue: _queue,
          barbers: _barbers,
          waitMinutes: waitMinutes,
        );
      }
    } catch (_) {
      // keep queue empty on failure
    } finally {
      _isQueueLoading = false;
      notifyListeners();
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _fetchSalonDoc() async {
    try {
      DocumentSnapshot<Map<String, dynamic>>? doc;
      if (salonId.isNotEmpty) {
        doc = await FirestoreCache.getDocCacheFirst(
            _firestore.collection('salons').doc(salonId));
        if (doc.exists) {
          return doc;
        } else {}
      }
      if (salonName.isNotEmpty) {
        try {
          final query = await FirestoreCache.getQueryCacheFirst(_firestore
              .collection('salons')
              .where('name', isEqualTo: salonName)
              .where('verificationStatus', isEqualTo: 'verified')
              .limit(1));
          if (query.docs.isNotEmpty) {
            return query.docs.first;
          } else {}
        } catch (e) {}
      }
      return null;
    } catch (e, stackTrace) {
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchSalonSummary(String salonId) async {
    try {
      final doc = await FirestoreCache.getDocCacheFirst(
        _firestore.collection('salons_summary').doc(salonId),
      );
      return doc.data();
    } catch (_) {
      return null;
    }
  }

  int? _summaryWaitMinutes(Map<String, dynamic>? summary) {
    if (summary == null) return null;
    final value = summary['avgWaitMinutes'];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  SalonDetailsData _mapSalon(
    String id,
    Map<String, dynamic> data,
    int waitMinutes,
    List<SalonQueueEntry> queue,
    List<SalonService> services,
    List<String> galleryPhotos,
    dynamic summaryTopServices,
  ) {
    final combos = _mapCombos(data['combos']);
    final workingHours = _mapWorkingHours(data['workingHours']);
    final topServicesFromServices = services.map((s) => s.name).toList();
    final topServices =
        _parseTopServices(summaryTopServices ?? data['topServices']);

    final locationField = data['location'];
    final GeoPoint? geoPoint = locationField is GeoPoint ? locationField : null;

    return SalonDetailsData(
      id: id,
      name: (data['name'] as String?) ?? salonName,
      address: (data['address'] as String?) ?? 'Address unavailable',
      mapAddress: (data['mapAddress'] as String?) ??
          (data['address'] as String?) ??
          'Address unavailable',
      location: geoPoint,
      contact: (data['contact'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      rating: (data['rating'] as num?)?.toDouble() ?? 4.6,
      reviews: (data['reviews'] as num?)?.toInt() ?? 120,
      isOpen: (data['isOpen'] as bool?) ?? false,
      waitMinutes: waitMinutes,
      coverImageUrl:
          (data['coverImageUrl'] as String?) ?? (data['coverPhoto'] as String?),
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
    List<SalonBarber> cachedBarbers = const [];
    try {
      final cached = await LocalTtlCache.get<List<dynamic>>(
          'salon_details_barbers:$salonId');
      if (cached != null && cached.isNotEmpty) {
        cachedBarbers = cached
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .map((data) => _mapBarber(
                  (data['id'] as String?) ?? '',
                  data,
                ))
            .whereType<SalonBarber>()
            .toList();
      }
    } catch (_) {
      cachedBarbers = const [];
    }

    try {
      final snap = await FirestoreCache.getQueryCacheFirst(
          _firestore.collection('salons').doc(salonId).collection('barbers'));

      final docs = snap.docs
          .map((doc) => _mapBarber(doc.id, doc.data()))
          .whereType<SalonBarber>()
          .toList();

      // Also read embedded array "barbers" from salon document and merge.
      final embeddedBarbers = <SalonBarber>[];
      try {
        final salonDoc = await FirestoreCache.getDocCacheFirst(
            _firestore.collection('salons').doc(salonId));
        final data = salonDoc.data() ?? {};
        final barbersField = data['barbers'];

        if (barbersField is List) {
          for (var i = 0; i < barbersField.length; i++) {
            final item = barbersField[i];
            if (item is Map) {
              try {
                final barberMap = item.cast<String, dynamic>();
                // Try to get a valid ID - could be uid, id, or index
                final barberId = (barberMap['uid'] as String?)?.trim() ??
                    (barberMap['id'] as String?)?.trim() ??
                    (barberMap['barberId'] as String?)?.trim() ??
                    'barber_$i';

                final barber = _mapBarber(barberId, barberMap);
                if (barber != null) {
                  embeddedBarbers.add(barber);
                } else {}
              } catch (e) {}
            } else {}
          }
        } else {}
      } catch (e, stackTrace) {}

      final merged = _mergeBarberSources(docs, embeddedBarbers);
      if (merged.isNotEmpty) {
        await LocalTtlCache.set(
          'salon_details_barbers:$salonId',
          merged
              .map((b) => {
                    'id': b.id,
                    'uid': b.uid,
                    'name': b.name,
                    'skills': b.skills,
                    'rating': b.rating,
                    'isAvailable': b.isAvailable,
                    'waitingClients': b.waitingClients,
                    'avatarUrl': b.avatarUrl,
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
    } catch (e, stackTrace) {
      if (cachedBarbers.isNotEmpty) {
        return cachedBarbers;
      }
      return const [];
    }
  }

  Future<List<SalonService>> _loadServices(String salonId) async {
    try {
      final cached = await LocalTtlCache.get<List<dynamic>>(
          'salon_details_services:$salonId');
      if (cached != null && cached.isNotEmpty) {
        return cached
            .whereType<Map>()
            .map((m) => m.cast<String, dynamic>())
            .map((data) => SalonService(
                  name: (data['name'] as String?) ?? 'Service',
                  price: (data['price'] as num?)?.toInt() ?? 0,
                  durationMinutes:
                      (data['durationMinutes'] as num?)?.toInt() ?? 0,
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
        final data = doc.data();
        return SalonService(
          name: (data['name'] as String?) ?? 'Service',
          price: (data['price'] as num?)?.toInt() ?? 0,
          durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      if (services.isNotEmpty) {
        await LocalTtlCache.set(
          'salon_details_services:$salonId',
          services
              .map((s) => {
                    'name': s.name,
                    'price': s.price,
                    'durationMinutes': s.durationMinutes,
                  })
              .toList(),
          const Duration(hours: 24),
        );
        return services;
      }
    } catch (_) {
      // fall through to fallback
    }
    try {
      final fallbackQuery = _firestore
          .collection('salons')
          .doc(salonId)
          .collection('all_services');
      final snap = await FirestoreCache.getQueryCacheFirst(fallbackQuery);
      final services = snap.docs.map((doc) {
        final data = doc.data();
        return SalonService(
          name: (data['name'] as String?) ?? 'Service',
          price: (data['price'] as num?)?.toInt() ?? 0,
          durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
        );
      }).toList();
      if (services.isNotEmpty) {
        await LocalTtlCache.set(
          'salon_details_services:$salonId',
          services
              .map((s) => {
                    'name': s.name,
                    'price': s.price,
                    'durationMinutes': s.durationMinutes,
                  })
              .toList(),
          const Duration(hours: 24),
        );
      }
      return services;
    } catch (_) {
      return [];
    }
  }

  Future<List<String>> _loadGalleryPhotos(String salonId) async {
    try {
      final cached = await LocalTtlCache.get<List<dynamic>>(
          'salon_details_gallery:$salonId');
      if (cached != null && cached.isNotEmpty) {
        return cached.whereType<String>().toList();
      }
      final query = _firestore
          .collection('salons')
          .doc(salonId)
          .collection('photos')
          .orderBy('order');
      final snap = await FirestoreCache.getQueryCacheFirst(query);
      final photos = snap.docs
          .map((doc) => (doc.data()['url'] as String?)?.trim() ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
      if (photos.isNotEmpty) {
        await LocalTtlCache.set(
          'salon_details_gallery:$salonId',
          photos,
          const Duration(hours: 24),
        );
        return photos;
      }
    } catch (_) {
      // fall through to fallback
    }
    try {
      final fallbackQuery =
          _firestore.collection('salons').doc(salonId).collection('photos');
      final snap = await FirestoreCache.getQueryCacheFirst(fallbackQuery);
      final photos = snap.docs
          .map((doc) => (doc.data()['url'] as String?)?.trim() ?? '')
          .where((url) => url.isNotEmpty)
          .toList();
      if (photos.isNotEmpty) {
        await LocalTtlCache.set(
          'salon_details_gallery:$salonId',
          photos,
          const Duration(hours: 24),
        );
      }
      return photos;
    } catch (_) {
      // fall through to embedded gallery fallback
    }

    // Final fallback: read embedded gallery fields from salon document.
    try {
      final salonDoc = await FirestoreCache.getDocCacheFirst(
        _firestore.collection('salons').doc(salonId),
      );
      final data = salonDoc.data() ?? {};
      final candidates = [
        data['galleryPhotos'],
        data['galleryImages'],
        data['photos'],
        data['gallery'],
        data['coverPhoto'],
        data['coverImageUrl'],
      ];
      final urls = <String>{};
      for (final field in candidates) {
        if (field is List) {
          for (final item in field) {
            if (item is String && item.trim().isNotEmpty) {
              urls.add(item.trim());
            } else if (item is Map) {
              final url = (item['url'] as String?)?.trim();
              if (url != null && url.isNotEmpty) urls.add(url);
            }
          }
        } else if (field is String && field.trim().isNotEmpty) {
          urls.add(field.trim());
        }
      }
      final list = urls.toList();
      if (list.isNotEmpty) {
        await LocalTtlCache.set(
          'salon_details_gallery:$salonId',
          list,
          const Duration(hours: 24),
        );
        return list;
      }
    } catch (_) {
      // ignore
    }

    return [];
  }

  Future<void> _loadFavorite(String id) async {
    if (userId.isEmpty) {
      return;
    }
    try {
      final userDoc = await FirestoreCache.getDocCacheFirst(
        _firestore.collection('users').doc(userId),
      );
      final data = userDoc.data();
      final raw = data?['favoriteSalonIds'];
      if (raw is List) {
        _isFavorite = raw.whereType<String>().contains(id);
      } else {
        _isFavorite = false;
      }
    } catch (e) {
      _isFavorite = false;
    }
    notifyListeners();
  }

  Future<void> toggleFavorite() async {
    if (userId.isEmpty || _details == null) {
      return;
    }

    final userRef = _firestore.collection('users').doc(userId);

    try {
      if (_isFavorite) {
        await userRef.set(
          {
            'favoriteSalonIds': FieldValue.arrayRemove([_details!.id]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        _isFavorite = false;
      } else {
        await userRef.set(
          {
            'favoriteSalonIds': FieldValue.arrayUnion([_details!.id]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
        _isFavorite = true;
      }
      notifyListeners();
    } catch (e, stackTrace) {
      // Revert UI state on error
      _isFavorite = !_isFavorite;
      notifyListeners();
    }
  }

  SalonBarber? _mapBarber(String id, Map<String, dynamic> data) {
    try {
      // Try to get uid from data, fallback to id
      final barberUid = (data['uid'] as String?) ??
          (data['barberUid'] as String?) ??
          (data['id'] as String?) ??
          (id.isNotEmpty ? id : null);

      // Get name with multiple fallback options
      final name = (data['name'] as String?)?.trim() ?? 'Barber';
      if (name.isEmpty || name == 'Barber') {}

      // Get specialization/skills
      final specialization = (data['specialization'] as String?)?.trim() ?? '';
      final skills = _parseSkills(
          data['skills'] ?? data['specialization'] ?? specialization);

      // Get availability
      final isAvailable = (data['isAvailable'] as bool?) ??
          (data['available'] as bool?) ??
          true;

      // Get waiting clients count
      final waitingClients = (data['waitingClients'] as num?)?.toInt() ??
          (data['waiting'] as num?)?.toInt() ??
          0;

      // Get avatar/photo URL
      final avatarUrl = (data['avatarUrl'] as String?)?.trim() ??
          (data['photoUrl'] as String?)?.trim() ??
          (data['photo'] as String?)?.trim();

      final barber = SalonBarber(
        id: id,
        uid: barberUid,
        name: name,
        skills: skills.isNotEmpty ? skills : 'Haircut • Trim • Styling',
        rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
        isAvailable: isAvailable,
        waitingClients: waitingClients,
        avatarUrl: avatarUrl,
      );

      return barber;
    } catch (e) {
      return null;
    }
  }

  List<SalonBarber> _mergeBarberSources(
    List<SalonBarber> primary,
    List<SalonBarber> secondary,
  ) {
    final merged = <String, SalonBarber>{};
    for (final barber in [...primary, ...secondary]) {
      final key = _barberMergeKey(
        uid: barber.uid,
        id: barber.id,
        name: barber.name,
      );
      final existing = merged[key];
      if (existing == null) {
        merged[key] = barber;
        continue;
      }
      if ((existing.avatarUrl == null || existing.avatarUrl!.isEmpty) &&
          barber.avatarUrl != null &&
          barber.avatarUrl!.isNotEmpty) {
        merged[key] = existing.copyWith(avatarUrl: barber.avatarUrl);
      }
    }
    return merged.values.toList();
  }

  String _barberMergeKey({
    required String? uid,
    required String id,
    required String name,
  }) {
    final normalizedUid = (uid ?? '').trim().toLowerCase();
    if (normalizedUid.isNotEmpty) return 'uid:$normalizedUid';
    final normalizedId = id.trim().toLowerCase();
    if (normalizedId.isNotEmpty) return 'id:$normalizedId';
    return 'name:${name.trim().toLowerCase()}';
  }

  String _parseSkills(dynamic skills) {
    if (skills is List) {
      return skills.whereType<String>().take(3).join(' • ');
    }
    if (skills is String) return skills;
    return 'Fade • Trim • Beard';
  }

  List<SalonCombo> _mapCombos(dynamic data) {
    if (data is! List) return [];
    return data.whereType<Map>().map((raw) {
      final map = raw.cast<String, dynamic>();
      return SalonCombo(
        name: (map['name'] as String?) ?? 'Combo',
        services: (map['services'] as String?) ?? '',
        highlight: (map['highlight'] as String?) ?? '',
        price: (map['price'] as num?)?.toInt() ?? 0,
        emoji: (map['emoji'] as String?) ?? '✨',
      );
    }).toList();
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
      final entry = data is Map<String, dynamic>
          ? data[day] as Map<String, dynamic>?
          : null;
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

  Future<List<SalonQueueEntry>> _loadQueue(String salonId) async {
    try {
      // Only load active queue items (waiting or serving)
      final queueSnap = await FirestoreCache.getQuery(_firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .where('status', whereIn: ['waiting', 'serving']).limit(50));

      final bookingSnap = await FirestoreCache.getQuery(_firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .where('status', whereIn: ['waiting', 'serving']).limit(50));

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

      final merged = _mergeQueue(queueEntries, bookingEntries)
        ..sort(_queueComparator);
      try {
        await _hydrateQueueAvatars(merged);
      } catch (e) {}
      return merged;
    } catch (e) {
      // Fallback: try without status filter if query fails
      try {
        final queueSnap = await FirestoreCache.getQuery(_firestore
            .collection('salons')
            .doc(salonId)
            .collection('queue')
            .limit(200));
        final bookingSnap = await FirestoreCache.getQuery(_firestore
            .collection('salons')
            .doc(salonId)
            .collection('bookings')
            .limit(200));

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

        final merged = _mergeQueue(queueEntries, bookingEntries)
          ..sort(_queueComparator);
        try {
          await _hydrateQueueAvatars(merged);
        } catch (e2) {}
        return merged;
      } catch (e2) {
        return const [];
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  int _queueComparator(SalonQueueEntry a, SalonQueueEntry b) {
    const order = {'serving': 0, 'waiting': 1, 'done': 2};
    final statusCompare =
        (order[a.status] ?? 9).compareTo(order[b.status] ?? 9);
    if (statusCompare != 0) return statusCompare;

    final barberCmp = _queueBarberSortKey(a).compareTo(_queueBarberSortKey(b));
    if (barberCmp != 0) return barberCmp;

    final aSerial = a.serialNo ?? (1 << 30);
    final bSerial = b.serialNo ?? (1 << 30);
    if (aSerial != bSerial) return aSerial.compareTo(bSerial);

    final aKey = _scheduleKey(a);
    final bKey = _scheduleKey(b);
    if (aKey != null && bKey != null) return aKey.compareTo(bKey);
    if (aKey != null) return -1;
    if (bKey != null) return 1;
    return a.waitMinutes.compareTo(b.waitMinutes);
  }

  String _queueBarberSortKey(SalonQueueEntry entry) {
    final serialKey = entry.serialBarberKey.trim().toLowerCase();
    if (serialKey.isNotEmpty) return serialKey;
    return entry.barberName.trim().toLowerCase();
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
      map[booking.id] =
          existing == null ? booking : _combineEntries(existing, booking);
    }
    return map.values.toList();
  }

  Future<void> _hydrateBarberAvatars(List<SalonBarber> barbers) async {
    try {
      final missing = barbers
          .where((b) =>
              (b.avatarUrl == null || b.avatarUrl!.isEmpty) &&
              (b.uid?.isNotEmpty == true))
          .map((b) => b.uid!)
          .whereType<String>()
          .toSet()
          .toList();

      if (missing.isEmpty) {
        return;
      }

      final photos = await _fetchUserPhotos(missing);

      if (photos.isEmpty) {
        return;
      }

      final updatedBarbers = barbers.map((b) {
        if (b.avatarUrl != null && b.avatarUrl!.isNotEmpty) return b;
        final url = b.uid != null ? photos[b.uid!] : null;
        if (url == null || url.isEmpty) {
          return b;
        }
        return b.copyWith(avatarUrl: url);
      }).toList();

      _barbers = updatedBarbers;
      notifyListeners();
    } catch (e, stackTrace) {}
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
    _queue = entries.map((e) {
      if (e.avatarUrl != null && e.avatarUrl!.isNotEmpty) return e;
      final url = e.customerUid != null ? photos[e.customerUid!] : null;
      if (url == null || url.isEmpty) return e;
      return e.copyWith(avatarUrl: url);
    }).toList()
      ..sort(_queueComparator);
    notifyListeners();
  }

  Future<Map<String, String>> _fetchUserPhotos(List<String> uids) async {
    final Map<String, String> result = {};

    // Use individual document reads instead of whereIn to avoid permission issues
    // Similar to what we did in OwnerQueueService for customer avatars

    for (final uid in uids) {
      try {
        final doc = await FirestoreCache.getDocCacheFirst(
          _firestore.collection('users').doc(uid),
        );
        if (doc.exists) {
          final data = doc.data() ?? {};
          final url = (data['photoUrl'] as String?)?.trim() ??
              (data['avatarUrl'] as String?)?.trim() ??
              (data['coverPhoto'] as String?)?.trim() ??
              (data['photo'] as String?)?.trim();
          if (url != null && url.isNotEmpty) {
            result[uid] = url;
          } else {}
        } else {}
      } catch (e) {
        // Continue with other users
      }
    }

    return result;
  }

  void _updateBarberWaitingCounts(
      List<SalonBarber> barbers, List<SalonQueueEntry> queue) {
    try {
      // Count waiting items per barber by matching barber name or UID
      final waitingCounts = <String, int>{};

      // First, count by barber name
      for (final entry in queue) {
        if (entry.isWaiting) {
          final barberName = entry.barberName.trim().toLowerCase();
          if (barberName.isNotEmpty && barberName != 'barber') {
            waitingCounts[barberName] = (waitingCounts[barberName] ?? 0) + 1;
          }
        }
      }

      // Update barbers with waiting counts
      for (var i = 0; i < barbers.length; i++) {
        final barber = barbers[i];
        final barberNameLower = barber.name.trim().toLowerCase();
        final waitingCount = waitingCounts[barberNameLower] ?? 0;

        if (waitingCount != barber.waitingClients) {
          _barbers[i] = barber.copyWith(waitingClients: waitingCount);
        }
      }

      notifyListeners();
    } catch (e, stackTrace) {}
  }

  int _computeWaitMinutes(List<SalonQueueEntry> queue) {
    final waiting = queue.where((entry) => entry.isWaiting).toList();
    if (waiting.isEmpty) return 0;
    var collected = 0;
    var items = 0;
    for (final entry in waiting) {
      if (entry.waitMinutes > 0) {
        collected += entry.waitMinutes;
        items++;
      }
    }
    if (items > 0) {
      final avg = (collected / items).ceil();
      return avg;
    }
    return waiting.length * 10;
  }

  SalonQueueEntry _combineEntries(
      SalonQueueEntry primary, SalonQueueEntry fallback) {
    final bestDate = _preferNonEmptyString(fallback.date, primary.date);
    final bestTime = _preferNonEmptyString(fallback.time, primary.time);
    final bestDateTime = _combineDateAndTime(bestDate, bestTime) ??
        fallback.dateTime ??
        primary.dateTime;
    return primary.copyWith(
      customerName: primary.customerName.isNotEmpty
          ? primary.customerName
          : fallback.customerName,
      barberName: primary.barberName.isNotEmpty
          ? primary.barberName
          : fallback.barberName,
      service: primary.service.isNotEmpty ? primary.service : fallback.service,
      status: primary.status.isNotEmpty ? primary.status : fallback.status,
      waitMinutes:
          primary.waitMinutes != 0 ? primary.waitMinutes : fallback.waitMinutes,
      date: bestDate,
      time: bestTime,
      dateTime: bestDateTime,
      avatarUrl: primary.avatarUrl ?? fallback.avatarUrl,
      customerUid: primary.customerUid ?? fallback.customerUid,
      serialNo: primary.serialNo ?? fallback.serialNo,
      serialBarberKey: primary.serialBarberKey.isNotEmpty
          ? primary.serialBarberKey
          : fallback.serialBarberKey,
      entrySource: primary.entrySource.isNotEmpty
          ? primary.entrySource
          : fallback.entrySource,
    );
  }

  String? _preferNonEmptyString(String? preferred, String? fallback) {
    final preferredTrimmed = preferred?.trim() ?? '';
    if (preferredTrimmed.isNotEmpty) return preferredTrimmed;
    final fallbackTrimmed = fallback?.trim() ?? '';
    if (fallbackTrimmed.isNotEmpty) return fallbackTrimmed;
    return null;
  }

  String _normalizeTimeString(String value) {
    return value
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  SalonQueueEntry? _mapQueue(String id, Map<String, dynamic> data) {
    final status = _normalizeStatus((data['status'] as String?) ?? 'waiting');
    final wait = (data['waitMinutes'] as num?)?.toInt() ?? 0;
    final date = _extractDateString(data['date'] ?? data['bookingDate']);
    final time = _extractTimeString(
        data['time'] ?? data['bookingTime'] ?? data['slotLabel']);
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
      serialNo: (data['serialNo'] as num?)?.toInt(),
      serialBarberKey: (data['serialBarberKey'] as String?) ?? '',
      entrySource: (data['entrySource'] as String?) ?? '',
    );
  }

  SalonQueueEntry? _mapBooking(String id, Map<String, dynamic> data) {
    final status = _normalizeStatus((data['status'] as String?) ?? 'waiting');
    final wait = (data['durationMinutes'] as num?)?.toInt() ??
        (data['waitMinutes'] as num?)?.toInt() ??
        0;
    final date = _extractDateString(data['date'] ?? data['bookingDate']);
    final time = _extractTimeString(
        data['time'] ?? data['bookingTime'] ?? data['slotLabel']);
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
      serialNo: (data['serialNo'] as num?)?.toInt(),
      serialBarberKey: (data['serialBarberKey'] as String?) ?? '',
      entrySource: (data['entrySource'] as String?) ?? '',
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
    if (date == null || date.isEmpty || time == null || time.isEmpty) {
      return null;
    }
    try {
      final parsedDate = DateTime.parse(date);
      final parsedTime =
          DateFormat('h:mm a', 'en_US').parse(_normalizeTimeString(time));
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
  final String mapAddress;
  final GeoPoint? location;
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
    required this.mapAddress,
    required this.location,
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
    String? mapAddress,
    GeoPoint? location,
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
      mapAddress: mapAddress ?? this.mapAddress,
      location: location ?? this.location,
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
  final int? serialNo;
  final String serialBarberKey;
  final String entrySource;

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
    this.serialNo,
    this.serialBarberKey = '',
    this.entrySource = '',
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
    int? serialNo,
    String? serialBarberKey,
    String? entrySource,
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
      serialNo: serialNo ?? this.serialNo,
      serialBarberKey: serialBarberKey ?? this.serialBarberKey,
      entrySource: entrySource ?? this.entrySource,
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
