import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/shared/models/salon_verification_status.dart';

class SalonService {
  SalonService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> saveSalon({
    required String ownerId,
    required String name,
    required String address,
    required GeoPoint location,
    required String geohash,
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
    final existing = await salonRef.get();
    final isNewSalon = !existing.exists;

    await salonRef.set(
      {
        'ownerId': ownerId,
        'name': name.trim(),
        'address': address.trim(),
        'location': location,
        'geohash': geohash,
        'contact': contact.trim(),
        'email': email.trim(),
        'workingHours': workingHours,
        'services': services,
        if (barbers != null) 'barbers': barbers,
        if (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty)
          'coverImageUrl': coverPhotoUrl,
        if (galleryPhotos != null && galleryPhotos.isNotEmpty)
          'galleryPhotos': galleryPhotos,
        if (isNewSalon) 'isOpen': false,
        if (isNewSalon)
          'verificationStatus': SalonVerificationStatus.pending.firestoreValue,
        if (isNewSalon) 'submittedAt': now,
        'updatedAt': now,
        if (isNewSalon) 'createdAt': now,
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
