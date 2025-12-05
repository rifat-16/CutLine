import 'package:cutline/features/auth/models/user_role.dart';

class CutlineUser {
  final String uid;
  final String name;
  final String email;
  final String? phone;
  final UserRole role;
  final bool profileComplete;

  const CutlineUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.profileComplete = false,
  });

  factory CutlineUser.fromMap(Map<String, dynamic> data) {
    return CutlineUser(
      uid: (data['uid'] as String?) ?? '',
      name: (data['name'] as String?) ?? '',
      email: (data['email'] as String?) ?? '',
      phone: data['phone'] as String?,
      role: UserRoleKey.fromKey((data['role'] as String?) ?? 'customer'),
      profileComplete: data['profileComplete'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'email': email,
      'phone': phone,
      'role': role.key,
      'profileComplete': profileComplete,
    };
  }

  CutlineUser copyWith({
    String? name,
    String? email,
    String? phone,
    UserRole? role,
    bool? profileComplete,
  }) {
    return CutlineUser(
      uid: uid,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      profileComplete: profileComplete ?? this.profileComplete,
    );
  }
}
