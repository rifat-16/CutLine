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
    for (final placemark in placemarks) {
      final label = _buildPlacemarkLabel(placemark);
      if (label.isNotEmpty) return label;
    }
    return '';
  }

  static String _buildPlacemarkLabel(Placemark place) {
    final primary = _joinUnique([
      place.street,
      place.thoroughfare,
      place.subThoroughfare,
      place.name,
    ], maxParts: 2);
    final area = _joinUnique([
      place.subLocality,
      place.locality,
      place.subAdministrativeArea,
      place.administrativeArea,
    ], maxParts: 3);

    if (primary.isNotEmpty && area.isNotEmpty) {
      return '$primary, $area';
    }
    if (primary.isNotEmpty) return primary;
    return area;
  }

  static String _joinUnique(List<String?> parts, {required int maxParts}) {
    final unique = <String>[];
    for (final part in parts) {
      final normalized = part?.trim() ?? '';
      if (normalized.isEmpty) continue;
      final lower = normalized.toLowerCase();
      if (unique.any((existing) => existing.toLowerCase() == lower)) {
        continue;
      }
      unique.add(normalized);
      if (unique.length >= maxParts) break;
    }
    return unique.join(', ');
  }
}
