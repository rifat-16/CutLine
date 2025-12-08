import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class BookingReceiptProvider extends ChangeNotifier {
  BookingReceiptProvider({
    required this.salonId,
    required this.bookingId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String salonId;
  final String bookingId;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  BookingReceiptData? _data;

  bool get isLoading => _isLoading;
  String? get error => _error;
  BookingReceiptData? get data => _data;

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    try {
      final doc = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .doc(bookingId)
          .get();
      if (!doc.exists) {
        _setError('Booking not found.');
        _data = null;
      } else {
        _data = _map(doc.data() ?? {});
      }
    } catch (_) {
      _setError('Failed to load booking receipt.');
      _data = null;
    } finally {
      _setLoading(false);
    }
  }

  BookingReceiptData _map(Map<String, dynamic> data) {
    final servicesField = data['services'];
    final services = servicesField is List
        ? servicesField
            .whereType<Map>()
            .map((e) {
              final map = e.cast<String, dynamic>();
              return ReceiptService(
                name: (map['name'] as String?) ?? 'Service',
                price: (map['price'] as num?)?.toInt() ?? 0,
              );
            })
            .toList()
        : <ReceiptService>[];

    final total = (data['total'] as num?)?.toInt() ??
        services.fold<int>(0, (acc, s) => acc + s.price);

    return BookingReceiptData(
      salonName: (data['salonName'] as String?) ?? 'Salon',
      address: (data['address'] as String?) ?? '',
      contact: (data['contact'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      barberName: (data['barberName'] as String?) ?? '',
      date: (data['date'] as String?) ?? '',
      time: (data['time'] as String?) ?? '',
      paymentMethod: (data['paymentMethod'] as String?) ?? 'Pay at salon',
      status: (data['status'] as String?) ?? 'upcoming',
      services: services,
      subtotal: services.fold<int>(0, (acc, s) => acc + s.price),
      serviceCharge: (data['serviceCharge'] as num?)?.toInt() ?? 0,
      total: total,
      customerName: (data['customerName'] as String?) ?? '',
      customerPhone: (data['customerPhone'] as String?) ?? '',
      customerEmail: (data['customerEmail'] as String?) ?? '',
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

class BookingReceiptData {
  final String salonName;
  final String address;
  final String contact;
  final String email;
  final String barberName;
  final String date;
  final String time;
  final String paymentMethod;
  final String status;
  final List<ReceiptService> services;
  final int subtotal;
  final int serviceCharge;
  final int total;
  final String customerName;
  final String customerPhone;
  final String customerEmail;

  const BookingReceiptData({
    required this.salonName,
    required this.address,
    required this.contact,
    required this.email,
    required this.barberName,
    required this.date,
    required this.time,
    required this.paymentMethod,
    required this.status,
    required this.services,
    required this.subtotal,
    required this.serviceCharge,
    required this.total,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
  });
}

class ReceiptService {
  final String name;
  final int price;

  const ReceiptService({required this.name, required this.price});
}
