import 'package:cloud_firestore/cloud_firestore.dart';

class SalonService {
  SalonService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> saveSalon({
    required String ownerId,
    required String name,
    required String address,
    required String contact,
    required String email,
    required Map<String, dynamic> workingHours,
    required List<Map<String, dynamic>> services,
    List<Map<String, dynamic>>? barbers,
    String? coverPhotoUrl,
    List<String>? galleryPhotos,
  }) async {
    final now = FieldValue.serverTimestamp();
    final salonRef = _firestore.collection('salons').doc(ownerId);

    await salonRef.set(
      {
        'ownerId': ownerId,
        'name': name.trim(),
        'address': address.trim(),
        'contact': contact.trim(),
        'email': email.trim(),
        'workingHours': workingHours,
        'services': services,
        if (barbers != null) 'barbers': barbers,
        if (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty)
          'coverImageUrl': coverPhotoUrl,
        if (galleryPhotos != null && galleryPhotos.isNotEmpty)
          'galleryPhotos': galleryPhotos,
        'updatedAt': now,
        'createdAt': now,
      },
      SetOptions(merge: true),
    );

    await _firestore.collection('users').doc(ownerId).set(
      {
        'profileComplete': true,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );
  }
}
