import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cutline/shared/services/firestore_cache.dart';
import 'package:cutline/shared/services/local_ttl_cache.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingSummaryProvider extends ChangeNotifier {
  BookingSummaryProvider({
    required this.salonId,
    required this.salonName,
    required this.selectedServices,
    required this.selectedBarber,
    this.selectedBarberId = '',
    this.selectedBarberAvatar,
    required this.selectedDate,
    required this.selectedTime,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    this.customerUid = '',
    this.bookingMode = 'custom',
    this.predictedSerialNo,
    this.predictedStartAt,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String salonId;
  final String salonName;
  final List<String> selectedServices;
  final String selectedBarber;
  final String selectedBarberId;
  final String? selectedBarberAvatar;
  final DateTime selectedDate;
  final String selectedTime;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerUid;
  final String bookingMode;
  final int? predictedSerialNo;
  final DateTime? predictedStartAt;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String _address = '';
  String _contact = '';
  double _rating = 4.6;
  String _salonEmail = '';
  int _serviceCharge = 0;
  String? _coverImageUrl;
  String? _customerAvatar;
  List<BookingSummaryService> _services = [];
  int? _lastCreatedSerialNo;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get address => _address;
  String get contact => _contact;
  double get rating => _rating;
  String get salonEmail => _salonEmail;
  List<BookingSummaryService> get services => _services;
  bool get isSaving => _isSaving;
  String get barberName => selectedBarber;
  int get serviceCharge => _serviceCharge;
  bool get isNextFreeMode => bookingMode == 'next_free';
  int? get lastCreatedSerialNo => _lastCreatedSerialNo;

  int get serviceTotal => _services.fold(0, (acc, item) => acc + item.price);
  int get totalDurationMinutes {
    if (_services.isEmpty && selectedServices.isNotEmpty) {
      return selectedServices.length * 30;
    }
    return _services.fold(
      0,
      (acc, item) =>
          acc + (item.durationMinutes > 0 ? item.durationMinutes : 30),
    );
  }

  int get total => serviceTotal + serviceCharge;
  String get formattedDate => DateFormat('dd MMM yyyy').format(selectedDate);
  String get dateKey => DateFormat('yyyy-MM-dd').format(selectedDate);

  String formatDateTime(DateTime dateTime) {
    return DateFormat('dd MMM yyyy, h:mm a').format(dateTime);
  }

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    try {
      final doc = await FirestoreCache.getDocCacheFirst(
        _firestore.collection('salons').doc(salonId),
      );
      final data = doc.data() ?? {};
      _address = (data['address'] as String?) ?? '';
      _contact = (data['contact'] as String?) ?? '';
      _salonEmail = ((data['email'] as String?) ??
                  (data['ownerEmail'] as String?) ??
                  (data['contactEmail'] as String?))
              ?.trim() ??
          '';
      _rating = (data['rating'] as num?)?.toDouble() ?? 4.6;
      _coverImageUrl =
          (data['coverImageUrl'] as String?) ?? (data['coverPhoto'] as String?);
      if (customerUid.isNotEmpty) {
        try {
          final userDoc = await FirestoreCache.getDocCacheFirst(
            _firestore.collection('users').doc(customerUid),
          );
          final userData = userDoc.data() ?? {};
          final avatar = (userData['photoUrl'] as String?) ??
              (userData['avatarUrl'] as String?) ??
              (userData['coverPhoto'] as String?);
          if (avatar != null && avatar.trim().isNotEmpty) {
            _customerAvatar = avatar.trim();
          }
        } catch (_) {
          // ignore avatar lookup failures
        }
      }
      _services = await _loadServices();
      _serviceCharge = await _loadPlatformFee();
    } catch (_) {
      _services = [];
      _serviceCharge = 0;
      _setError('Could not load booking summary.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveBooking(String paymentMethod, {int tipAmount = 0}) async {
    _isSaving = true;
    _lastCreatedSerialNo = null;
    _setError(null);
    notifyListeners();
    final resolvedCustomerUid = _resolvedCustomerUid();
    if (resolvedCustomerUid.isEmpty) {
      _isSaving = false;
      _setError('Please sign in and try again.');
      return false;
    }
    try {
      final success = isNextFreeMode
          ? await _saveNextFreeBooking(
              paymentMethod,
              tipAmount: tipAmount,
              resolvedCustomerUid: resolvedCustomerUid,
            )
          : await _saveCustomBooking(
              paymentMethod,
              tipAmount: tipAmount,
              resolvedCustomerUid: resolvedCustomerUid,
            );
      _isSaving = false;
      notifyListeners();
      return success;
    } on FirebaseException catch (e) {
      _isSaving = false;
      _setError(_mapSaveError(e));
      return false;
    } catch (_) {
      _isSaving = false;
      _setError('Could not confirm booking. Try again.');
      return false;
    }
  }

  Future<bool> _saveCustomBooking(
    String paymentMethod, {
    required int tipAmount,
    required String resolvedCustomerUid,
  }) async {
    final exists = await _bookingExists();
    if (exists) {
      _setError('This time slot is already booked. Please choose another.');
      return false;
    }

    final totalWithTip = total + tipAmount;
    final scheduledAt = _buildScheduledAt();
    final bookingRef = _firestore
        .collection('salons')
        .doc(salonId)
        .collection('bookings')
        .doc();

    final data = {
      ..._baseBookingPayload(
        paymentMethod: paymentMethod,
        tipAmount: tipAmount,
        totalWithTip: totalWithTip,
        resolvedCustomerUid: resolvedCustomerUid,
      ),
      'date': dateKey,
      'time': selectedTime,
      if (scheduledAt != null) 'dateTime': scheduledAt,
      'status': 'upcoming',
      'entrySource': 'app',
      'bookingMode': 'custom',
    };

    await bookingRef.set(data, SetOptions(merge: true));
    await _writeUserBookingMirror(
      bookingId: bookingRef.id,
      date: dateKey,
      time: selectedTime,
      scheduledAt: scheduledAt,
      status: 'upcoming',
      bookingMode: 'custom',
      serialNo: null,
      serialDate: null,
      serialBarberKey: null,
      resolvedCustomerUid: resolvedCustomerUid,
    );
    return true;
  }

  Future<bool> _saveNextFreeBooking(
    String paymentMethod, {
    required int tipAmount,
    required String resolvedCustomerUid,
  }) async {
    final placement = await _computeNextFreePlacement();
    final now = DateTime.now();
    final estimatedStart = placement.estimatedStart;
    final date = DateFormat('yyyy-MM-dd').format(estimatedStart);
    final time = DateFormat('h:mm a').format(estimatedStart);
    final serialDate = DateFormat('yyyy-MM-dd').format(now);
    final serialBarberKey = _serialBarberKey();
    final totalWithTip = total + tipAmount;
    final serviceLabel = _serviceLabel();
    final bookingRef = _firestore
        .collection('salons')
        .doc(salonId)
        .collection('bookings')
        .doc();
    final queueRef = _firestore
        .collection('salons')
        .doc(salonId)
        .collection('queue')
        .doc(bookingRef.id);

    final bookingPayload = {
      ..._baseBookingPayload(
        paymentMethod: paymentMethod,
        tipAmount: tipAmount,
        totalWithTip: totalWithTip,
        resolvedCustomerUid: resolvedCustomerUid,
      ),
      'date': date,
      'time': time,
      'dateTime': Timestamp.fromDate(estimatedStart),
      'status': 'waiting',
      'waitMinutes': totalDurationMinutes,
      'entrySource': 'app',
      'bookingMode': 'next_free',
      'createdByUid': resolvedCustomerUid,
      'createdByRole': 'customer',
      'serialNo': placement.nextSerial,
      'serialDate': serialDate,
      'serialBarberKey': serialBarberKey,
      'slotLabel': '#${placement.nextSerial}',
    };

    final queuePayload = {
      'salonId': salonId,
      'customerUid': resolvedCustomerUid,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      if (_customerAvatar != null && _customerAvatar!.isNotEmpty)
        'customerAvatar': _customerAvatar,
      'barberName': selectedBarber,
      if (selectedBarberId.trim().isNotEmpty) 'barberId': selectedBarberId,
      if (selectedBarberAvatar != null &&
          selectedBarberAvatar!.trim().isNotEmpty)
        'barberAvatar': selectedBarberAvatar,
      'services': _serviceEntries(),
      'service': serviceLabel,
      'price': serviceTotal,
      'total': totalWithTip,
      'tipAmount': tipAmount,
      'serviceCharge': serviceCharge,
      'waitMinutes': totalDurationMinutes,
      'durationMinutes': totalDurationMinutes,
      'date': date,
      'time': time,
      'dateTime': Timestamp.fromDate(estimatedStart),
      'slotLabel': '#${placement.nextSerial}',
      'status': 'waiting',
      'entrySource': 'app',
      'bookingMode': 'next_free',
      'createdByUid': resolvedCustomerUid,
      'createdByRole': 'customer',
      'serialNo': placement.nextSerial,
      'serialDate': serialDate,
      'serialBarberKey': serialBarberKey,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };

    final batch = _firestore.batch();
    batch.set(bookingRef, bookingPayload, SetOptions(merge: true));
    batch.set(queueRef, queuePayload, SetOptions(merge: true));
    if (resolvedCustomerUid.isNotEmpty) {
      final userRef = _firestore.collection('users').doc(resolvedCustomerUid);
      batch.set(
        userRef,
        {
          'activeBookingIds': FieldValue.arrayUnion([bookingRef.id]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      final userBookingRef = userRef.collection('bookings').doc(bookingRef.id);
      batch.set(
        userBookingRef,
        {
          'salonId': salonId,
          'salonName': salonName,
          'services': _serviceNames(),
          'barberName': selectedBarber,
          if (selectedBarberId.trim().isNotEmpty) 'barberId': selectedBarberId,
          if (selectedBarberAvatar != null &&
              selectedBarberAvatar!.trim().isNotEmpty)
            'barberAvatar': selectedBarberAvatar,
          'date': date,
          'time': time,
          'dateTime': Timestamp.fromDate(estimatedStart),
          'status': 'waiting',
          'bookingMode': 'next_free',
          'entrySource': 'app',
          'serialNo': placement.nextSerial,
          'serialDate': serialDate,
          'serialBarberKey': serialBarberKey,
          'customerUid': resolvedCustomerUid,
          'customerEmail': customerEmail,
          'customerPhone': customerPhone,
          if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty)
            'coverImageUrl': _coverImageUrl,
          if (_customerAvatar != null && _customerAvatar!.isNotEmpty)
            'customerAvatar': _customerAvatar,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    _lastCreatedSerialNo = placement.nextSerial;
    return true;
  }

  Map<String, dynamic> _baseBookingPayload({
    required String paymentMethod,
    required int tipAmount,
    required int totalWithTip,
    required String resolvedCustomerUid,
  }) {
    return {
      'salonId': salonId,
      'salonName': salonName,
      'userId': resolvedCustomerUid,
      'customerUid': resolvedCustomerUid,
      'services': _serviceEntries(),
      'barberName': selectedBarber,
      if (selectedBarberId.trim().isNotEmpty) 'barberId': selectedBarberId,
      if (selectedBarberAvatar != null &&
          selectedBarberAvatar!.trim().isNotEmpty)
        'barberAvatar': selectedBarberAvatar,
      'paymentMethod': paymentMethod,
      'tipAmount': tipAmount,
      'total': totalWithTip,
      'durationMinutes': totalDurationMinutes,
      'serviceCharge': serviceCharge,
      'address': _address,
      'contact': _contact,
      'email': _salonEmail,
      'salonEmail': _salonEmail,
      'salonContact': _contact,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerEmail': customerEmail,
      if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty)
        'coverImageUrl': _coverImageUrl,
      if (_customerAvatar != null && _customerAvatar!.isNotEmpty)
        'customerAvatar': _customerAvatar,
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  List<Map<String, dynamic>> _serviceEntries() {
    return _services
        .map((s) => {
              'name': s.name,
              'price': s.price,
              'durationMinutes': s.durationMinutes,
            })
        .toList();
  }

  List<String> _serviceNames() {
    return _services
        .map((s) => s.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
  }

  String _serviceLabel() {
    final names = _serviceNames();
    if (names.isEmpty) return 'Service';
    return names.join(', ');
  }

  Future<void> _writeUserBookingMirror({
    required String bookingId,
    required String date,
    required String time,
    required Timestamp? scheduledAt,
    required String status,
    required String bookingMode,
    required int? serialNo,
    required String? serialDate,
    required String? serialBarberKey,
    required String resolvedCustomerUid,
  }) async {
    if (resolvedCustomerUid.isEmpty) return;
    await _firestore.collection('users').doc(resolvedCustomerUid).set(
      {
        'activeBookingIds': FieldValue.arrayUnion([bookingId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    final userBookingRef = _firestore
        .collection('users')
        .doc(resolvedCustomerUid)
        .collection('bookings')
        .doc(bookingId);
    await userBookingRef.set({
      'salonId': salonId,
      'salonName': salonName,
      'services': _serviceNames(),
      'barberName': selectedBarber,
      if (selectedBarberId.trim().isNotEmpty) 'barberId': selectedBarberId,
      if (selectedBarberAvatar != null &&
          selectedBarberAvatar!.trim().isNotEmpty)
        'barberAvatar': selectedBarberAvatar,
      'date': date,
      'time': time,
      if (scheduledAt != null) 'dateTime': scheduledAt,
      'status': status,
      'bookingMode': bookingMode,
      'entrySource': 'app',
      if (serialNo != null) 'serialNo': serialNo,
      if (serialDate != null && serialDate.isNotEmpty) 'serialDate': serialDate,
      if (serialBarberKey != null && serialBarberKey.isNotEmpty)
        'serialBarberKey': serialBarberKey,
      'customerUid': resolvedCustomerUid,
      'customerEmail': customerEmail,
      'customerPhone': customerPhone,
      if (_coverImageUrl != null && _coverImageUrl!.isNotEmpty)
        'coverImageUrl': _coverImageUrl,
      if (_customerAvatar != null && _customerAvatar!.isNotEmpty)
        'customerAvatar': _customerAvatar,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<_NextFreePlacement> _computeNextFreePlacement() async {
    const activeStatuses = {'serving', 'waiting', 'arrived'};
    QuerySnapshot<Map<String, dynamic>> snapshot;
    try {
      snapshot = await FirestoreCache.getQuery(_firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .where('status', whereIn: activeStatuses.toList())
          .limit(400));
    } catch (_) {
      snapshot = await FirestoreCache.getQuery(_firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .limit(700));
    }

    int activeCount = 0;
    int maxSerial = 0;
    int aheadWaitMinutes = 0;
    for (final doc in snapshot.docs) {
      final data = doc.data();
      final status = (data['status'] as String?)?.trim().toLowerCase() ?? '';
      if (!activeStatuses.contains(status)) continue;
      if (!_matchesSelectedBarber(data)) continue;
      activeCount += 1;
      final waitMinutes = (data['waitMinutes'] as num?)?.toInt() ?? 0;
      aheadWaitMinutes += waitMinutes > 0 ? waitMinutes : 30;
      final serialNo = (data['serialNo'] as num?)?.toInt() ?? 0;
      if (serialNo > maxSerial) maxSerial = serialNo;
    }
    final nextSerial = maxSerial > 0 ? maxSerial + 1 : activeCount + 1;
    final estimatedStart =
        DateTime.now().add(Duration(minutes: aheadWaitMinutes));
    return _NextFreePlacement(
      nextSerial: nextSerial,
      estimatedStart: estimatedStart,
    );
  }

  bool _matchesSelectedBarber(Map<String, dynamic> data) {
    final targetBarberId = selectedBarberId.trim().toLowerCase();
    final targetBarberName = selectedBarber.trim().toLowerCase();
    final bookingBarberId =
        ((data['barberId'] as String?) ?? (data['barberUid'] as String?) ?? '')
            .trim()
            .toLowerCase();
    if (targetBarberId.isNotEmpty && bookingBarberId == targetBarberId) {
      return true;
    }
    final bookingBarberName =
        ((data['barberName'] as String?) ?? (data['barber'] as String?) ?? '')
            .trim()
            .toLowerCase();
    return targetBarberName.isNotEmpty && bookingBarberName == targetBarberName;
  }

  String _serialBarberKey() {
    final raw =
        selectedBarberId.trim().isNotEmpty ? selectedBarberId : selectedBarber;
    final normalized = raw
        .trim()
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    return normalized.isNotEmpty ? normalized : 'unassigned';
  }

  Future<bool> _bookingExists() async {
    try {
      final snap = await FirestoreCache.getQuery(_firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .where('date', isEqualTo: dateKey)
          .where('time', isEqualTo: selectedTime));
      final normalizedBarber = selectedBarber.trim().toLowerCase();
      for (final doc in snap.docs) {
        final data = doc.data();
        final status = (data['status'] as String?)?.trim().toLowerCase() ?? '';
        if (status == 'cancelled' ||
            status == 'canceled' ||
            status == 'no_show' ||
            status == 'rejected') {
          continue;
        }
        final bookingBarber =
            (data['barberName'] as String?)?.trim().toLowerCase() ?? '';
        if (bookingBarber == normalizedBarber) return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<List<BookingSummaryService>> _loadServices() async {
    try {
      final query = _firestore
          .collection('salons')
          .doc(salonId)
          .collection('all_services')
          .orderBy('order');
      final snap = await FirestoreCache.getQueryCacheFirst(query);
      final mapped = _mapServices(snap.docs, selectedServices);
      if (mapped.isNotEmpty) return mapped;
    } catch (_) {
      // fall through to fallback
    }
    try {
      final snap = await FirestoreCache.getQueryCacheFirst(_firestore
          .collection('salons')
          .doc(salonId)
          .collection('all_services'));
      return _mapServices(snap.docs, selectedServices);
    } catch (_) {
      return [];
    }
  }

  Timestamp? _buildScheduledAt() {
    try {
      final parsedTime = DateFormat('h:mm a').parse(selectedTime);
      final dt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        parsedTime.hour,
        parsedTime.minute,
      );
      return Timestamp.fromDate(dt);
    } catch (_) {
      return null;
    }
  }

  Future<int> _loadPlatformFee() async {
    try {
      final cached = await LocalTtlCache.get<int>('platform_fee_v1');
      if (cached != null) return cached;
      final snap = await FirestoreCache.getQueryCacheFirst(
        _firestore.collection('platform_fee').limit(1),
      );
      if (snap.docs.isEmpty) {
        await LocalTtlCache.set(
          'platform_fee_v1',
          0,
          const Duration(hours: 24),
        );
        return 0;
      }
      final data = snap.docs.first.data();
      final raw = data['fee'];
      if (raw == null) {
        await LocalTtlCache.set(
          'platform_fee_v1',
          0,
          const Duration(hours: 24),
        );
        return 0;
      }
      if (raw is num) {
        final fee = raw.toInt();
        await LocalTtlCache.set(
          'platform_fee_v1',
          fee,
          const Duration(hours: 24),
        );
        return fee;
      }
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized.isEmpty || normalized == 'free') {
          await LocalTtlCache.set(
            'platform_fee_v1',
            0,
            const Duration(hours: 24),
          );
          return 0;
        }
        final parsed = int.tryParse(normalized);
        if (parsed != null) {
          await LocalTtlCache.set(
            'platform_fee_v1',
            parsed,
            const Duration(hours: 24),
          );
          return parsed;
        }
        final digits = RegExp(r'\d+').stringMatch(normalized);
        final parsedDigits = digits != null ? int.tryParse(digits) ?? 0 : 0;
        await LocalTtlCache.set(
          'platform_fee_v1',
          parsedDigits,
          const Duration(hours: 24),
        );
        return parsedDigits;
      }
      await LocalTtlCache.set(
        'platform_fee_v1',
        0,
        const Duration(hours: 24),
      );
      return 0;
    } catch (_) {
      return 0;
    }
  }

  List<BookingSummaryService> _mapServices(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
      List<String> selected) {
    final List<BookingSummaryService> mapped = [];
    final Map<String, int> priceLookup = {};
    final Map<String, int> durationLookup = {};
    for (final doc in docs) {
      final item = doc.data();
      final name = (item['name'] as String?)?.trim() ?? '';
      if (name.isEmpty) continue;
      priceLookup[name] = (item['price'] as num?)?.toInt() ?? 0;
      durationLookup[name] = (item['durationMinutes'] as num?)?.toInt() ?? 30;
    }
    for (final name in selected) {
      final trimmed = name.trim();
      final price = priceLookup[trimmed] ?? 0;
      final duration = durationLookup[trimmed] ?? (trimmed.isNotEmpty ? 30 : 0);
      mapped.add(BookingSummaryService(
        name: trimmed,
        price: price,
        durationMinutes: duration,
      ));
    }
    return mapped;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  String _resolvedCustomerUid() {
    final provided = customerUid.trim();
    if (provided.isNotEmpty) return provided;
    final liveUser = FirebaseAuth.instance.currentUser;
    final liveUid = liveUser == null ? '' : liveUser.uid.trim();
    return liveUid;
  }

  String _mapSaveError(FirebaseException e) {
    if (e.code == 'permission-denied') {
      return 'Permission denied while confirming booking. Please sign in again or deploy latest Firestore rules.';
    }
    if (e.code == 'unauthenticated') {
      return 'Please sign in and try again.';
    }
    return 'Could not confirm booking. Try again.';
  }
}

class _NextFreePlacement {
  final int nextSerial;
  final DateTime estimatedStart;

  const _NextFreePlacement({
    required this.nextSerial,
    required this.estimatedStart,
  });
}

class BookingSummaryService {
  final String name;
  final int price;
  final int durationMinutes;

  const BookingSummaryService({
    required this.name,
    required this.price,
    required this.durationMinutes,
  });
}
