import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/shared/models/salon_verification_status.dart';
import 'package:cutline/shared/services/firestore_cache.dart';

class SalonService {
  SalonService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> saveSalon({
    required String ownerId,
    required String name,
    required String typedAddress,
    required String mapAddress,
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
    final existing = await FirestoreCache.getDoc(salonRef);
    final isNewSalon = !existing.exists;
    final existingData = existing.data();
    final existingIsOpen = existingData?['isOpen'];
    final bool? isOpen =
        existingIsOpen is bool ? existingIsOpen : (isNewSalon ? false : null);

    await salonRef.set(
      {
        'ownerId': ownerId,
        'name': name.trim(),
        'address': typedAddress.trim(),
        'mapAddress': mapAddress.trim(),
        'location': location,
        'geohash': geohash,
        'contact': contact.trim(),
        'email': email.trim(),
        'workingHours': workingHours,
        if (barbers != null) 'barbers': barbers,
        if (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty)
          'coverImageUrl': coverPhotoUrl,
        if (isNewSalon) 'isOpen': false,
        if (isNewSalon)
          'verificationStatus': SalonVerificationStatus.pending.firestoreValue,
        if (isNewSalon) 'submittedAt': now,
        'updatedAt': now,
        if (isNewSalon) 'createdAt': now,
      },
      SetOptions(merge: true),
    );

    await _syncServices(salonRef, services);
    if (galleryPhotos != null) {
      await _syncGalleryPhotos(salonRef, galleryPhotos);
    }

    await _firestore.collection('salons_summary').doc(ownerId).set(
      {
        'name': name.trim(),
        'address': typedAddress.trim(),
        if (coverPhotoUrl != null && coverPhotoUrl.isNotEmpty)
          'coverImageUrl': coverPhotoUrl,
        'topServices': _topServices(services),
        if (isOpen != null) 'isOpen': isOpen,
        if (isNewSalon) 'avgWaitMinutes': 0,
        if (isNewSalon) 'waitingCount': 0,
        if (isNewSalon) 'servingCount': 0,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );

    await _firestore.collection('users').doc(ownerId).set(
      {
        'profileComplete': true,
        // Keep owner profiles queryable by salonId for targeted FCM notifications.
        'salonId': ownerId,
        'updatedAt': now,
      },
      SetOptions(merge: true),
    );
  }

  Future<void> _syncServices(
    DocumentReference<Map<String, dynamic>> salonRef,
    List<Map<String, dynamic>> services,
  ) async {
    final collection = salonRef.collection('all_services');
    final existing = await FirestoreCache.getQuery(collection);
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (var i = 0; i < services.length; i++) {
      final data = Map<String, dynamic>.from(services[i]);
      data['order'] = i;
      data['updatedAt'] = FieldValue.serverTimestamp();
      batch.set(collection.doc(), data);
    }
    await batch.commit();
  }

  Future<void> _syncGalleryPhotos(
    DocumentReference<Map<String, dynamic>> salonRef,
    List<String> galleryPhotos,
  ) async {
    final collection = salonRef.collection('photos');
    final existing = await FirestoreCache.getQuery(collection);
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (var i = 0; i < galleryPhotos.length; i++) {
      final url = galleryPhotos[i].trim();
      if (url.isEmpty) continue;
      batch.set(collection.doc(), {
        'url': url,
        'order': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  List<String> _topServices(List<Map<String, dynamic>> services) {
    final names = services
        .map((item) => (item['name'] as String?)?.trim() ?? '')
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) return const [];
    return names.take(3).toList();
  }
}
