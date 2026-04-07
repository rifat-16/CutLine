import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cutline/shared/models/platform_fee_config.dart';
import 'package:cutline/shared/services/firestore_cache.dart';

class PlatformFeeService {
  PlatformFeeService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<PlatformFeeConfig> loadConfig() async {
    try {
      final doc = await FirestoreCache.getDoc(
        _firestore.collection('platform_fee').doc('default'),
      );
      if (doc.exists) {
        return PlatformFeeConfig.fromMap(doc.data() ?? <String, dynamic>{});
      }
    } catch (_) {
      // Fall back to legacy query shape.
    }

    try {
      final snapshot = await FirestoreCache.getQuery(
        _firestore.collection('platform_fee').limit(1),
      );
      if (snapshot.docs.isNotEmpty) {
        return PlatformFeeConfig.fromMap(snapshot.docs.first.data());
      }
    } catch (_) {
      // Fall through to free config.
    }

    return const PlatformFeeConfig.free();
  }

  Future<int> loadEffectiveAmount() async {
    final config = await loadConfig();
    return config.effectiveAmount;
  }
}
