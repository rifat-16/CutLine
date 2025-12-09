import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class SalonServicesProvider extends ChangeNotifier {
  SalonServicesProvider({
    required this.salonName,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String salonName;
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
      debugPrint('SalonServicesProvider: Loading services for salonName: $salonName');
      
      final doc = await _findSalonDoc();
      if (doc == null) {
        debugPrint('SalonServicesProvider: Salon document not found for name: $salonName');
        _services = [];
        _combos = [];
        _setError('Salon services not found.');
        return;
      }
      
      debugPrint('SalonServicesProvider: Found salon document: ${doc.id}');
      final data = doc.data() ?? {};
      debugPrint('SalonServicesProvider: Salon document keys: ${data.keys.toList()}');
      
      // Load services
      try {
        final servicesField = data['services'];
        debugPrint('SalonServicesProvider: Services field type: ${servicesField.runtimeType}');
        _services = _mapServices(servicesField);
        debugPrint('SalonServicesProvider: Mapped ${_services.length} services');
      } catch (e) {
        debugPrint('SalonServicesProvider: Error mapping services: $e');
        _services = [];
      }
      
      // Load combos
      try {
        final combosField = data['combos'];
        debugPrint('SalonServicesProvider: Combos field type: ${combosField.runtimeType}');
        _combos = _mapCombos(combosField);
        debugPrint('SalonServicesProvider: Mapped ${_combos.length} combos');
      } catch (e) {
        debugPrint('SalonServicesProvider: Error mapping combos: $e');
        _combos = [];
      }
      
      debugPrint('SalonServicesProvider: Successfully loaded ${_services.length} services and ${_combos.length} combos');
    } catch (e, stackTrace) {
      debugPrint('SalonServicesProvider: Error in load: $e');
      debugPrint('Error code: ${e is FirebaseException ? e.code : "unknown"}');
      debugPrint('Stack trace: $stackTrace');
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
      debugPrint('_findSalonDoc: Searching for salon with name: $salonName');
      final query = await _firestore
          .collection('salons')
          .where('name', isEqualTo: salonName)
          .limit(1)
          .get();
      
      debugPrint('_findSalonDoc: Query returned ${query.docs.length} documents');
      if (query.docs.isEmpty) {
        debugPrint('_findSalonDoc: No salon found with name: $salonName');
        return null;
      }
      
      final doc = query.docs.first;
      debugPrint('_findSalonDoc: Found salon document: ${doc.id}');
      return doc;
    } catch (e, stackTrace) {
      debugPrint('_findSalonDoc: Error finding salon document: $e');
      debugPrint('Error code: ${e is FirebaseException ? e.code : "unknown"}');
      debugPrint('Stack trace: $stackTrace');
      return null;
    }
  }

  List<SalonService> _mapServices(dynamic raw) {
    try {
      if (raw is! List) {
        debugPrint('_mapServices: Services field is not a List: ${raw.runtimeType}');
        return [];
      }
      
      debugPrint('_mapServices: Mapping ${raw.length} service items');
      final services = <SalonService>[];
      
      for (var i = 0; i < raw.length; i++) {
        try {
          final item = raw[i];
          if (item is! Map) {
            debugPrint('_mapServices: Item $i is not a Map: ${item.runtimeType}');
            continue;
          }
          
          final m = item.cast<String, dynamic>();
          final service = SalonService(
            name: (m['name'] as String?)?.trim() ?? 'Service',
            durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 
                (m['duration'] as num?)?.toInt() ?? 30,
            price: (m['price'] as num?)?.toInt() ?? 0,
          );
          services.add(service);
          debugPrint('_mapServices: Mapped service: ${service.name} - ৳${service.price}');
        } catch (e) {
          debugPrint('_mapServices: Error mapping service item $i: $e');
        }
      }
      
      debugPrint('_mapServices: Successfully mapped ${services.length} services');
      return services;
    } catch (e, stackTrace) {
      debugPrint('_mapServices: Error in _mapServices: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  List<SalonCombo> _mapCombos(dynamic raw) {
    try {
      if (raw is! List) {
        debugPrint('_mapCombos: Combos field is not a List: ${raw.runtimeType}');
        return [];
      }
      
      debugPrint('_mapCombos: Mapping ${raw.length} combo items');
      final combos = <SalonCombo>[];
      
      for (var i = 0; i < raw.length; i++) {
        try {
          final item = raw[i];
          if (item is! Map) {
            debugPrint('_mapCombos: Item $i is not a Map: ${item.runtimeType}');
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
          debugPrint('_mapCombos: Mapped combo: ${combo.title} - ৳${combo.price}');
        } catch (e) {
          debugPrint('_mapCombos: Error mapping combo item $i: $e');
        }
      }
      
      debugPrint('_mapCombos: Successfully mapped ${combos.length} combos');
      return combos;
    } catch (e, stackTrace) {
      debugPrint('_mapCombos: Error in _mapCombos: $e');
      debugPrint('Stack trace: $stackTrace');
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
