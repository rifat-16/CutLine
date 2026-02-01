import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:cutline/shared/services/firestore_cache.dart';

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
      final doc = await FirestoreCache.getDoc(
        _firestore.collection('salons').doc(ownerId),
      );
      final data = doc.data() ?? {};
      final combosField = data['combos'];
      _services = await _loadServices(ownerId);
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
      await _syncServices(ownerId, _services);
      await _firestore.collection('salons_summary').doc(ownerId).set(
        {
          'topServices': _topServices(_services),
        },
        SetOptions(merge: true),
      );
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

  List<String> _topServices(List<OwnerServiceInfo> services) {
    final names = services
        .map((s) => s.name.trim())
        .where((name) => name.isNotEmpty)
        .toList();
    if (names.isEmpty) return const [];
    return names.take(3).toList();
  }

  Future<List<OwnerServiceInfo>> _loadServices(String ownerId) async {
    try {
      final query = _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('all_services')
          .orderBy('order');
      final snap = await FirestoreCache.getQuery(query);
      final services =
          snap.docs.map((doc) => _mapService(doc.data())).toList();
      if (services.isNotEmpty) return services;
    } catch (_) {
      // fall through to fallback
    }
    try {
      final snap = await FirestoreCache.getQuery(_firestore
          .collection('salons')
          .doc(ownerId)
          .collection('all_services'));
      return snap.docs.map((doc) => _mapService(doc.data())).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _syncServices(
    String ownerId,
    List<OwnerServiceInfo> services,
  ) async {
    final collection =
        _firestore.collection('salons').doc(ownerId).collection('all_services');
    final existing = await FirestoreCache.getQuery(collection);
    final batch = _firestore.batch();
    for (final doc in existing.docs) {
      batch.delete(doc.reference);
    }
    for (var i = 0; i < services.length; i++) {
      final service = services[i];
      batch.set(collection.doc(), {
        'name': service.name,
        'price': service.price,
        'durationMinutes': service.durationMinutes,
        'order': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }
}
