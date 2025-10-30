import 'package:cutline/models/service_model.dart';
import 'package:cutline/models/booking_model.dart';

class BarberModel {
  final String id;
  final String salonId;
  final String name;
  final String phone;
  final bool available;
  final List<ServiceModel> services;
  final List<BookingModel> currentQueue;
  final DateTime createdAt;
  final String? imageUrl;

  BarberModel({
    required this.id,
    required this.salonId,
    required this.name,
    required this.phone,
    this.available = true,
    this.services = const [],
    this.currentQueue = const [],
    required this.createdAt,
    this.imageUrl,
  });

  factory BarberModel.fromMap(Map<String, dynamic> map, String id) {
    return BarberModel(
      id: id,
      salonId: map['salonId'] ?? '',
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      available: map['available'] ?? true,
      services: (map['services'] as List<dynamic>? ?? [])
          .map((s) => ServiceModel.fromMap(s))
          .toList(),
      currentQueue: (map['currentQueue'] as List<dynamic>? ?? [])
          .map((q) => BookingModel.fromMap(q))
          .toList(),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'salonId': salonId,
      'name': name,
      'phone': phone,
      'available': available,
      'services': services.map((s) => s.toMap()).toList(),
      'currentQueue': currentQueue.map((q) => q.toMap()).toList(),
      'createdAt': createdAt,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  BarberModel copyWith({
    String? id,
    String? salonId,
    String? name,
    String? phone,
    bool? available,
    List<ServiceModel>? services,
    List<BookingModel>? currentQueue,
    DateTime? createdAt,
    String? imageUrl,
  }) {
    return BarberModel(
      id: id ?? this.id,
      salonId: salonId ?? this.salonId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      available: available ?? this.available,
      services: services ?? this.services,
      currentQueue: currentQueue ?? this.currentQueue,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
