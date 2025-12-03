import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class ManageServicesProvider extends ChangeNotifier {
  ManageServicesProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  List<OwnerServiceInfo> _services = [];
  List<OwnerComboInfo> _combos = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<OwnerServiceInfo> get services => _services;
  List<OwnerComboInfo> get combos => _combos;

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final doc = await _firestore.collection('salons').doc(ownerId).get();
      final data = doc.data() ?? {};
      final servicesField = data['services'];
      final combosField = data['combos'];
      if (servicesField is List) {
        _services = servicesField
            .map((e) => _mapService(e as Map<String, dynamic>? ?? {}))
            .toList();
      }
      if (combosField is List) {
        _combos = combosField
            .map((e) => _mapCombo(e as Map<String, dynamic>? ?? {}))
            .toList();
      }
    } catch (_) {
      _services = [];
      _combos = [];
      _setError('Showing cached data. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> save() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    try {
      await _firestore.collection('salons').doc(ownerId).set({
        'services': _services
            .map((s) => {
                  'name': s.name,
                  'price': s.price,
                  'durationMinutes': s.durationMinutes,
                })
            .toList(),
        'combos': _combos
            .map((c) => {
                  'name': c.name,
                  'services': c.services,
                  'highlight': c.highlight,
                  'price': c.price,
                  'emoji': c.emoji,
                })
            .toList(),
      }, SetOptions(merge: true));
    } catch (_) {
      _setError('Failed to save changes.');
    }
  }

  void addService(OwnerServiceInfo service) {
    _services.add(service);
    notifyListeners();
  }

  void updateService(int index, OwnerServiceInfo service) {
    _services[index] = service;
    notifyListeners();
  }

  void removeService(int index) {
    _services.removeAt(index);
    notifyListeners();
  }

  void addCombo(OwnerComboInfo combo) {
    _combos.add(combo);
    notifyListeners();
  }

  void updateCombo(int index, OwnerComboInfo combo) {
    _combos[index] = combo;
    notifyListeners();
  }

  void removeCombo(int index) {
    _combos.removeAt(index);
    notifyListeners();
  }

  OwnerServiceInfo _mapService(Map<String, dynamic> data) {
    return OwnerServiceInfo(
      name: (data['name'] as String?) ?? 'Service',
      price: (data['price'] as num?)?.toInt() ?? 0,
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 30,
    );
  }

  OwnerComboInfo _mapCombo(Map<String, dynamic> data) {
    return OwnerComboInfo(
      name: (data['name'] as String?) ?? 'Combo',
      services: (data['services'] as String?) ?? '',
      highlight: (data['highlight'] as String?) ?? '',
      price: (data['price'] as num?)?.toInt() ?? 0,
      emoji: (data['emoji'] as String?) ?? '✨',
    );
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }
}
