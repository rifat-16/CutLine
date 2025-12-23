import 'package:cloud_firestore/cloud_firestore.dart';

class PickedLocation {
  const PickedLocation({
    required this.latitude,
    required this.longitude,
    required this.address,
  });

  final double latitude;
  final double longitude;
  final String address;

  GeoPoint toGeoPoint() => GeoPoint(latitude, longitude);
}

