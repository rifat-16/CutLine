import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/shared/services/firestore_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class BarberHomeProvider extends ChangeNotifier {
  BarberHomeProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _queueSubscription;

  bool _isLoading = false;
  String? _error;
  BarberProfile? _profile;
  List<BarberQueueItem> _queue = [];
  bool _salonOpen = false;
  bool _isAvailable = true;
  bool _isUpdatingAvailability = false;
  String? _salonName;
  int _todayTips = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  BarberProfile? get profile => _profile;
  List<BarberQueueItem> get queue => _queue;
  bool get isSalonOpen => _salonOpen;
  bool get isAvailable => _isAvailable;
  bool get isUpdatingAvailability => _isUpdatingAvailability;
  String? get salonName => _salonName;
  int get todayTips => _todayTips;

  int get waitingCount => _countStatus(BarberQueueStatus.waiting);
  int get servingCount => _countStatus(BarberQueueStatus.serving);
  int get completedCount => _countStatus(BarberQueueStatus.done);

  Future<void> load() async {
    final uid = _authProvider.currentUser?.uid;
    if (uid == null) {
      _setError('Please log in again.');
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      // Verify user document exists and has barber role
      try {
        final userDoc = await FirestoreCache.getDoc(
            _firestore.collection('users').doc(uid));
        if (!userDoc.exists) {
          _setError('User profile not found. Please contact the salon owner.');
          _setLoading(false);
          return;
        }
        final userData = userDoc.data();
        final userRole = userData?['role'] as String?;
        if (userRole != 'barber') {
          _setError('You do not have barber permissions.');
          _setLoading(false);
          return;
        }
        _profile = _profileFromUserData(uid, userData);
      } catch (e, stackTrace) {
        if (e is FirebaseException && e.code == 'permission-denied') {
          _setError(
              'Permission denied. Please check Firestore rules are deployed.');
          _setLoading(false);
          return;
        }
      }

      final profile = _profile;
      if (profile == null) {
        _setError(
            'Could not load your profile. Please contact the salon owner.');
        _setLoading(false);
        return;
      }

      await _loadSalonMeta(profile.ownerId);
      _todayTips = await _loadTodayTips(profile);

      try {
        _isAvailable = await _fetchAvailability(profile);
      } catch (e) {
        _isAvailable = true; // Default to available
      }

      if (_salonOpen) {
        _startQueueListener(profile);
      } else {
        _queue = [];
      }
    } catch (e, stackTrace) {
      String errorMessage = 'Failed to load data. Pull to refresh.';
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

  BarberProfile? _profileFromUserData(String uid, Map<String, dynamic>? data) {
    if (data == null) return null;
    final ownerId = data['ownerId'] as String?;
    if (ownerId == null || ownerId.isEmpty) {
      return null;
    }
    return BarberProfile(
      uid: uid,
      ownerId: ownerId,
      name: (data['name'] as String?) ?? '',
      photoUrl: (data['photoUrl'] as String?) ?? '',
    );
  }

  void _startQueueListener(BarberProfile profile) {
    _queueSubscription?.cancel();
    try {
      final queueRef = _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('queue');
      final activeStatuses = [
        'waiting',
        'serving',
        'turn_ready',
        'arrived',
        'done',
        'completed',
      ];

      _queueSubscription = queueRef
          .where('status', whereIn: activeStatuses)
          .snapshots()
          .listen((snapshot) {
        _queue = snapshot.docs
            .where((doc) => _matchesBarber(doc.data(), profile))
            .map((doc) => _mapQueue(doc.id, doc.data(), profile))
            .whereType<BarberQueueItem>()
            .toList()
          ..sort((a, b) => a.waitMinutes.compareTo(b.waitMinutes));
        notifyListeners();
      }, onError: (_) {
        _setError('Failed to load queue. Pull to refresh.');
      });
    } catch (e) {
      _setError('Failed to load queue. Pull to refresh.');
    }
  }

  Future<int> _loadTodayTips(BarberProfile profile) async {
    final today = DateTime.now();
    final todayKey = DateFormat('yyyy-MM-dd')
        .format(DateTime(today.year, today.month, today.day));
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      final collection = _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('bookings');
      try {
        snap = await collection
            .where('status', whereIn: ['completed', 'done']).get();
      } catch (_) {
        snap = await collection.get();
      }

      int total = 0;
      for (final doc in snap.docs) {
        final data = doc.data();
        if (!_matchesBarber(data, profile)) continue;
        final status = (data['status'] as String?)?.toLowerCase() ?? '';
        if (status != 'completed' && status != 'done') continue;
        if (!_isTodayBooking(data, todayKey, today)) continue;
        final tip = (data['tipAmount'] as num?)?.toInt() ?? 0;
        total += tip;
      }
      return total;
    } catch (_) {
      return 0;
    }
  }

  bool _matchesBarber(Map<String, dynamic> data, BarberProfile profile) {
    final barberId = data['barberId'] ?? data['barberUid'];
    if (barberId is String && barberId == profile.uid) return true;
    final barberName =
        (data['barberName'] as String?) ?? (data['barber'] as String?);
    if (barberName != null &&
        profile.name.isNotEmpty &&
        barberName.toLowerCase() == profile.name.toLowerCase()) {
      return true;
    }
    return false;
  }

  bool _isTodayBooking(
      Map<String, dynamic> data, String todayKey, DateTime today) {
    final dateStr = (data['date'] as String?)?.trim();
    if (dateStr != null && dateStr == todayKey) return true;
    final completedAt = data['completedAt'];
    if (completedAt is Timestamp) {
      final dt = completedAt.toDate();
      return dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day;
    }
    final dateTime = data['dateTime'];
    if (dateTime is Timestamp) {
      final dt = dateTime.toDate();
      return dt.year == today.year &&
          dt.month == today.month &&
          dt.day == today.day;
    }
    return false;
  }

  BarberQueueItem? _mapQueue(
      String id, Map<String, dynamic> data, BarberProfile profile) {
    final status = _statusFromString((data['status'] as String?) ?? 'waiting');
    DateTime? startedAt;
    DateTime? completedAt;
    if (data['startedAt'] != null) {
      final ts = data['startedAt'];
      if (ts is Timestamp) {
        startedAt = ts.toDate();
      }
    }
    if (data['completedAt'] != null) {
      final ts = data['completedAt'];
      if (ts is Timestamp) {
        completedAt = ts.toDate();
      }
    }
    final scheduledAt = _parseScheduledAt(data);
    final avatar = (data['customerAvatar'] as String?) ??
        (data['customerPhotoUrl'] as String?) ??
        (data['photoUrl'] as String?) ??
        '';

    return BarberQueueItem(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      service: (data['service'] as String?) ?? 'Service',
      barberName: (data['barberName'] as String?) ?? profile.name,
      price: (data['price'] as num?)?.toInt() ?? 0,
      tipAmount: (data['tipAmount'] as num?)?.toInt() ?? 0,
      status: status,
      waitMinutes: (data['waitMinutes'] as num?)?.toInt() ?? 0,
      slotLabel: (data['slotLabel'] as String?) ?? id,
      customerPhone: (data['customerPhone'] as String?) ?? '',
      note: data['note'] as String?,
      startedAt: startedAt,
      completedAt: completedAt,
      scheduledAt: scheduledAt,
      customerAvatar: avatar,
    );
  }

  Future<void> _loadSalonMeta(String ownerId) async {
    if (ownerId.isEmpty) {
      _salonOpen = false;
      _salonName = null;
      return;
    }
    try {
      final doc = await FirestoreCache.getDoc(
          _firestore.collection('salons').doc(ownerId));
      if (!doc.exists) {
        _salonOpen = false;
        _salonName = null;
        return;
      }
      final data = doc.data() ?? {};
      _salonOpen = (data['isOpen'] as bool?) ?? false;
      _salonName = data['name'] as String?;
    } catch (e) {
      _salonOpen = false;
      _salonName = null;
    }
  }

  Future<bool> _fetchAvailability(BarberProfile profile) async {
    try {
      final doc = await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('barbers')
          .doc(profile.uid)
          .get();
      if (!doc.exists) return true;
      final data = doc.data() ?? {};
      final available = data['isAvailable'];
      if (available is bool) return available;
    } catch (_) {
      // ignore
    }
    return true;
  }

  Future<void> setAvailability(bool value) async {
    final profile = _profile;
    if (profile == null) return;
    final previous = _isAvailable;
    _isAvailable = value;
    _isUpdatingAvailability = true;
    notifyListeners();
    try {
      await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('barbers')
          .doc(profile.uid)
          .set(
        {
          'isAvailable': value,
          'uid': profile.uid,
          'name': profile.name,
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      _isAvailable = previous;
      _setError('Could not update availability.');
    } finally {
      _isUpdatingAvailability = false;
      notifyListeners();
    }
  }

  BarberQueueStatus _statusFromString(String status) {
    switch (status) {
      case 'serving':
        return BarberQueueStatus.serving;
      case 'done':
      case 'completed':
        return BarberQueueStatus.done;
      case 'cancelled':
        return BarberQueueStatus.cancelled;
      default:
        return BarberQueueStatus.waiting;
    }
  }

  Future<void> updateStatus(String id, BarberQueueStatus status) async {
    final profile = _profile;
    if (profile == null) return;
    try {
      final statusString = status == BarberQueueStatus.done
          ? 'completed'
          : (status == BarberQueueStatus.cancelled ? 'cancelled' : status.name);
      final updateData = <String, dynamic>{'status': status.name};

      if (status == BarberQueueStatus.serving) {
        updateData['startedAt'] = FieldValue.serverTimestamp();
      } else if (status == BarberQueueStatus.done) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      } else if (status == BarberQueueStatus.cancelled) {
        updateData['cancelledAt'] = FieldValue.serverTimestamp();
      } else if (status == BarberQueueStatus.waiting) {
        updateData['startedAt'] = FieldValue.delete();
        updateData['completedAt'] = FieldValue.delete();
        updateData['cancelledAt'] = FieldValue.delete();
      }

      await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('queue')
          .doc(id)
          .set(updateData, SetOptions(merge: true));
      await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('bookings')
          .doc(id)
          .set({'status': statusString}, SetOptions(merge: true));
      if (status == BarberQueueStatus.done) {
        await _createLedgersForBooking(profile, id);
      }
    } catch (_) {
      // ignore write failures for now
    }
    final index = _queue.indexWhere((item) => item.id == id);
    if (index != -1) {
      final now = DateTime.now();
      _queue[index] = _queue[index].copyWith(
        status: status,
        startedAt: status == BarberQueueStatus.serving
            ? now
            : (status == BarberQueueStatus.waiting
                ? null
                : _queue[index].startedAt),
        completedAt: status == BarberQueueStatus.done
            ? now
            : (status == BarberQueueStatus.waiting
                ? null
                : _queue[index].completedAt),
      );
      notifyListeners();
    }
  }

  Future<void> _createLedgersForBooking(
      BarberProfile profile, String bookingId) async {
    try {
      final bookingSnap = await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('bookings')
          .doc(bookingId)
          .get();
      final data = bookingSnap.data() ?? <String, dynamic>{};
      final salonId = (data['salonId'] as String?) ?? profile.ownerId;
      final tipAmount = (data['tipAmount'] as num?)?.toInt() ?? 0;
      final serviceCharge = (data['serviceCharge'] as num?)?.toInt() ?? 0;
      final barberId = (data['barberId'] as String?) ??
          (data['barberUid'] as String?) ??
          profile.uid;
      final barberName = (data['barberName'] as String?) ?? profile.name;
      final completedAt = data['completedAt'];

      if (tipAmount > 0) {
        await _firestore.collection('barber_tip_ledger').doc(bookingId).set(
          {
            'bookingId': bookingId,
            'salonId': salonId,
            'barberId': barberId,
            'barberName': barberName,
            'tipAmount': tipAmount,
            'status': 'unpaid',
            'createdAt': FieldValue.serverTimestamp(),
            if (completedAt is Timestamp) 'completedAt': completedAt,
          },
          SetOptions(merge: true),
        );
      }

      if (serviceCharge > 0) {
        await _firestore.collection('platform_fee_ledger').doc(bookingId).set(
          {
            'bookingId': bookingId,
            'salonId': salonId,
            'feeAmount': serviceCharge,
            'status': 'unpaid',
            'createdAt': FieldValue.serverTimestamp(),
            if (completedAt is Timestamp) 'completedAt': completedAt,
          },
          SetOptions(merge: true),
        );
      }
    } catch (_) {
      // ignore ledger failures
    }
  }

  int _countStatus(BarberQueueStatus status) {
    return _queue.where((item) => item.status == status).length;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  DateTime? _parseScheduledAt(Map<String, dynamic> data) {
    final ts = data['dateTime'];
    if (ts is Timestamp) return ts.toDate();

    final dateStr = (data['date'] as String?)?.trim() ?? '';
    final timeStr = ((data['time'] as String?) ??
                (data['bookingTime'] as String?) ??
                (data['slotLabel'] as String?))
            ?.trim() ??
        '';
    if (dateStr.isEmpty || timeStr.isEmpty) return null;

    try {
      final date = DateTime.parse(dateStr);
      final time = DateFormat('h:mm a').parse(timeStr);
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }
}

class BarberProfile {
  final String uid;
  final String ownerId;
  final String name;
  final String photoUrl;

  const BarberProfile({
    required this.uid,
    required this.ownerId,
    required this.name,
    required this.photoUrl,
  });
}

class BarberQueueItem {
  final String id;
  final String customerName;
  final String service;
  final String barberName;
  final int price;
  final int tipAmount;
  final BarberQueueStatus status;
  final int waitMinutes;
  final String slotLabel;
  final String customerPhone;
  final String? note;
  final String customerAvatar;
  final DateTime? scheduledAt;
  final DateTime? startedAt;
  final DateTime? completedAt;

  const BarberQueueItem({
    required this.id,
    required this.customerName,
    required this.service,
    required this.barberName,
    required this.price,
    required this.tipAmount,
    required this.status,
    required this.waitMinutes,
    required this.slotLabel,
    required this.customerPhone,
    required this.customerAvatar,
    this.scheduledAt,
    this.note,
    this.startedAt,
    this.completedAt,
  });

  BarberQueueItem copyWith({
    BarberQueueStatus? status,
    DateTime? startedAt,
    DateTime? completedAt,
    String? customerAvatar,
    DateTime? scheduledAt,
  }) {
    return BarberQueueItem(
      id: id,
      customerName: customerName,
      service: service,
      barberName: barberName,
      price: price,
      tipAmount: tipAmount,
      status: status ?? this.status,
      waitMinutes: waitMinutes,
      slotLabel: slotLabel,
      customerPhone: customerPhone,
      note: note,
      customerAvatar: customerAvatar ?? this.customerAvatar,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

enum BarberQueueStatus { waiting, serving, done, cancelled }
