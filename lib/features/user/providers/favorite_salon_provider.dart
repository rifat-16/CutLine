import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cutline/shared/services/firestore_cache.dart';

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
    final userDoc =
        await FirestoreCache.getDoc(_firestore.collection('users').doc(userId));
    final data = userDoc.data();
    if (data == null) return [];
    final raw = data['favoriteSalonIds'];
    if (raw is List) {
      return raw.whereType<String>().where((id) => id.isNotEmpty).toList();
    }
    return [];
  }

  Future<FavoriteSalon?> _fetchSalon(String salonId) async {
    try {
      final doc = await FirestoreCache.getDoc(
          _firestore.collection('salons_summary').doc(salonId));
      final data = doc.data();
      if (data == null) return null;
      final waitMinutes = _summaryWaitMinutes(data);
      final isOpenFlag = data['isOpen'];
      final bool isOpenNow = isOpenFlag is bool ? isOpenFlag : false;
      return FavoriteSalon(
        id: salonId,
        name: (data['name'] as String?) ?? 'Salon',
        address: (data['address'] as String?) ?? 'Address unavailable',
        isOpen: isOpenNow,
        waitMinutes: waitMinutes,
        rating: (data['rating'] as num?)?.toDouble() ?? 4.6,
        reviews: (data['reviews'] as num?)?.toInt() ?? 120,
        topServices: _parseTopServices(data['topServices']),
        coverImageUrl: (data['coverImageUrl'] as String?) ??
            (data['coverPhoto'] as String?),
      );
    } catch (_) {
      return null;
    }
  }

  List<String> _parseTopServices(dynamic topServices) {
    if (topServices is List) {
      final names = topServices
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      if (names.isNotEmpty) return names.take(3).toList();
    }
    return const [];
  }

  int _summaryWaitMinutes(Map<String, dynamic> data) {
    final value = data['avgWaitMinutes'];
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
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
