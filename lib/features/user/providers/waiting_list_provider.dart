import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WaitingListProvider extends ChangeNotifier {
  WaitingListProvider({this.salonId, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String? salonId;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _queueSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _bookingSubscription;

  bool _isLoading = false;
  String? _error;
  List<WaitingCustomer> _customers = [];
  final Map<String, WaitingCustomer> _queueItems = {};
  final Map<String, WaitingCustomer> _bookingItems = {};
  bool _receivedQueue = false;
  bool _receivedBookings = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<WaitingCustomer> get customers => _customers;

  Future<void> load() async {
    _queueSubscription?.cancel();
    _bookingSubscription?.cancel();
    _queueItems.clear();
    _bookingItems.clear();
    _receivedQueue = false;
    _receivedBookings = false;
    _setLoading(true);
    _setError(null);
    try {
      _queueSubscription = _queueStream().listen((snap) {
        _receivedQueue = true;
        _queueItems
          ..clear()
          ..addEntries(
            snap.docs
                .map((doc) => _map(doc.id, doc.data()))
                .whereType<WaitingCustomer>()
                .map((c) => MapEntry(c.id, c)),
          );
        _rebuild();
        _stopLoadingIfReady();
      }, onError: (_) {
        _setError('Failed to load waiting list.');
        _stopLoadingIfReady();
      });

      _bookingSubscription = _bookingStream().listen((snap) {
        _receivedBookings = true;
        _bookingItems
          ..clear()
          ..addEntries(
            snap.docs
                .map((doc) => _map(doc.id, doc.data()))
                .whereType<WaitingCustomer>()
                .map((c) => MapEntry(c.id, c)),
          );
        _rebuild();
        _stopLoadingIfReady();
      }, onError: (_) {
        _stopLoadingIfReady();
      });
    } catch (_) {
      _customers = [];
      _setError('Failed to load waiting list.');
      _setLoading(false);
    }
  }

  void _rebuild() {
    final Map<String, WaitingCustomer> merged = {};
    merged.addAll(_bookingItems);
    for (final entry in _queueItems.entries) {
      final fallback = merged[entry.key];
      merged[entry.key] = _combine(entry.value, fallback);
    }
    _customers = merged.values
        .where((c) => c.status != WaitingStatus.done)
        .toList()
      ..sort(_compareBySchedule);
    _hydrateAvatars();
  }

  int _compareBySchedule(WaitingCustomer a, WaitingCustomer b) {
    final DateTime? aKey = _sortKeyFor(a);
    final DateTime? bKey = _sortKeyFor(b);
    if (aKey != null && bKey != null) return aKey.compareTo(bKey);
    if (aKey != null) return -1; // scheduled items first
    if (bKey != null) return 1;
    return a.waitMinutes.compareTo(b.waitMinutes);
  }

  DateTime? _sortKeyFor(WaitingCustomer customer) {
    if (customer.dateTime != null) return customer.dateTime;
    return _combineDateAndTime(customer.date, customer.time);
  }

  Future<void> _hydrateAvatars() async {
    final missingUids = _customers
        .where((c) => c.avatar.isEmpty && (c.customerUid?.isNotEmpty == true))
        .map((c) => c.customerUid!)
        .toSet()
        .toList();
    if (missingUids.isEmpty) {
      notifyListeners();
      return;
    }
    final photos = await _fetchUserPhotos(missingUids);
    if (photos.isEmpty) {
      notifyListeners();
      return;
    }
    _customers = _customers.map((c) {
      if (c.avatar.isNotEmpty) return c;
      final url = c.customerUid != null ? photos[c.customerUid!] : null;
      if (url == null || url.isEmpty) return c;
      return c.copyWith(avatar: url);
    }).toList()
      ..sort(_compareBySchedule);
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

  Stream<QuerySnapshot<Map<String, dynamic>>> _queueStream() {
    if (salonId != null && salonId!.isNotEmpty) {
      return _firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .where('status', whereIn: ['waiting', 'serving']).snapshots();
    }
    return _firestore.collectionGroup('queue').snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _bookingStream() {
    if (salonId != null && salonId!.isNotEmpty) {
      return _firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .where('status', whereIn: ['waiting', 'serving']).snapshots();
    }
    return _firestore.collectionGroup('bookings').snapshots();
  }

  WaitingCustomer _combine(WaitingCustomer primary, WaitingCustomer? fallback) {
    if (fallback == null) return primary;
    final bestDate = _preferNonEmptyString(fallback.date, primary.date);
    final bestTime = _preferNonEmptyString(fallback.time, primary.time);
    final bestDateTime = _combineDateAndTime(bestDate, bestTime) ??
        fallback.dateTime ??
        primary.dateTime;
    return primary.copyWith(
      name: primary.name.isNotEmpty ? primary.name : fallback.name,
      barber: primary.barber.isNotEmpty ? primary.barber : fallback.barber,
      service: primary.service.isNotEmpty ? primary.service : fallback.service,
      waitMinutes:
          primary.waitMinutes != 0 ? primary.waitMinutes : fallback.waitMinutes,
      slotLabel:
          primary.slotLabel.isNotEmpty ? primary.slotLabel : fallback.slotLabel,
      date: bestDate,
      time: bestTime,
      dateTime: bestDateTime,
      customerUid: primary.customerUid ?? fallback.customerUid,
      avatar: primary.avatar.isNotEmpty ? primary.avatar : fallback.avatar,
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

  void _stopLoadingIfReady() {
    if (_receivedQueue && _receivedBookings) {
      _setLoading(false);
    }
  }

  WaitingCustomer? _map(String id, Map<String, dynamic> data) {
    final statusString = (data['status'] as String?) ?? 'waiting';
    final status = _statusFromString(statusString);
    final String? rawDate =
        _extractDateString(data['date'] ?? data['bookingDate']);
    final String? rawTime =
        _extractTimeString(data['time'] ?? data['bookingTime']) ??
            _extractSlotTimeString(data['slotLabel']);
    final DateTime? scheduledAt = _parseDateTime(data['dateTime']) ??
        _combineDateAndTime(rawDate, rawTime) ??
        _parseDateTime(data['createdAt']);
    final String serviceLabel = _serviceFrom(data);
    final String avatarUrl = (data['avatar'] as String?) ??
        (data['customerAvatar'] as String?) ??
        (data['photoUrl'] as String?) ??
        '';
    final String? customerUid = (data['customerUid'] as String?)?.trim();
    return WaitingCustomer(
      id: id,
      name: (data['customerName'] as String?) ?? 'Customer',
      barber: (data['barberName'] as String?) ?? '',
      service: serviceLabel,
      waitMinutes: (data['waitMinutes'] as num?)?.toInt() ?? 0,
      status: status,
      avatar: avatarUrl,
      slotLabel: (data['slotLabel'] as String?)?.trim() ?? '',
      date: rawDate,
      time: rawTime,
      dateTime: scheduledAt,
      customerUid: customerUid,
    );
  }

  String? _extractSlotTimeString(dynamic value) {
    if (value is String) {
      final trimmed = _normalizeTimeString(value);
      if (trimmed.isEmpty) return null;
      try {
        DateFormat('h:mm a', 'en_US').parse(trimmed);
        return trimmed;
      } catch (_) {
        return null;
      }
    }
    if (value is Timestamp) {
      return DateFormat('h:mm a').format(value.toDate());
    }
    return null;
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

  WaitingStatus _statusFromString(String status) {
    switch (status) {
      case 'serving':
      case 'serving soon':
        return WaitingStatus.servingSoon;
      case 'done':
      case 'completed':
        return WaitingStatus.done;
      default:
        return WaitingStatus.waiting;
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
    _queueSubscription?.cancel();
    _bookingSubscription?.cancel();
    super.dispose();
  }
}

class WaitingCustomer {
  final String id;
  final String name;
  final String barber;
  final String service;
  final int waitMinutes;
  final WaitingStatus status;
  final String avatar;
  final String slotLabel;
  final String? date;
  final String? time;
  final DateTime? dateTime;
  final String? customerUid;

  const WaitingCustomer({
    required this.id,
    required this.name,
    required this.barber,
    required this.service,
    required this.waitMinutes,
    required this.status,
    required this.avatar,
    required this.slotLabel,
    this.date,
    this.time,
    this.dateTime,
    this.customerUid,
  });

  String get scheduleLabel {
    final dateLabel = _formattedDate;
    final timeLabel = _formattedTime;
    if (dateLabel != null &&
        dateLabel.isNotEmpty &&
        timeLabel != null &&
        timeLabel.isNotEmpty) {
      return '$dateLabel, $timeLabel';
    }
    if (dateLabel != null && dateLabel.isNotEmpty) return dateLabel;
    if (timeLabel != null && timeLabel.isNotEmpty) return timeLabel;
    return 'Schedule not set';
  }

  String get dateLabel => _formattedDate ?? 'Date not set';

  String get timeLabel => _formattedTime ?? 'Time not set';

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
    if (slotLabel.isNotEmpty) return slotLabel;
    return null;
  }

  WaitingCustomer copyWith({
    String? name,
    String? barber,
    String? service,
    int? waitMinutes,
    WaitingStatus? status,
    String? avatar,
    String? slotLabel,
    String? date,
    String? time,
    DateTime? dateTime,
    String? customerUid,
  }) {
    return WaitingCustomer(
      id: id,
      name: name ?? this.name,
      barber: barber ?? this.barber,
      service: service ?? this.service,
      waitMinutes: waitMinutes ?? this.waitMinutes,
      status: status ?? this.status,
      avatar: avatar ?? this.avatar,
      slotLabel: slotLabel ?? this.slotLabel,
      date: date ?? this.date,
      time: time ?? this.time,
      dateTime: dateTime ?? this.dateTime,
      customerUid: customerUid ?? this.customerUid,
    );
  }
}

enum WaitingStatus { waiting, servingSoon, done }
