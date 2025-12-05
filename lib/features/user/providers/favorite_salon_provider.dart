import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class FavoriteSalonProvider extends ChangeNotifier {
  FavoriteSalonProvider({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  List<FavoriteSalon> _salons = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<FavoriteSalon> get salons => _salons;

  Future<void> load() async {
    if (userId.isEmpty) {
      _error = 'Please sign in to view favorites.';
      notifyListeners();
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final favoriteIds = await _fetchFavoriteIds();
      final salons = <FavoriteSalon>[];
      for (final salonId in favoriteIds) {
        final mapped = await _fetchSalon(salonId);
        if (mapped != null) salons.add(mapped);
      }
      salons.sort((a, b) => a.name.compareTo(b.name));
      _salons = salons;
    } catch (_) {
      _salons = [];
      _setError('Could not load favorites. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  Future<List<String>> _fetchFavoriteIds() async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('favorites')
        .get();
    return snapshot.docs.map((doc) {
      final data = doc.data();
      final id = data['salonId'];
      if (id is String && id.isNotEmpty) return id;
      return doc.id;
    }).where((id) => id.isNotEmpty).toList();
  }

  Future<FavoriteSalon?> _fetchSalon(String salonId) async {
    try {
      final doc = await _firestore.collection('salons').doc(salonId).get();
      final data = doc.data();
      if (data == null) return null;
      final waitMinutes = await _estimateWaitMinutes(salonId);
      return FavoriteSalon(
        id: salonId,
        name: (data['name'] as String?) ?? 'Salon',
        address: (data['address'] as String?) ?? 'Address unavailable',
        isOpen: (data['isOpen'] as bool?) ?? false,
        waitMinutes: waitMinutes,
        rating: (data['rating'] as num?)?.toDouble() ?? 4.6,
        reviews: (data['reviews'] as num?)?.toInt() ?? 120,
        topServices: _parseTopServices(data['topServices'], data['services']),
        coverImageUrl: data['coverImageUrl'] as String?,
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _parseTopServices(dynamic topServices, dynamic services) {
    if (topServices is List) {
      final names = topServices
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (names.isNotEmpty) return names.take(3).toList();
    }
    if (services is List) {
      return services
          .whereType<Map>()
          .map((e) => (e['name'] as String?)?.trim() ?? '')
          .where((e) => e.isNotEmpty)
          .take(3)
          .toList();
    }
    return const [];
  }

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
      var count = 0;
      for (final doc in snap.docs) {
        final wait = (doc.data()['waitMinutes'] as num?)?.toInt();
        if (wait != null && wait > 0) {
          collected += wait;
          count++;
        }
      }
      if (count > 0) return (collected / count).ceil();
      return snap.size * 10;
    } catch (_) {
      return 0;
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

class FavoriteSalon {
  final String id;
  final String name;
  final String address;
  final bool isOpen;
  final int waitMinutes;
  final double rating;
  final int reviews;
  final List<String> topServices;
  final String? coverImageUrl;

  const FavoriteSalon({
    required this.id,
    required this.name,
    required this.address,
    required this.isOpen,
    required this.waitMinutes,
    required this.rating,
    required this.reviews,
    required this.topServices,
    required this.coverImageUrl,
  });

  String get waitLabel =>
      waitMinutes <= 0 ? 'No wait' : '$waitMinutes min wait';

  String get servicesLabel =>
      topServices.isEmpty ? 'Popular services will appear here' : topServices.join(', ');
}
