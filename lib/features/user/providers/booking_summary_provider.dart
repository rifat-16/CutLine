import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cutline/shared/services/firestore_cache.dart';

class BookingSummaryProvider extends ChangeNotifier {
  BookingSummaryProvider({
    required this.salonId,
    required this.salonName,
    required this.selectedServices,
    required this.selectedBarber,
    required this.selectedDate,
    required this.selectedTime,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    this.customerUid = '',
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String salonId;
  final String salonName;
  final List<String> selectedServices;
  final String selectedBarber;
  final DateTime selectedDate;
  final String selectedTime;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerUid;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  String _address = '';
  String _contact = '';
  double _rating = 4.6;
  String _salonEmail = '';
  int _serviceCharge = 0;
  List<BookingSummaryService> _services = [];

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

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    try {
      final doc = await FirestoreCache.getDoc(
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
    notifyListeners();
    try {
      final exists = await _bookingExists();
      if (exists) {
        _isSaving = false;
        _setError('This time slot is already booked. Please choose another.');
        return false;
      }
      final totalWithTip = total + tipAmount;
      final data = {
        'salonId': salonId,
        'salonName': salonName,
        'customerUid': customerUid,
        'services': _services
            .map((s) => {
                  'name': s.name,
                  'price': s.price,
                  'durationMinutes': s.durationMinutes,
                })
            .toList(),
        'barberName': selectedBarber,
        'date': dateKey,
        'time': selectedTime,
        'paymentMethod': paymentMethod,
        'tipAmount': tipAmount,
        'total': totalWithTip,
        'durationMinutes': totalDurationMinutes,
        'status': 'upcoming',
        'createdAt': FieldValue.serverTimestamp(),
        'serviceCharge': serviceCharge,
        'address': _address,
        'contact': _contact,
        'email': _salonEmail,
        'salonEmail': _salonEmail,
        'salonContact': _contact,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerEmail': customerEmail,
      };
      final bookingRef = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .add(data);
      if (customerUid.isNotEmpty) {
        await _firestore.collection('users').doc(customerUid).set(
          {
            'activeBookingIds': FieldValue.arrayUnion([bookingRef.id]),
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
      }
      _isSaving = false;
      notifyListeners();
      return true;
    } catch (_) {
      _isSaving = false;
      _setError('Could not confirm booking. Try again.');
      return false;
    }
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
      final snap = await FirestoreCache.getQuery(query);
      final mapped = _mapServices(snap.docs, selectedServices);
      if (mapped.isNotEmpty) return mapped;
    } catch (_) {
      // fall through to fallback
    }
    try {
      final snap = await FirestoreCache.getQuery(_firestore
          .collection('salons')
          .doc(salonId)
          .collection('all_services'));
      return _mapServices(snap.docs, selectedServices);
    } catch (_) {
      return [];
    }
  }

  Future<int> _loadPlatformFee() async {
    try {
      final snap = await FirestoreCache.getQuery(
        _firestore.collection('platform_fee').limit(1),
      );
      if (snap.docs.isEmpty) return 0;
      final data = snap.docs.first.data();
      final raw = data['fee'];
      if (raw == null) return 0;
      if (raw is num) return raw.toInt();
      if (raw is String) {
        final normalized = raw.trim().toLowerCase();
        if (normalized.isEmpty || normalized == 'free') return 0;
        final parsed = int.tryParse(normalized);
        if (parsed != null) return parsed;
        final digits = RegExp(r'\d+').stringMatch(normalized);
        return digits != null ? int.tryParse(digits) ?? 0 : 0;
      }
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
