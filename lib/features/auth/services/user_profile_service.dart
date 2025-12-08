import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/models/user_role.dart';

class UserProfileService {
  UserProfileService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> createUserProfile({
    required String uid,
    required String email,
    required String name,
    String phone = '',
    required UserRole role,
  }) {
    final data = {
      'uid': uid,
      'email': email.trim(),
      'name': name.trim(),
      'phone': phone.trim(),
      'role': role.key,
      'profileComplete': role == UserRole.owner ? false : true,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    return _firestore.collection('users').doc(uid).set(
          data,
          SetOptions(merge: true),
        );
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    final snap = await _firestore.collection('users').doc(uid).get();
    if (!snap.exists) return null;
    return snap.data();
  }

  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? email,
    String? phone,
    String? photoUrl,
  }) async {
    final now = FieldValue.serverTimestamp();
    final data = <String, dynamic>{
      'updatedAt': now,
    };
    if (name != null) data['name'] = name.trim();
    if (email != null) data['email'] = email.trim();
    if (phone != null) data['phone'] = phone.trim();
    if (photoUrl != null) data['photoUrl'] = photoUrl.trim();

    await _firestore
        .collection('users')
        .doc(uid)
        .set(data, SetOptions(merge: true));
  }

  Future<void> setProfileComplete(String uid, bool complete) async {
    final now = FieldValue.serverTimestamp();
    await _firestore.collection('users').doc(uid).set(
      {
        'profileComplete': complete,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );
  }
}
