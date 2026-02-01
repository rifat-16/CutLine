import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/shared/models/picked_location.dart';
import 'package:cutline/shared/services/firestore_cache.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class UserHomeProvider extends ChangeNotifier {
  UserHomeProvider({FirebaseFirestore? firestore, this.userId = ''})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String userId;

  static const int _pageSize = 12;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  List<UserSalon> _allSalons = [];
  List<UserSalon> _visibleSalons = [];
  Set<String> _favoriteIds = {};
  String _searchQuery = '';
  PickedLocation? _userLocation;
  DocumentSnapshot<Map<String, dynamic>>? _lastSalonDoc;
  bool _hasMore = true;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  List<UserSalon> get salons => _visibleSalons;
  String get searchQuery => _searchQuery;
  bool get canLoadMore => _hasMore && !_isLoadingMore;

  void setUserLocation(PickedLocation? location) {
    final current = _userLocation;
    if (current != null &&
        location != null &&
        current.latitude == location.latitude &&
        current.longitude == location.longitude) {
      return;
    }
    if (current == null && location == null) return;
    _userLocation = location;
    _recomputeVisibleSalons();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    _recomputeVisibleSalons();
    notifyListeners();
  }

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    try {
      _allSalons = [];
      _visibleSalons = [];
      _lastSalonDoc = null;
      _hasMore = true;
      // Load favorites first
      try {
        _favoriteIds = await _loadFavoriteIds();
      } catch (e) {
        _favoriteIds = {}; // Continue without favorites
      }

      await _loadNextPage();
    } catch (e) {
      _allSalons = [];
      _visibleSalons = [];

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

  Future<void> loadMore() async {
    if (!_hasMore || _isLoadingMore) return;
    _isLoadingMore = true;
    notifyListeners();
    try {
      await _loadNextPage();
    } catch (_) {
      // Ignore incremental load failures; keep existing data.
    } finally {
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> _loadNextPage() async {
    if (!_hasMore) return;
    try {
      Query<Map<String, dynamic>> query = _firestore
          .collection('salons_summary')
          .limit(_pageSize);

      if (_lastSalonDoc != null) {
        query = query.startAfterDocument(_lastSalonDoc!);
      }

      final snapshot = await FirestoreCache.getQuery(query);

      if (snapshot.docs.isEmpty) {
        _hasMore = false;
        if (_allSalons.isEmpty) {
          _setError(null);
        }
        return;
      }

      _lastSalonDoc = snapshot.docs.last;
      if (snapshot.docs.length < _pageSize) {
        _hasMore = false;
      }

      final salons = await Future.wait(
        snapshot.docs.map((doc) => _mapSalon(doc.id, doc.data())),
      );

      final merged = <String, UserSalon>{
        for (final salon in _allSalons) salon.id: salon,
      };
      for (final salon in salons) {
        merged[salon.id] = salon;
      }
      _allSalons = merged.values.toList();
      _recomputeVisibleSalons();
    } catch (e) {
      _hasMore = false;
      rethrow;
    }
  }

  Future<UserSalon> _mapSalon(String id, Map<String, dynamic> data) async {
    try {
      final topServices = _parseTopServices(data['topServices']);
      final services = topServices.isNotEmpty ? topServices : const <String>[];

      final isOpenFlag = data['isOpen'];
      final bool isOpenNow = isOpenFlag is bool ? isOpenFlag : false;

      final locationField = data['location'];
      final GeoPoint? geoPoint =
          locationField is GeoPoint ? locationField : null;

      final waitMinutes = _summaryWaitMinutes(data);

      final salon = UserSalon(
        id: id,
        name: (data['name'] as String?) ?? 'Salon',
        address: (data['address'] as String?) ?? 'Address unavailable',
        contact: (data['contact'] as String?) ?? '',
        isOpenNow: isOpenNow,
        waitMinutes: waitMinutes,
        topServices: services.take(3).toList(),
        isFavorite: _favoriteIds.contains(id),
        geoPoint: geoPoint,
        coverImageUrl: (data['coverImageUrl'] as String?) ??
            (data['coverPhoto'] as String?),
      );

      return salon;
    } catch (e) {
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
        geoPoint: null,
        coverImageUrl: null,
      );
    }
  }

  List<String> _parseTopServices(dynamic field) {
    if (field is List) {
      return field
          .map((e) => e is String
              ? e.trim()
              : e is Map<String, dynamic>
                  ? (e['name'] as String?)?.trim() ?? ''
                  : '')
          .where((e) => e.isNotEmpty)
          .take(3)
          .toList();
    }
    return [];
  }

  int _summaryWaitMinutes(Map<String, dynamic> data) {
    final candidates = [
      data['avgWaitMinutes'],
    ];
    for (final value in candidates) {
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  Future<Set<String>> _loadFavoriteIds() async {
    if (userId.isEmpty) {
      return {};
    }
    try {
      final userDoc = await FirestoreCache.getDoc(
        _firestore.collection('users').doc(userId),
      );
      final data = userDoc.data();
      if (data == null) return {};
      final raw = data['favoriteSalonIds'];
      if (raw is List) {
        return raw.whereType<String>().where((id) => id.isNotEmpty).toSet();
      }
      return {};
    } catch (e) {
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

  void _recomputeVisibleSalons() {
    final userLocation = _userLocation;
    final radiusMeters = 5000.0;
    final query = _searchQuery.toLowerCase().trim();

    if (userLocation == null) {
      _visibleSalons = [];
      return;
    }

    Iterable<UserSalon> list = _allSalons;
    list = list
        .map((salon) {
          final point = salon.geoPoint;
          if (point == null) return salon.copyWith(distanceMeters: null);
          final distance = Geolocator.distanceBetween(
            userLocation.latitude,
            userLocation.longitude,
            point.latitude,
            point.longitude,
          );
          return salon.copyWith(distanceMeters: distance);
        })
        .where((salon) =>
            salon.distanceMeters == null ||
            salon.distanceMeters! <= radiusMeters);

    if (query.isNotEmpty) {
      list = list.where((salon) {
        final nameMatch = salon.name.toLowerCase().contains(query);
        final addressMatch = salon.address.toLowerCase().contains(query);
        final servicesMatch = salon.topServices.any(
          (service) => service.toLowerCase().contains(query),
        );
        return nameMatch || addressMatch || servicesMatch;
      });
    }

    final sorted = list.toList();
    sorted.sort((a, b) {
      final da = a.distanceMeters;
      final db = b.distanceMeters;
      if (da != null && db != null) {
        final distanceCompare = da.compareTo(db);
        if (distanceCompare != 0) return distanceCompare;
      } else if (da != null) {
        return -1;
      } else if (db != null) {
        return 1;
      }
      return a.name.compareTo(b.name);
    });

    _visibleSalons = sorted;
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
  final GeoPoint? geoPoint;
  final double? distanceMeters;
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
    required this.geoPoint,
    this.distanceMeters,
    this.coverImageUrl,
  });

  UserSalon copyWith({
    bool? isFavorite,
    double? distanceMeters,
  }) {
    return UserSalon(
      id: id,
      name: name,
      address: address,
      contact: contact,
      isOpenNow: isOpenNow,
      waitMinutes: waitMinutes,
      topServices: topServices,
      isFavorite: isFavorite ?? this.isFavorite,
      geoPoint: geoPoint,
      distanceMeters: distanceMeters,
      coverImageUrl: coverImageUrl,
    );
  }

  String get locationLabel {
    final parts = address.split(',');
    if (parts.length >= 2) {
      return '${parts[0].trim()}, ${parts[1].trim()}';
    }
    return address;
  }

  String get distanceLabel {
    final meters = distanceMeters;
    if (meters == null) return 'nearby';
    final km = meters / 1000.0;
    if (km < 1) {
      return '${km.toStringAsFixed(1)} km';
    }
    if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    }
    return '${km.toStringAsFixed(0)} km';
  }

  String get servicesLabel {
    if (topServices.isEmpty) return 'Popular services will appear here';
    return topServices.join(', ');
  }
}
