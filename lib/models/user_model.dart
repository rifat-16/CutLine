class UserModel {
  final String id;
  final String name;
  final String phone;
  final UserRole role;
  final String? salonId;
  final DateTime createdAt;
  final String? fcmToken;

  UserModel({
    required this.id,
    required this.name,
    required this.phone,
    required this.role,
    this.salonId,
    required this.createdAt,
    this.fcmToken,
  });

  factory UserModel.fromMap(Map<String, dynamic> map, String id) {
    return UserModel(
      id: id,
      name: map['name'] ?? '',
      phone: map['phone'] ?? '',
      role: UserRole.fromString(map['role'] ?? 'user'),
      salonId: map['salonId'],
      createdAt: map['createdAt']?.toDate() ?? DateTime.now(),
      fcmToken: map['fcmToken'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'role': role.toString(),
      'salonId': salonId,
      'createdAt': createdAt,
      if (fcmToken != null) 'fcmToken': fcmToken,
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? phone,
    UserRole? role,
    String? salonId,
    DateTime? createdAt,
    String? fcmToken,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      salonId: salonId ?? this.salonId,
      createdAt: createdAt ?? this.createdAt,
      fcmToken: fcmToken ?? this.fcmToken,
    );
  }
}

enum UserRole {
  user,
  owner,
  barber;

  String toString() {
    switch (this) {
      case UserRole.user:
        return 'user';
      case UserRole.owner:
        return 'owner';
      case UserRole.barber:
        return 'barber';
    }
  }

  static UserRole fromString(String role) {
    switch (role) {
      case 'owner':
        return UserRole.owner;
      case 'barber':
        return UserRole.barber;
      default:
        return UserRole.user;
    }
  }
}
