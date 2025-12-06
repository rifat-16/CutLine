import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OwnerBookingReceiptProvider extends ChangeNotifier {
  OwnerBookingReceiptProvider({
    required this.ownerId,
    required this.bookingId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String ownerId;
  final String bookingId;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  OwnerBookingReceiptData? _data;

  bool get isLoading => _isLoading;
  String? get error => _error;
  OwnerBookingReceiptData? get data => _data;

  Future<void> load() async {
    if (ownerId.isEmpty || bookingId.isEmpty) {
      _setError('Missing booking details.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final doc = await _firestore
          .collection('salons')
          .doc(ownerId)
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

  OwnerBookingReceiptData _map(Map<String, dynamic> data) {
    final servicesField = data['services'];
    final services = servicesField is List
        ? servicesField
            .whereType<Map>()
            .map((e) {
              final map = e.cast<String, dynamic>();
              final name = (map['name'] as String?) ??
                  (map['service'] as String?) ??
                  'Service';
              return OwnerReceiptService(
                name: name,
                price: (map['price'] as num?)?.toInt() ?? 0,
              );
            })
            .toList()
        : <OwnerReceiptService>[];

    final price = (data['price'] as num?)?.toInt();
    final total = (data['total'] as num?)?.toInt() ??
        price ??
        services.fold<int>(0, (acc, s) => acc + s.price);
    final subtotal = services.fold<int>(0, (acc, s) => acc + s.price);

    final serviceName = (data['service'] as String?) ?? '';
    final fallbackService = serviceName.isNotEmpty
        ? [
            OwnerReceiptService(
              name: serviceName,
              price: price ?? total,
            )
          ]
        : <OwnerReceiptService>[];

    return OwnerBookingReceiptData(
      salonName: (data['salonName'] as String?) ??
          (data['salon'] as String?) ??
          'Salon',
      address: (data['address'] as String?) ?? '',
      phone: (data['contact'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      barberName: (data['barberName'] as String?) ?? '',
      dateTime: _parseDateTime(data),
      paymentMethod: (data['paymentMethod'] as String?) ??
          (data['payment'] as String?) ??
          'Pay at salon',
      status: _statusFromString((data['status'] as String?) ?? 'upcoming'),
      services: services.isNotEmpty ? services : fallbackService,
      subtotal: subtotal != 0 ? subtotal : (price ?? total),
      serviceCharge: (data['serviceCharge'] as num?)?.toInt() ?? 0,
      total: total,
      customerName: (data['customerName'] as String?) ?? '',
      customerPhone: (data['customerPhone'] as String?) ?? '',
      customerEmail: (data['customerEmail'] as String?) ?? '',
    );
  }

  OwnerBookingStatus _statusFromString(String status) {
    switch (status) {
      case 'completed':
      case 'done':
        return OwnerBookingStatus.completed;
      case 'cancelled':
      case 'rejected':
        return OwnerBookingStatus.cancelled;
      default:
        return OwnerBookingStatus.upcoming;
    }
  }

  DateTime _parseDateTime(Map<String, dynamic> data) {
    final ts = data['dateTime'];
    if (ts is Timestamp) return ts.toDate();
    final dateStr = (data['date'] as String?) ?? '';
    final timeStr = (data['time'] as String?) ?? '';
    if (dateStr.isNotEmpty && timeStr.isNotEmpty) {
      try {
        final parsedDate = DateTime.parse(dateStr);
        final parsedTime = DateFormat('h:mm a').parse(timeStr);
        return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
            parsedTime.hour, parsedTime.minute);
      } catch (_) {}
    }
    return DateTime.now();
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

class OwnerBookingReceiptData {
  final String salonName;
  final String address;
  final String phone;
  final String email;
  final String barberName;
  final DateTime dateTime;
  final String paymentMethod;
  final OwnerBookingStatus status;
  final List<OwnerReceiptService> services;
  final int subtotal;
  final int serviceCharge;
  final int total;
  final String customerName;
  final String customerPhone;
  final String customerEmail;

  const OwnerBookingReceiptData({
    required this.salonName,
    required this.address,
    required this.phone,
    required this.email,
    required this.barberName,
    required this.dateTime,
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

class OwnerReceiptService {
  final String name;
  final int price;

  const OwnerReceiptService({required this.name, required this.price});
}
