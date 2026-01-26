import 'package:geocoding/geocoding.dart';

class MapsReverseGeocoder {
  static String? get lastError => null;

  static Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final placemarks = await placemarkFromCoordinates(latitude, longitude);
      return _formatPlacemark(placemarks);
    } catch (_) {
      return '';
    }
  }

  static String _formatPlacemark(List<Placemark> placemarks) {
    if (placemarks.isEmpty) return '';
    final p = placemarks.first;
    final parts = <String>[
      if ((p.name ?? '').trim().isNotEmpty) p.name!.trim(),
      if ((p.subLocality ?? '').trim().isNotEmpty) p.subLocality!.trim(),
      if ((p.locality ?? '').trim().isNotEmpty) p.locality!.trim(),
      if ((p.administrativeArea ?? '').trim().isNotEmpty)
        p.administrativeArea!.trim(),
      if ((p.postalCode ?? '').trim().isNotEmpty) p.postalCode!.trim(),
      if ((p.country ?? '').trim().isNotEmpty) p.country!.trim(),
    ];
    return parts.join(', ');
  }
}
