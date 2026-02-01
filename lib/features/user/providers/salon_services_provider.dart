import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cutline/shared/services/firestore_cache.dart';

class SalonServicesProvider extends ChangeNotifier {
  SalonServicesProvider({
    required this.salonName,
    this.salonId = '',
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String salonName;
  final String salonId;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  List<SalonService> _services = [];
  List<SalonCombo> _combos = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<SalonService> get services => _services;
  List<SalonCombo> get combos => _combos;

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    try {
      
      final doc = await _findSalonDoc();
      if (doc == null) {
        _services = [];
        _combos = [];
        _setError('Salon services not found.');
        return;
      }
      
      final data = doc.data() ?? {};
      
      // Load services
      try {
        final servicesQuery = _firestore
            .collection('salons')
            .doc(doc.id)
            .collection('all_services')
            .orderBy('order');
        final servicesSnap = await FirestoreCache.getQuery(servicesQuery);
        _services = _mapServices(servicesSnap.docs);
        if (_services.isEmpty) {
          final fallbackSnap = await FirestoreCache.getQuery(_firestore
              .collection('salons')
              .doc(doc.id)
              .collection('all_services'));
          _services = _mapServices(fallbackSnap.docs);
        }
      } catch (e) {
        try {
          final fallbackSnap = await FirestoreCache.getQuery(_firestore
              .collection('salons')
              .doc(doc.id)
              .collection('all_services'));
          _services = _mapServices(fallbackSnap.docs);
        } catch (_) {
          _services = [];
        }
      }
      
      // Load combos
      try {
        final combosField = data['combos'];
        _combos = _mapCombos(combosField);
      } catch (e) {
        _combos = [];
      }
      
    } catch (e, stackTrace) {
      _services = [];
      _combos = [];
      
      String errorMessage = 'Could not load services. Pull to refresh.';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          errorMessage = 'Permission denied. Please check Firestore rules are deployed.';
        } else if (e.code == 'unavailable') {
          errorMessage = 'Network error. Check your connection.';
        } else {
          errorMessage = 'Firebase error: ${e.message ?? e.code}';
        }
      }
      _setError(errorMessage);
    } finally {
      _setLoading(false);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findSalonDoc() async {
    try {
      if (salonId.trim().isNotEmpty) {
        final doc = await FirestoreCache.getDoc(
          _firestore.collection('salons').doc(salonId),
        );
        if (doc.exists) {
          return doc;
        }
      }
      final query = await FirestoreCache.getQuery(_firestore
          .collection('salons')
          .where('name', isEqualTo: salonName)
          .limit(1)
          );
      
      if (query.docs.isEmpty) {
        return null;
      }
      
      final doc = query.docs.first;
      return doc;
    } catch (e, stackTrace) {
      return null;
    }
  }

  List<SalonService> _mapServices(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    try {
      final services = <SalonService>[];
      for (final doc in docs) {
        try {
          final m = doc.data();
          final service = SalonService(
            name: (m['name'] as String?)?.trim() ?? 'Service',
            durationMinutes: (m['durationMinutes'] as num?)?.toInt() ??
                (m['duration'] as num?)?.toInt() ??
                30,
            price: (m['price'] as num?)?.toInt() ?? 0,
          );
          services.add(service);
        } catch (e) {
        }
      }
      return services;
    } catch (e, stackTrace) {
      return [];
    }
  }

  List<SalonCombo> _mapCombos(dynamic raw) {
    try {
      if (raw is! List) {
        return [];
      }
      
      final combos = <SalonCombo>[];
      
      for (var i = 0; i < raw.length; i++) {
        try {
          final item = raw[i];
          if (item is! Map) {
            continue;
          }
          
          final m = item.cast<String, dynamic>();
          final combo = SalonCombo(
            title: (m['title'] as String?)?.trim() ??
                (m['name'] as String?)?.trim() ??
                'Combo Offer',
            details: (m['details'] as String?)?.trim() ??
                (m['description'] as String?)?.trim() ??
                (m['services'] as String?)?.trim() ??
                '',
            price: (m['price'] as num?)?.toInt() ?? 0,
            discountLabel: (m['discount'] as String?)?.trim() ??
                (m['discountLabel'] as String?)?.trim() ??
                '',
          );
          combos.add(combo);
        } catch (e) {
        }
      }
      
      return combos;
    } catch (e, stackTrace) {
      return [];
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }
}

class SalonService {
  final String name;
  final int durationMinutes;
  final int price;

  const SalonService({
    required this.name,
    required this.durationMinutes,
    required this.price,
  });
}

class SalonCombo {
  final String title;
  final String details;
  final int price;
  final String discountLabel;

  const SalonCombo({
    required this.title,
    required this.details,
    required this.price,
    required this.discountLabel,
  });
}
