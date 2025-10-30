class ServiceModel {
  final String id;
  final String name;
  final double price;
  final int duration; // in minutes
  final String description;

  ServiceModel({
    required this.id,
    required this.name,
    required this.price,
    required this.duration,
    this.description = '',
  });

  factory ServiceModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return ServiceModel(
      id: id ?? map['id'] ?? '',
      name: map['name'] ?? '',
      price: (map['price'] ?? 0.0).toDouble(),
      duration: map['duration'] ?? 30,
      description: map['description'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'price': price,
      'duration': duration,
      'description': description,
    };
  }

  ServiceModel copyWith({
    String? id,
    String? name,
    double? price,
    int? duration,
    String? description,
  }) {
    return ServiceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      price: price ?? this.price,
      duration: duration ?? this.duration,
      description: description ?? this.description,
    );
  }
}
