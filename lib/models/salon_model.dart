import 'package:cutline/models/service_model.dart';

class SalonModel {
  final String id;
  final String name;
  final String ownerId;
  final String location;
  final List<String> barbers;
  final List<ServiceModel> services;
  final DateTime createdAt;
  final String? imageUrl;

  SalonModel({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.location,
    this.barbers = const [],
    this.services = const [],
    required this.createdAt,
    this.imageUrl,
  });

  factory SalonModel.fromMap(Map<String, dynamic> map, String id) {
    return SalonModel(
      id: id,
      name: map['name'] ?? '',
      ownerId: map['ownerId'] ?? '',
      location: map['location'] ?? '',
      barbers: List<String>.from(map['barbers'] ?? []),
      services: (map['services'] as List<dynamic>? ?? [])
          .map((s) => ServiceModel.fromMap(s))
          .toList(),
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      imageUrl: map['imageUrl'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerId': ownerId,
      'location': location,
      'barbers': barbers,
      'services': services.map((s) => s.toMap()).toList(),
      'createdAt': createdAt,
      if (imageUrl != null) 'imageUrl': imageUrl,
    };
  }

  SalonModel copyWith({
    String? id,
    String? name,
    String? ownerId,
    String? location,
    List<String>? barbers,
    List<ServiceModel>? services,
    DateTime? createdAt,
    String? imageUrl,
  }) {
    return SalonModel(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerId: ownerId ?? this.ownerId,
      location: location ?? this.location,
      barbers: barbers ?? this.barbers,
      services: services ?? this.services,
      createdAt: createdAt ?? this.createdAt,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }
}
