import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCache {
  const FirestoreCache._();

  static Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      if (cached.exists) return cached;
    } catch (_) {
      // Cache miss or unavailable.
    }

    try {
      return await ref.get();
    } catch (_) {
      return ref.get(const GetOptions(source: Source.cache));
    }
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getQuery(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      final cached = await query.get(const GetOptions(source: Source.cache));
      if (cached.docs.isNotEmpty) return cached;
    } catch (_) {
      // Cache miss or unavailable.
    }

    try {
      return await query.get();
    } catch (_) {
      return query.get(const GetOptions(source: Source.cache));
    }
  }
}
