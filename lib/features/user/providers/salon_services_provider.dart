import 'package:cloud_firestore/cloud_firestore.dart';
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
      final doc = await _findSalonDoc();
      if (doc == null) {
        _services = [];
        _combos = [];
        _setError('Salon services not found.');
      } else {
        final data = doc.data() ?? {};
        _services = _mapServices(data['services']);
        _combos = _mapCombos(data['combos']);
      }
    } catch (_) {
      _services = [];
      _combos = [];
      _setError('Could not load services. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  Future<DocumentSnapshot<Map<String, dynamic>>?> _findSalonDoc() async {
    final query = await _firestore
        .collection('salons')
        .where('name', isEqualTo: salonName)
        .limit(1)
        .get();
    if (query.docs.isEmpty) return null;
    return query.docs.first;
  }

  List<SalonService> _mapServices(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((map) {
      final m = map.cast<String, dynamic>();
      return SalonService(
        name: (m['name'] as String?) ?? 'Service',
        durationMinutes: (m['durationMinutes'] as num?)?.toInt() ?? 30,
        price: (m['price'] as num?)?.toInt() ?? 0,
      );
    }).toList();
  }

  List<SalonCombo> _mapCombos(dynamic raw) {
    if (raw is! List) return [];
    return raw.whereType<Map>().map((map) {
      final m = map.cast<String, dynamic>();
      return SalonCombo(
        title: (m['title'] as String?) ??
            (m['name'] as String?) ??
            'Combo Offer',
        details: (m['details'] as String?) ??
            (m['description'] as String?) ??
            '',
        price: (m['price'] as num?)?.toInt() ?? 0,
        discountLabel: (m['discount'] as String?) ?? '',
      );
    }).toList();
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
