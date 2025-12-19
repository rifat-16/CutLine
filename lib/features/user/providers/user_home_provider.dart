import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class UserHomeProvider extends ChangeNotifier {
  UserHomeProvider({FirebaseFirestore? firestore, this.userId = ''})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String userId;

  bool _isLoading = false;
  String? _error;
  List<UserSalon> _salons = [];
  List<UserSalon> _allSalons = [];
  Set<String> _favoriteIds = {};
  String _searchQuery = '';

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserSalon> get salons => _filteredSalons;
  String get searchQuery => _searchQuery;

  List<UserSalon> get _filteredSalons {
    if (_searchQuery.trim().isEmpty) {
      return _allSalons;
    }
    final query = _searchQuery.toLowerCase().trim();
    return _allSalons.where((salon) {
      final nameMatch = salon.name.toLowerCase().contains(query);
      final addressMatch = salon.address.toLowerCase().contains(query);
      final servicesMatch = salon.topServices.any(
        (service) => service.toLowerCase().contains(query),
      );
      return nameMatch || addressMatch || servicesMatch;
    }).toList();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    try {
      debugPrint('UserHomeProvider: Starting to load salons');

      // Load favorites first
      try {
        _favoriteIds = await _loadFavoriteIds();
        debugPrint('UserHomeProvider: Loaded ${_favoriteIds.length} favorites');
      } catch (e) {
        debugPrint('UserHomeProvider: Error loading favorites: $e');
        _favoriteIds = {}; // Continue without favorites
      }

      // Load salons collection
      final snapshot = await _firestore
          .collection('salons')
          .where('verificationStatus', isEqualTo: 'verified')
          .get();
      debugPrint(
          'UserHomeProvider: Found ${snapshot.docs.length} salon documents');

      if (snapshot.docs.isEmpty) {
        debugPrint('UserHomeProvider: No salons found in database');
        _allSalons = [];
        _setError(null); // No error, just empty list
        return;
      }

      final salons = await Future.wait(
        snapshot.docs.map((doc) => _mapSalon(doc.id, doc.data())),
      );
      salons.sort((a, b) => a.name.compareTo(b.name));
      _allSalons = salons;
      debugPrint(
          'UserHomeProvider: Successfully loaded ${_allSalons.length} salons');
    } catch (e, stackTrace) {
      debugPrint('UserHomeProvider: Error loading salons: $e');
      debugPrint('Error code: ${e is FirebaseException ? e.code : "unknown"}');
      debugPrint('Stack trace: $stackTrace');
      _allSalons = [];

      String errorMessage = 'Failed to load salons. Pull to refresh.';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          errorMessage =
              'Salons are not available right now. Please try again later.';
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

  Future<UserSalon> _mapSalon(String id, Map<String, dynamic> data) async {
    try {
      debugPrint('_mapSalon: Mapping salon $id');
      final servicesField = data['services'];
      final services = servicesField is List
          ? servicesField
              .map((item) => _parseServiceName(item))
              .where((name) => name.isNotEmpty)
              .toList()
          : <String>[];

      final isOpenFlag = data['isOpen'];
      final bool isOpenNow = isOpenFlag is bool ? isOpenFlag : false;

      // Estimate wait time (this may fail due to permissions, but shouldn't break salon loading)
      int waitMinutes = 0;
      try {
        waitMinutes = await _estimateWaitMinutes(id);
      } catch (e) {
        debugPrint('_mapSalon: Error estimating wait time for $id: $e');
        // Continue without wait time
      }

      final salon = UserSalon(
        id: id,
        name: (data['name'] as String?) ?? 'Salon',
        address: (data['address'] as String?) ?? 'Address unavailable',
        contact: (data['contact'] as String?) ?? '',
        isOpenNow: isOpenNow,
        waitMinutes: waitMinutes,
        topServices: services.take(3).toList(),
        isFavorite: _favoriteIds.contains(id),
        coverImageUrl: (data['coverImageUrl'] as String?) ??
            (data['coverPhoto'] as String?),
      );

      debugPrint('_mapSalon: Successfully mapped salon ${salon.name}');
      return salon;
    } catch (e) {
      debugPrint('_mapSalon: Error mapping salon $id: $e');
      // Return a default salon rather than failing completely
      return UserSalon(
        id: id,
        name: (data['name'] as String?) ?? 'Salon',
        address: (data['address'] as String?) ?? 'Address unavailable',
        contact: (data['contact'] as String?) ?? '',
        isOpenNow: false,
        waitMinutes: 0,
        topServices: <String>[],
        isFavorite: _favoriteIds.contains(id),
        coverImageUrl: null,
      );
    }
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
      debugPrint(
          '_estimateWaitMinutes: Estimating wait time for salonId: $salonId');
      final snap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .where('status', isEqualTo: 'waiting')
          .get();

      if (snap.docs.isEmpty) {
        debugPrint('_estimateWaitMinutes: No waiting queue items found');
        return 0;
      }

      debugPrint(
          '_estimateWaitMinutes: Found ${snap.docs.length} waiting items');
      var collected = 0;
      var items = 0;
      for (final doc in snap.docs) {
        final wait = (doc.data()['waitMinutes'] as num?)?.toInt();
        if (wait != null && wait > 0) {
          collected += wait;
          items++;
        }
      }
      if (items > 0) {
        final avg = (collected / items).ceil();
        debugPrint('_estimateWaitMinutes: Average wait time: $avg minutes');
        return avg;
      }
      final fallback = snap.size * 10;
      debugPrint(
          '_estimateWaitMinutes: Using fallback estimate: $fallback minutes');
      return fallback;
    } catch (e) {
      debugPrint('_estimateWaitMinutes: Error estimating wait time: $e');
      debugPrint('Error code: ${e is FirebaseException ? e.code : "unknown"}');
      // Return 0 if queue read fails - users can still see salons without wait time
      return 0;
    }
  }

  Future<Set<String>> _loadFavoriteIds() async {
    if (userId.isEmpty) {
      debugPrint('_loadFavoriteIds: userId is empty, returning empty set');
      return {};
    }
    try {
      debugPrint('_loadFavoriteIds: Loading favorites for userId: $userId');
      final snap = await _firestore
          .collection('users')
          .doc(userId)
          .collection('favorites')
          .get();
      final favorites = snap.docs
          .map((doc) {
            final data = doc.data();
            final salonId = data['salonId'];
            if (salonId is String && salonId.isNotEmpty) return salonId;
            return doc.id;
          })
          .where((id) => id.isNotEmpty)
          .toSet();
      debugPrint('_loadFavoriteIds: Loaded ${favorites.length} favorites');
      return favorites;
    } catch (e) {
      debugPrint('_loadFavoriteIds: Error loading favorites: $e');
      debugPrint('Error code: ${e is FirebaseException ? e.code : "unknown"}');
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
  final String? coverImageUrl;

  const UserSalon({
    required this.id,
    required this.name,
    required this.address,
    required this.contact,
    required this.isOpenNow,
    required this.waitMinutes,
    required this.topServices,
    required this.isFavorite,
    this.coverImageUrl,
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
