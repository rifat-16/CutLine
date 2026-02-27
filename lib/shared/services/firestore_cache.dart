import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class FirestoreCache {
  const FirestoreCache._();

  static bool debugReads = false;
  static int docReads = 0;
  static int queryReads = 0;

  static void resetCounters() {
    docReads = 0;
    queryReads = 0;
  }

  static void _log(String message) {
    if (debugReads && kDebugMode) {
      debugPrint(message);
    }
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getDoc(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      docReads++;
      _log('FirestoreCache.getDoc server: ${ref.path}');
      return await ref.get(const GetOptions(source: Source.server));
    } catch (_) {
      _log('FirestoreCache.getDoc cache fallback: ${ref.path}');
      return ref.get(const GetOptions(source: Source.cache));
    }
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getQuery(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      queryReads++;
      _log('FirestoreCache.getQuery server');
      return await query.get(const GetOptions(source: Source.server));
    } catch (_) {
      _log('FirestoreCache.getQuery cache fallback');
      return query.get(const GetOptions(source: Source.cache));
    }
  }

  static Future<DocumentSnapshot<Map<String, dynamic>>> getDocCacheFirst(
    DocumentReference<Map<String, dynamic>> ref,
  ) async {
    try {
      final cached = await ref.get(const GetOptions(source: Source.cache));
      if (cached.exists) return cached;
    } catch (_) {
      // ignore cache errors, fall back to server
    }
    try {
      docReads++;
      _log('FirestoreCache.getDocCacheFirst server: ${ref.path}');
      return await ref.get(const GetOptions(source: Source.server));
    } catch (_) {
      _log('FirestoreCache.getDocCacheFirst cache fallback: ${ref.path}');
      return ref.get(const GetOptions(source: Source.cache));
    }
  }

  static Future<QuerySnapshot<Map<String, dynamic>>> getQueryCacheFirst(
    Query<Map<String, dynamic>> query,
  ) async {
    try {
      final cached = await query.get(const GetOptions(source: Source.cache));
      if (cached.docs.isNotEmpty) return cached;
    } catch (_) {
      // ignore cache errors, fall back to server
    }
    try {
      queryReads++;
      _log('FirestoreCache.getQueryCacheFirst server');
      return await query.get(const GetOptions(source: Source.server));
    } catch (_) {
      _log('FirestoreCache.getQueryCacheFirst cache fallback');
      return query.get(const GetOptions(source: Source.cache));
    }
  }
}
