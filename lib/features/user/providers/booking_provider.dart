import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  Future<void> loadBookedSlots(DateTime date) async {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    try {
      final snap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .where('date', isEqualTo: formattedDate)
          .get();
      _bookedSlots = snap.docs
          .map((doc) => (doc.data()['time'] as String?) ?? '')
          .where((slot) => slot.isNotEmpty)
          .toList();
    } catch (_) {
      _bookedSlots = [];
    }
    notifyListeners();
  }

  Future<void> _loadSalon() async {
    try {
      final doc = await _firestore.collection('salons').doc(salonId).get();
      final data = doc.data() ?? {};
      _services = _parseServices(data['services']);
      _barbers = await _loadBarbers(data);
      _currentWaiting = await _estimateWaiting();
      _address = (data['address'] as String?) ?? '';
      _rating = (data['rating'] as num?)?.toDouble() ?? 4.6;
      _workingHours = _normalizeWorkingHours(data['workingHours']);
      _workingHoursLabel = _formatWorkingHours(_workingHours);
      _coverImageUrl =
          (data['coverImageUrl'] as String?) ?? (data['coverPhoto'] as String?);
    } catch (_) {
      _services = [];
      _barbers = [];
      _currentWaiting = 0;
    }
  }

  List<BookingService> _parseServices(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((e) {
      final map = e.cast<String, dynamic>();
      return BookingService(
        name: (map['name'] as String?) ?? 'Service',
        price: (map['price'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  Future<List<BookingBarber>> _loadBarbers(Map<String, dynamic> salonData) async {
    try {
      final snap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('barbers')
          .get();
      final barbers = snap.docs.map((doc) {
        final data = doc.data();
        return BookingBarber(
          id: doc.id,
          name: (data['name'] as String?) ?? 'Barber',
          rating: (data['rating'] as num?)?.toDouble() ?? 4.8,
          avatarUrl: (data['avatarUrl'] as String?) ??
              (data['photoUrl'] as String?),
          uid: (data['uid'] as String?) ?? doc.id,
        );
      }).toList();
      
      // Hydrate avatars from users collection if needed
      final hydratedBarbers = await _hydrateBarberAvatars(barbers);
      
      if (hydratedBarbers.isNotEmpty) return hydratedBarbers;

      final embedded = salonData['barbers'];
      if (embedded is List) {
        final embeddedBarbers = embedded
            .whereType<Map>()
            .map((e) => BookingBarber(
                  id: (e['uid'] as String?) ?? '',
                  name: (e['name'] as String?) ?? 'Barber',
                  rating: (e['rating'] as num?)?.toDouble() ?? 4.8,
                  avatarUrl: (e['avatarUrl'] as String?) ??
                      (e['photoUrl'] as String?),
                  uid: (e['uid'] as String?) ?? '',
                ))
            .toList();
        final hydratedEmbedded = await _hydrateBarberAvatars(embeddedBarbers);
        return hydratedEmbedded;
      }
      return const [];
    } catch (_) {
      return [];
    }
  }

  Future<List<BookingBarber>> _hydrateBarberAvatars(List<BookingBarber> barbers) async {
    final missing = barbers
        .where((b) => (b.avatarUrl == null || b.avatarUrl!.isEmpty) && b.uid.isNotEmpty)
        .map((b) => b.uid)
        .toSet()
        .toList();
    if (missing.isEmpty) return barbers;

    final avatarMap = <String, String>{};
    const int chunkSize = 10;
    for (var i = 0; i < missing.length; i += chunkSize) {
      final chunk = missing.skip(i).take(chunkSize).toList();
      try {
        final snap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();
        for (final doc in snap.docs) {
          final data = doc.data();
          final url = (data['photoUrl'] as String?) ??
              (data['avatarUrl'] as String?);
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
          );
        }
      }
      return barber;
    }).toList();
  }

  Future<int> _estimateWaiting() async {
    try {
      final snap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .where('status', isEqualTo: 'waiting')
          .get();
      return snap.size;
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

  const BookingService({required this.name, required this.price});
}

class BookingBarber {
  final String id;
  final String name;
  final double rating;
  final String? avatarUrl;
  final String uid;

  const BookingBarber({
    required this.id,
    required this.name,
    required this.rating,
    required this.avatarUrl,
    required this.uid,
  });
}
