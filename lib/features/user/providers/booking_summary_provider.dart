import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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

  int get serviceTotal =>
      _services.fold(0, (acc, item) => acc + item.price);
  int get serviceCharge => 10;
  int get total => serviceTotal + serviceCharge;
  String get formattedDate => DateFormat('dd MMM yyyy').format(selectedDate);
  String get dateKey => DateFormat('yyyy-MM-dd').format(selectedDate);

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    try {
      final doc = await _firestore.collection('salons').doc(salonId).get();
      final data = doc.data() ?? {};
      _address = (data['address'] as String?) ?? '';
      _contact = (data['contact'] as String?) ?? '';
      _salonEmail = ((data['email'] as String?) ??
              (data['ownerEmail'] as String?) ??
              (data['contactEmail'] as String?))
          ?.trim() ??
          '';
      _rating = (data['rating'] as num?)?.toDouble() ?? 4.6;
      _services = _mapServices(data['services'], selectedServices);
    } catch (_) {
      _services = [];
      _setError('Could not load booking summary.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> saveBooking(String paymentMethod) async {
    _isSaving = true;
    notifyListeners();
    try {
      final exists = await _bookingExists();
      if (exists) {
        _isSaving = false;
        _setError('This time slot is already booked. Please choose another.');
        return false;
      }
      final data = {
        'salonId': salonId,
        'salonName': salonName,
        'customerUid': customerUid,
        'services': _services
            .map((s) => {'name': s.name, 'price': s.price})
            .toList(),
        'barberName': selectedBarber,
        'date': dateKey,
        'time': selectedTime,
        'paymentMethod': paymentMethod,
        'total': total,
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
      await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .add(data);
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
      final snap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .where('date', isEqualTo: dateKey)
          .where('time', isEqualTo: selectedTime)
          .limit(1)
          .get();
      return snap.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  List<BookingSummaryService> _mapServices(
      dynamic servicesField, List<String> selected) {
    final List<BookingSummaryService> mapped = [];
    Map<String, int> priceLookup = {};
    if (servicesField is List) {
      for (final item in servicesField) {
        if (item is Map<String, dynamic>) {
          final name = (item['name'] as String?) ?? '';
          final price = (item['price'] as num?)?.toInt() ?? 0;
          if (name.isNotEmpty) {
            priceLookup[name] = price;
          }
        }
      }
    }
    for (final name in selected) {
      final price = priceLookup[name] ?? 0;
      mapped.add(BookingSummaryService(name: name, price: price));
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

  const BookingSummaryService({required this.name, required this.price});
}
