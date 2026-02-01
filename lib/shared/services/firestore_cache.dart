import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreCache {
  const FirestoreCache._();

  static Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      return await ref.get(const GetOptions(source: Source.server));
    } catch (_) {
      return ref.get(const GetOptions(source: Source.cache));
    }
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getQuery(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      return await query.get(const GetOptions(source: Source.server));
    } catch (_) {
      return query.get(const GetOptions(source: Source.cache));
    }
  }
}
