import 'package:cutline/shared/models/picked_location.dart';
import 'package:cutline/shared/screens/address_picker_screen.dart';
import 'package:cutline/shared/services/device_location_service.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class UserLocationProvider extends ChangeNotifier {
  PickedLocation? _location;
  bool _isBusy = false;
  String? _error;
  bool _initialized = false;

  PickedLocation? get location => _location;
  bool get isBusy => _isBusy;
  String? get error => _error;

  Future<void> initSilently() async {
    if (_initialized) return;
    _initialized = true;

    try {
      _setBusy(true);
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }

      final current = await _getLiveCurrentPosition();
      if (current == null) return;

      final address = await _reverseGeocode(
        current.latitude,
        current.longitude,
      );
      _location = PickedLocation(
        latitude: current.latitude,
        longitude: current.longitude,
        address: address.isEmpty ? 'Selected location' : address,
      );
      notifyListeners();
    } catch (_) {
      // Silent init should never block the app.
    } finally {
      _setBusy(false);
    }
  }

  Future<void> pickLocation(BuildContext context) async {
    if (_isBusy) return;
    _setBusy(true);
    _setError(null);
    try {
      final current = _location;
      final picked = await Navigator.of(context).push<PickedLocation>(
        buildAddressPickerRoute(
          AddressPickerScreen(
            title: 'Choose your location',
            initialAddress: current?.address,
            initialLocation: current == null
                ? null
                : LatLng(current.latitude, current.longitude),
            selectCurrentLocationOnOpen: current == null,
          ),
        ),
      );

      if (picked == null) return;
      _location = picked;
      notifyListeners();
    } catch (e) {
      _setError('Could not set location. Please try again.');
    } finally {
      _setBusy(false);
    }
  }

  void _setBusy(bool value) {
    _isBusy = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  Future<Position?> _getLiveCurrentPosition() async {
    try {
      final precise = await DeviceLocationService.getPreciseCurrentLocation(
        timeout: const Duration(seconds: 10),
        maxAge: Duration.zero,
        maxAccuracyMeters: 120,
      );
      if (precise != null) {
        return Position(
          latitude: precise.latitude,
          longitude: precise.longitude,
          timestamp: DateTime.fromMillisecondsSinceEpoch(precise.timestampMs),
          accuracy: precise.accuracy,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          floor: null,
          speed: 0,
          speedAccuracy: 0,
          isMocked: precise.isMocked,
        );
      }
    } on DeviceLocationException {
      // Fall back to geolocator current position below.
    } catch (_) {
      // Fall back to geolocator current position below.
    }

    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 12),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> _reverseGeocode(double lat, double lng) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      return _formatPlacemark(placemarks);
    } catch (_) {
      return '';
    }
  }

  String _formatPlacemark(List<Placemark> placemarks) {
    if (placemarks.isEmpty) return '';
    for (final place in placemarks) {
      final primary = _joinPlacemarkParts([
        place.street,
        place.thoroughfare,
        place.subThoroughfare,
        place.name,
      ], maxParts: 2);
      final area = _joinPlacemarkParts([
        place.subLocality,
        place.locality,
        place.subAdministrativeArea,
        place.administrativeArea,
      ], maxParts: 3);
      if (primary.isNotEmpty && area.isNotEmpty) {
        return '$primary, $area';
      }
      if (primary.isNotEmpty) return primary;
      if (area.isNotEmpty) return area;
    }
    return '';
  }

  String _joinPlacemarkParts(List<String?> parts, {required int maxParts}) {
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
