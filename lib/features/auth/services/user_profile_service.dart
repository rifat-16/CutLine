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
    required UserRole role,
  }) {
    final data = {
      'uid': uid,
      'email': email.trim(),
      'name': name.trim(),
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
