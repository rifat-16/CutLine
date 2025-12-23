import 'package:cloud_firestore/cloud_firestore.dart';

class SalonLookupService {
  SalonLookupService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<bool> salonExists(String ownerId) async {
    try {
      final doc = await _firestore.collection('salons').doc(ownerId).get();
      return doc.exists;
    } on FirebaseException {
      return false;
    } catch (_) {
      return false;
    }
  }
}
