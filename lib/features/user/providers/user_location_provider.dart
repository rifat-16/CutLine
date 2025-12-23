import 'package:cutline/shared/models/picked_location.dart';
import 'package:cutline/shared/screens/address_picker_screen.dart';
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
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      final permission = await Geolocator.checkPermission();
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        return;
      }

      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown == null) return;

      final address = await _reverseGeocode(
        lastKnown.latitude,
        lastKnown.longitude,
      );
      _location = PickedLocation(
        latitude: lastKnown.latitude,
        longitude: lastKnown.longitude,
        address: address.isEmpty ? 'Selected location' : address,
      );
      notifyListeners();
    } catch (_) {
      // Silent init should never block the app.
    }
  }

  Future<void> pickLocation(BuildContext context) async {
    if (_isBusy) return;
    _setBusy(true);
    _setError(null);
    try {
      final current = _location;
      final picked = await Navigator.of(context).push<PickedLocation>(
        MaterialPageRoute(
          builder: (_) => AddressPickerScreen(
            title: 'Choose your location',
            initialAddress: current?.address,
            initialLocation: current == null
                ? null
                : LatLng(current.latitude, current.longitude),
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
