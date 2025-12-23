import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/shared/models/picked_location.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class UserHomeProvider extends ChangeNotifier {
  UserHomeProvider({FirebaseFirestore? firestore, this.userId = ''})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final String userId;

  bool _isLoading = false;
  String? _error;
  List<UserSalon> _allSalons = [];
  List<UserSalon> _visibleSalons = [];
  Set<String> _favoriteIds = {};
  String _searchQuery = '';
  PickedLocation? _userLocation;

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<UserSalon> get salons => _visibleSalons;
  String get searchQuery => _searchQuery;

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

      // Load favorites first
      try {
        _favoriteIds = await _loadFavoriteIds();
      } catch (e) {
        _favoriteIds = {}; // Continue without favorites
      }

      // Load salons collection
      final snapshot = await _firestore
          .collection('salons')
          .where('verificationStatus', isEqualTo: 'verified')
          .get();

      if (snapshot.docs.isEmpty) {
        _allSalons = [];
        _visibleSalons = [];
        _setError(null); // No error, just empty list
        return;
      }

      final salons = await Future.wait(
        snapshot.docs.map((doc) => _mapSalon(doc.id, doc.data())),
      );
      _allSalons = salons;
      _recomputeVisibleSalons();
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

  Future<UserSalon> _mapSalon(String id, Map<String, dynamic> data) async {
    try {
      final servicesField = data['services'];
      final services = servicesField is List
          ? servicesField
              .map((item) => _parseServiceName(item))
              .where((name) => name.isNotEmpty)
              .toList()
          : <String>[];

      final isOpenFlag = data['isOpen'];
      final bool isOpenNow = isOpenFlag is bool ? isOpenFlag : false;

      final locationField = data['location'];
      final GeoPoint? geoPoint =
          locationField is GeoPoint ? locationField : null;

      // Estimate wait time (this may fail due to permissions, but shouldn't break salon loading)
      int waitMinutes = 0;
      try {
        waitMinutes = await _estimateWaitMinutes(id);
      } catch (e) {
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

      if (snap.docs.isEmpty) {
        return 0;
      }

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
        return avg;
      }
      final fallback = snap.size * 10;
      return fallback;
    } catch (e) {
      // Return 0 if queue read fails - users can still see salons without wait time
      return 0;
    }
  }

  Future<Set<String>> _loadFavoriteIds() async {
    if (userId.isEmpty) {
      return {};
    }
    try {
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
      return favorites;
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
            salon.distanceMeters != null &&
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
