import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/models/user_role.dart';
import 'package:cutline/shared/services/firestore_cache.dart';

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
  }) async {
    final userRef = _firestore.collection('users').doc(uid);
    final existing = await FirestoreCache.getDoc(userRef);
    final data = {
      'uid': uid,
      'email': email.trim(),
      'name': name.trim(),
      'phone': phone.trim(),
      'role': role.key,
      // Owners are associated to the salon document that uses their uid as id.
      // This allows server-side notification targeting via `.where('salonId' == bookingSalonId)`.
      if (role == UserRole.owner) 'salonId': uid,
      'profileComplete': role == UserRole.owner ? false : true,
      if (!existing.exists) 'favoriteSalonIds': <String>[],
      if (!existing.exists) 'activeBookingIds': <String>[],
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    return userRef.set(
          data,
          SetOptions(merge: true),
        );
  }

  Future<Map<String, dynamic>?> fetchUserProfile(String uid) async {
    final snap = await FirestoreCache.getDoc(
      _firestore.collection('users').doc(uid),
    );
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
