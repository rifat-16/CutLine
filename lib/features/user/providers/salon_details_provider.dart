import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

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
        _queue = await _loadQueue(doc.id);
        _details =
            _mapSalon(doc.id, doc.data() ?? {}, waitMinutes, _queue);
        await _loadFavorite(doc.id);
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
      coverImageUrl: data['coverImageUrl'] as String?,
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
    return SalonBarber(
      id: id,
      name: (data['name'] as String?) ?? 'Barber',
      skills: _parseSkills(data['skills']),
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      isAvailable: (data['isAvailable'] as bool?) ?? true,
      waitingClients: (data['waitingClients'] as num?)?.toInt() ?? 0,
      avatarUrl: data['avatarUrl'] as String?,
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
      final snap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .get();
      final entries = snap.docs.map((doc) {
        final data = doc.data();
        return _mapQueue(doc.id, data);
      }).whereType<SalonQueueEntry>().toList();
      entries.sort((a, b) {
        const order = {'serving': 0, 'waiting': 1, 'done': 2};
        return (order[a.status] ?? 9).compareTo(order[b.status] ?? 9);
      });
      return entries;
    } catch (_) {
      return const [];
    }
  }

  SalonQueueEntry? _mapQueue(String id, Map<String, dynamic> data) {
    final status = (data['status'] as String?) ?? 'waiting';
    final wait = (data['waitMinutes'] as num?)?.toInt() ?? 0;
    return SalonQueueEntry(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      barberName: (data['barberName'] as String?) ?? 'Barber',
      service: (data['service'] as String?) ?? 'Service',
      status: status,
      waitMinutes: wait,
    );
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
  final String name;
  final String skills;
  final double rating;
  final bool isAvailable;
  final int waitingClients;
  final String? avatarUrl;

  const SalonBarber({
    required this.id,
    required this.name,
    required this.skills,
    required this.rating,
    required this.isAvailable,
    required this.waitingClients,
    required this.avatarUrl,
  });
}

class SalonQueueEntry {
  final String id;
  final String customerName;
  final String barberName;
  final String service;
  final String status;
  final int waitMinutes;

  const SalonQueueEntry({
    required this.id,
    required this.customerName,
    required this.barberName,
    required this.service,
    required this.status,
    required this.waitMinutes,
  });

  bool get isWaiting => status == 'waiting';
  bool get isServing => status == 'serving';
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
