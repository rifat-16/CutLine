import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class UserHomeProvider extends ChangeNotifier {
  UserHomeProvider({FirebaseFirestore? firestore, this.userId = ''})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String userId;

  bool _isLoading = false;
  String? _error;
  List<UserSalon> _salons = [];
  Set<String> _favoriteIds = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserSalon> get salons => _salons;

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    try {
      _favoriteIds = await _loadFavoriteIds();
      final snapshot = await _firestore.collection('salons').get();
      final salons = await Future.wait(
        snapshot.docs.map((doc) => _mapSalon(doc.id, doc.data())),
      );
      salons.sort((a, b) => a.name.compareTo(b.name));
      _salons = salons;
    } catch (_) {
      _salons = [];
      _setError('Failed to load salons. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  Future<UserSalon> _mapSalon(String id, Map<String, dynamic> data) async {
    final servicesField = data['services'];
    final services = servicesField is List
        ? servicesField
            .map((item) => _parseServiceName(item))
            .where((name) => name.isNotEmpty)
            .toList()
        : <String>[];

    final isOpenFlag = data['isOpen'];
    final bool isOpenNow = isOpenFlag is bool ? isOpenFlag : false;
    final waitMinutes = await _estimateWaitMinutes(id);

    return UserSalon(
      id: id,
      name: (data['name'] as String?) ?? 'Salon',
      address: (data['address'] as String?) ?? 'Address unavailable',
      contact: (data['contact'] as String?) ?? '',
      isOpenNow: isOpenNow,
      waitMinutes: waitMinutes,
      topServices: services.take(3).toList(),
      isFavorite: _favoriteIds.contains(id),
    );
  }

  String _parseServiceName(dynamic item) {
    if (item is Map<String, dynamic>) {
      return (item['name'] as String?)?.trim() ?? '';
    }
    if (item is String) return item.trim();
    return '';
  }

  // Working-hours parsing retained for future use; the card now relies solely
  // on the salon's `isOpen` flag from Firestore.

  Future<int> _estimateWaitMinutes(String salonId) async {
    try {
      final snap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .where('status', isEqualTo: 'waiting')
          .get();
      if (snap.docs.isEmpty) return 0;

      var collected = 0;
      var items = 0;
      for (final doc in snap.docs) {
        final wait = (doc.data()['waitMinutes'] as num?)?.toInt();
        if (wait != null && wait > 0) {
          collected += wait;
          items++;
        }
      }
      if (items > 0) return (collected / items).ceil();
      return snap.size * 10; // fallback estimate
    } catch (_) {
      return 0;
    }
  }

  Future<Set<String>> _loadFavoriteIds() async {
    if (userId.isEmpty) return {};
    try {
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();
      return snap.docs
          .map((doc) {
            final data = doc.data();
            final salonId = data['salonId'];
            if (salonId is String && salonId.isNotEmpty) return salonId;
            return doc.id;
          })
          .where((id) => id.isNotEmpty)
          .toSet();
    } catch (_) {
      return {};
    }
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

class UserSalon {
  final String id;
  final String name;
  final String address;
  final String contact;
  final bool isOpenNow;
  final int waitMinutes;
  final List<String> topServices;
  final bool isFavorite;

  const UserSalon({
    required this.id,
    required this.name,
    required this.address,
    required this.contact,
    required this.isOpenNow,
    required this.waitMinutes,
    required this.topServices,
    required this.isFavorite,
  });

  String get locationLabel {
    final parts = address.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return address;
  }

  String get servicesLabel {
    if (topServices.isEmpty) return 'Popular services will appear here';
    return topServices.join(', ');
  }
}
