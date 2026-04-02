import 'dart:async';

import 'package:cutline/shared/models/picked_location.dart';
import 'package:cutline/shared/services/device_location_service.dart';
import 'package:cutline/shared/services/google_maps_js_loader.dart';
import 'package:cutline/shared/services/maps_reverse_geocoder.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

Route<PickedLocation> buildAddressPickerRoute(AddressPickerScreen screen) {
  return PageRouteBuilder<PickedLocation>(
    pageBuilder: (context, animation, secondaryAnimation) => screen,
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInOutCubic,
      );
      final offsetAnimation = Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: offsetAnimation,
          child: child,
        ),
      );
    },
  );
}

class AddressPickerScreen extends StatefulWidget {
  const AddressPickerScreen({
    super.key,
    this.title,
    this.confirmLabel,
    this.initialAddress,
    this.initialLocation,
    this.selectCurrentLocationOnOpen = false,
  });

  final String? title;
  final String? confirmLabel;
  final String? initialAddress;
  final LatLng? initialLocation;
  final bool selectCurrentLocationOnOpen;

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

enum _LocationAction { openLocationSettings, openAppSettings }
enum _BusyAction { none, searching, locating }

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  static const _defaultLocation = LatLng(23.8103, 90.4125); // Dhaka
  static const _liveLocationAccuracyMeters = 120.0;
  static const _bootstrapLocationAccuracyMeters = 150.0;
  static const _addressRefreshThresholdMeters = 18.0;
  static const _reverseGeocodeDebounceDuration = Duration(milliseconds: 550);

  late final TextEditingController _searchController;
  late final Future<void> _mapsReadyFuture;
  GoogleMapController? _mapController;
  LatLng? _selected;
  _BusyAction _busyAction = _BusyAction.none;
  bool _isDraggingPin = false;
  bool _isResolvingAddress = false;
  bool _isLocating = false;
  bool _myLocationEnabled = false;
  bool _suppressAutoCameraSelection = false;
  int _selectionVersion = 0;
  int _mapInteractionVersion = 0;
  String? _error;
  _LocationAction? _locationAction;
  LatLng? _cameraTarget;
  LatLng? _pendingCameraTarget;
  LatLng? _lastReverseGeocodedTarget;
  Future<LatLng?>? _activeLocationRequest;
  Timer? _reverseGeocodeDebounce;

  @override
  void initState() {
    super.initState();
    final useCurrentLocationOnly = widget.selectCurrentLocationOnOpen;
    final hasInitialLocation = widget.initialLocation != null;
    final hasInitialAddress = widget.initialAddress?.trim().isNotEmpty ?? false;
    final startWithoutSelection =
        useCurrentLocationOnly || (!hasInitialLocation && !hasInitialAddress);
    _mapsReadyFuture = GoogleMapsJsLoader.ensureLoaded();
    _searchController = TextEditingController(
      text: startWithoutSelection ? '' : widget.initialAddress,
    );
    _selected = startWithoutSelection ? null : widget.initialLocation;
    _suppressAutoCameraSelection = startWithoutSelection;
    if (startWithoutSelection) {
      _searchController.clear();
    }
    _bootstrapLocationState();
  }

  @override
  void dispose() {
    _reverseGeocodeDebounce?.cancel();
    if (!kIsWeb) _mapController?.dispose();
    _mapController = null;
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final statusMessage = _statusMessage;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: Text(widget.title ?? 'Set salon location'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                _buildSearchRow(),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  if (_locationAction != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _handleLocationAction,
                        icon: Icon(
                          _locationAction == _LocationAction.openAppSettings
                              ? Icons.settings_outlined
                              : Icons.location_searching_outlined,
                        ),
                        label: Text(
                          _locationAction == _LocationAction.openAppSettings
                              ? 'Open app settings'
                              : 'Turn on location',
                        ),
                      ),
                    ),
                ],
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                FutureBuilder<void>(
                  future: _mapsReadyFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _WebMapsError(message: '${snapshot.error}');
                    }
                    return GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: selected ?? _defaultLocation,
                        zoom: selected == null ? 12 : 16,
                      ),
                      onMapCreated: _handleMapCreated,
                      onTap: _handleMapTap,
                      onLongPress: _handleMapTap,
                      onCameraMoveStarted: _handleCameraMoveStarted,
                      onCameraMove: _handleCameraMove,
                      onCameraIdle: _handleCameraIdle,
                      myLocationButtonEnabled: _myLocationEnabled,
                      myLocationEnabled: _myLocationEnabled,
                      compassEnabled: false,
                      mapToolbarEnabled: false,
                      buildingsEnabled: false,
                      indoorViewEnabled: false,
                      rotateGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      zoomControlsEnabled: false,
                      markers: const <Marker>{},
                    );
                  },
                ),
                if (selected != null) _CenterPinOverlay(isAdjusting: _isDraggingPin),
                if (statusMessage != null)
                  Positioned(
                    top: 12,
                    left: 16,
                    right: 16,
                    child: IgnorePointer(
                      child: Center(
                        child: _MapStatusPill(message: statusMessage),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed:
                      selected == null ||
                              _isBusy ||
                              _isLocating ||
                              _isResolvingAddress
                          ? null
                          : _confirm,
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(widget.confirmLabel ?? 'Confirm location'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchRow() {
    final isSearching = _isSearching;
    final isLocating = _isLocating;
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            enabled: !isSearching,
            onSubmitted: (_) => _searchAddress(),
            decoration: InputDecoration(
              hintText: 'Search address or area',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2.2),
                      ),
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        FilledButton.icon(
          onPressed: _isBusy || _isLocating ? null : _useCurrentLocation,
          icon: isLocating
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Icon(Icons.my_location),
          label: Text(isLocating ? 'Locating...' : 'My Location'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _error = 'Enter an address to search.';
        _locationAction = null;
      });
      return;
    }

    _markUserMapInteraction();
    final interactionVersion = _mapInteractionVersion;
    await _runBusy(_BusyAction.searching, () async {
      setState(() {
        _error = null;
        _locationAction = null;
      });
      try {
        final results = await locationFromAddress(query);
        if (results.isEmpty) {
          setState(() {
            _error = 'No results found for that address.';
            _locationAction = null;
          });
          return;
        }
        if (!mounted || interactionVersion != _mapInteractionVersion) return;
        final first = results.first;
        final pos = LatLng(first.latitude, first.longitude);
        _setSelected(pos, reverseGeocode: true);
        await _moveCamera(pos);
      } catch (_) {
        setState(() {
          _error = 'Could not search that address. Try another.';
          _locationAction = null;
        });
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    final interactionVersion = _mapInteractionVersion;
    _suppressAutoCameraSelection = false;
    _clearSelectedLocation();
    setState(() {
      _error = null;
      _locationAction = null;
    });
    final latLng = await _runLocationRequest(() {
      return _resolveCurrentLocation(
        requestPermission: true,
        showErrors: true,
        allowLastKnownFallback: false,
        maxAcceptedAge: const Duration(seconds: 45),
        maxAcceptedAccuracyMeters: _liveLocationAccuracyMeters,
      );
    });
    if (latLng == null) return;
    if (!mounted || interactionVersion != _mapInteractionVersion) return;
    _setSelected(latLng, reverseGeocode: true);
    await _moveCamera(latLng);
  }

  Future<void> _moveCamera(LatLng target) async {
    _pendingCameraTarget = target;
    if (!mounted) return;
    final controller = _mapController;
    if (controller == null) return;
    try {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: target, zoom: 16),
        ),
      );
      if (_sameLatLng(_pendingCameraTarget, target)) {
        _pendingCameraTarget = null;
      }
    } catch (_) {
      // Ignore camera updates when the map widget gets disposed/recreated.
    }
  }

  void _handleMapTap(LatLng pos) {
    _markUserMapInteraction();
    _suppressAutoCameraSelection = false;
    _setSelected(pos, reverseGeocode: _shouldRefreshAddressFor(pos));
    _moveCamera(pos);
  }

  void _handleCameraMoveStarted() {
    _reverseGeocodeDebounce?.cancel();
    _markUserMapInteraction();
    _suppressAutoCameraSelection = false;
    if (_isDraggingPin && !_isResolvingAddress) return;
    setState(() {
      _isDraggingPin = true;
      _isResolvingAddress = false;
      _error = null;
      _locationAction = null;
    });
  }

  void _handleCameraMove(CameraPosition position) {
    _cameraTarget = position.target;
  }

  void _handleCameraIdle() {
    final target = _cameraTarget;
    if (target == null) {
      if (_isDraggingPin) {
        setState(() => _isDraggingPin = false);
      }
      return;
    }

    _cameraTarget = null;
    if (_suppressAutoCameraSelection && _selected == null) {
      if (_isDraggingPin) {
        setState(() => _isDraggingPin = false);
      }
      return;
    }
    if (_sameLatLng(_selected, target)) {
      if (_isDraggingPin) {
        setState(() => _isDraggingPin = false);
      }
      return;
    }

    setState(() => _isDraggingPin = false);
    _setSelected(target, reverseGeocode: _shouldRefreshAddressFor(target));
  }

  void _setSelected(LatLng pos, {required bool reverseGeocode}) {
    final selectionVersion = ++_selectionVersion;
    setState(() {
      _selected = pos;
      _error = null;
      _locationAction = null;
      _isResolvingAddress = reverseGeocode;
      if (reverseGeocode) {
        _searchController.clear();
      }
    });
    if (!reverseGeocode) return;

    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(_reverseGeocodeDebounceDuration, () async {
      final current = pos;
      try {
        final fallbackAddress = await _resolveAddressLabel(current);
        if (!mounted) return;
        if (!_isLatestSelection(selectionVersion, current)) return;
        _finishAddressResolution(current);
        if (fallbackAddress.isNotEmpty) {
          _searchController.text = fallbackAddress;
        } else if (MapsReverseGeocoder.lastError == 'REQUEST_DENIED') {
          setState(() {
            _error =
                'Web geocoding not enabled. Enable Google "Geocoding API" for this API key.';
          });
        } else if (_searchController.text.trim().isEmpty) {
          setState(() {
            _error = 'Could not detect this location name. Move map a bit and try again.';
          });
        }
      } catch (_) {
        final fallbackAddress = await _resolveAddressLabel(current);
        if (!mounted) return;
        if (!_isLatestSelection(selectionVersion, current)) return;
        _finishAddressResolution(current);
        if (fallbackAddress.isNotEmpty) {
          _searchController.text = fallbackAddress;
        } else if (_searchController.text.trim().isEmpty) {
          setState(() {
            _error = 'Could not detect this location name. Move map a bit and try again.';
          });
        }
      }
    });
  }

  Future<String> _resolveAddressLabel(LatLng latLng) async {
    try {
      final mapsAddress = await MapsReverseGeocoder.reverseGeocode(
        latitude: latLng.latitude,
        longitude: latLng.longitude,
      );
      if (mapsAddress.trim().isNotEmpty) {
        return mapsAddress.trim();
      }
    } catch (_) {
      // Fall through to native geocoding below.
    }
    return _reverseGeocodeFallback(latLng);
  }

  Future<String> _reverseGeocodeFallback(LatLng latLng) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        latLng.latitude,
        latLng.longitude,
      );
      if (placemarks.isEmpty) return '';
      for (final place in placemarks) {
        final label = _buildPlacemarkLabel(place);
        if (label.isNotEmpty) return label;
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  String _buildPlacemarkLabel(Placemark place) {
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
    return area;
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

  Future<void> _confirm() async {
    final selected = _selected;
    if (selected == null) return;

    var address = _searchController.text.trim();
    if (address.isEmpty) {
      setState(() {
        _isResolvingAddress = true;
        _error = null;
      });
      final resolved = await _resolveAddressLabel(selected);
      if (!mounted) return;
      setState(() => _isResolvingAddress = false);
      if (resolved.isEmpty) {
        setState(() {
          _error = 'Could not detect this location name. Move map a bit and try again.';
        });
        return;
      }
      address = resolved;
      _searchController.text = resolved;
    }

    Navigator.pop(
      context,
      PickedLocation(
        latitude: selected.latitude,
        longitude: selected.longitude,
        address: address,
      ),
    );
  }

  Future<void> _bootstrapLocationState() async {
    if (widget.selectCurrentLocationOnOpen ||
        (widget.initialLocation == null &&
            !(widget.initialAddress?.trim().isNotEmpty ?? false))) {
      _clearSelectedLocation();
    }
    await _syncMyLocationAvailability();

    if (widget.selectCurrentLocationOnOpen) {
      final interactionVersion = _mapInteractionVersion;
      final latLng = await _runLocationRequest(() {
        return _resolveCurrentLocation(
          requestPermission: true,
          showErrors: false,
          allowLastKnownFallback: false,
          maxAcceptedAge: const Duration(seconds: 45),
          maxAcceptedAccuracyMeters: _bootstrapLocationAccuracyMeters,
        );
      });
      if (latLng == null) return;
      if (!mounted || interactionVersion != _mapInteractionVersion) return;
      _suppressAutoCameraSelection = false;
      _setSelected(latLng, reverseGeocode: true);
      await _moveCamera(latLng);
      return;
    }

    final hasInitialLocation = widget.initialLocation != null;
    final hasInitialAddress = widget.initialAddress?.trim().isNotEmpty ?? false;
    if (hasInitialLocation || hasInitialAddress) {
      return;
    }

    final interactionVersion = _mapInteractionVersion;
    final latLng = await _runLocationRequest(() {
      return _resolveCurrentLocation(
        requestPermission: false,
        showErrors: false,
        allowLastKnownFallback: false,
        maxAcceptedAge: const Duration(seconds: 45),
        maxAcceptedAccuracyMeters: _bootstrapLocationAccuracyMeters,
      );
    });
    if (latLng == null) return;
    if (!mounted || interactionVersion != _mapInteractionVersion) return;
    _suppressAutoCameraSelection = false;
    _setSelected(latLng, reverseGeocode: true);
    await _moveCamera(latLng);
  }

  void _handleMapCreated(GoogleMapController controller) {
    _mapController = controller;
    final target = _pendingCameraTarget;
    if (target == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _moveCamera(target);
    });
  }

  Future<void> _syncMyLocationAvailability() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final permission = await Geolocator.checkPermission();
      final enabled = serviceEnabled && _hasLocationPermission(permission);
      if (!mounted || _myLocationEnabled == enabled) return;
      setState(() => _myLocationEnabled = enabled);
    } catch (_) {
      // Ignore. The map can still render without the user location layer.
    }
  }

  Future<LatLng?> _resolveCurrentLocation({
    required bool requestPermission,
    required bool showErrors,
    required bool allowLastKnownFallback,
    required Duration maxAcceptedAge,
    required double maxAcceptedAccuracyMeters,
  }) async {
    try {
      var permission = await Geolocator.checkPermission();
      if (!_hasLocationPermission(permission) && requestPermission) {
        permission = await Geolocator.requestPermission();
      }

      final hasPermission = _hasLocationPermission(permission);
      if (mounted && _myLocationEnabled != hasPermission) {
        setState(() => _myLocationEnabled = hasPermission);
      }
      if (!hasPermission) {
        if (showErrors && mounted) {
          setState(() {
            _error = permission == LocationPermission.deniedForever
                ? 'Location permission is blocked. Enable it from app settings.'
                : 'Allow location permission to use your current location.';
            _locationAction = permission == LocationPermission.deniedForever
                ? _LocationAction.openAppSettings
                : null;
          });
        }
        return null;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      final canPromptInApp = _canPromptAndroidLocationResolution();
      if (!serviceEnabled && !canPromptInApp) {
        if (showErrors && mounted) {
          setState(
            () {
              _error = 'Turn on location services to use your current location.';
              _locationAction = _LocationAction.openLocationSettings;
            },
          );
        }
        await _syncMyLocationAvailability();
        return null;
      }

      final lastKnown =
          allowLastKnownFallback ? await Geolocator.getLastKnownPosition() : null;
      try {
        final nativeAndroidLocation = await _tryNativeAndroidLocation(
          maxAcceptedAge: maxAcceptedAge,
          maxAcceptedAccuracyMeters: maxAcceptedAccuracyMeters,
          showErrors: showErrors,
        );
        if (nativeAndroidLocation != null) {
          return nativeAndroidLocation;
        }

        final current = await _getFreshCurrentPosition(
          maxAcceptedAge: maxAcceptedAge,
          maxAcceptedAccuracyMeters: maxAcceptedAccuracyMeters,
          preferLiveStream: !serviceEnabled && canPromptInApp,
        );
        if (current != null) {
          return LatLng(current.latitude, current.longitude);
        }
      } catch (_) {
        // Fall through to last-known fallback / final error below.
      }

      if (lastKnown != null &&
          _isAcceptablePosition(
            lastKnown,
            maxAcceptedAge: maxAcceptedAge,
            maxAcceptedAccuracyMeters: maxAcceptedAccuracyMeters,
          )) {
        return LatLng(lastKnown.latitude, lastKnown.longitude);
      }

      if (showErrors && mounted) {
        setState(() {
          _error = allowLastKnownFallback
              ? 'Could not get your latest location right now.'
              : 'Could not get an accurate live current location. Turn on GPS and try again.';
          _locationAction = _LocationAction.openLocationSettings;
        });
      }
      return null;
    } catch (_) {
      if (showErrors && mounted) {
        setState(() {
          _error = 'Could not get your current location.';
          _locationAction = _LocationAction.openLocationSettings;
        });
      }
      return null;
    }
  }

  bool _hasLocationPermission(LocationPermission permission) {
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  Future<Position?> _getFreshCurrentPosition({
    required Duration maxAcceptedAge,
    required double maxAcceptedAccuracyMeters,
    bool preferLiveStream = false,
  }) async {
    final primarySettings = _locationSettings();
    if (preferLiveStream) {
      final streamed = await _waitForAccuratePosition(
        settings: primarySettings,
        maxAcceptedAge: maxAcceptedAge,
        maxAcceptedAccuracyMeters: maxAcceptedAccuracyMeters,
      );
      if (streamed != null) {
        return streamed;
      }
    }

    final direct = await _tryCurrentPosition(primarySettings);
    if (direct != null &&
        _isAcceptablePosition(
          direct,
          maxAcceptedAge: maxAcceptedAge,
          maxAcceptedAccuracyMeters: maxAcceptedAccuracyMeters,
        )) {
      return direct;
    }

    final streamed = await _waitForAccuratePosition(
      settings: primarySettings,
      maxAcceptedAge: maxAcceptedAge,
      maxAcceptedAccuracyMeters: maxAcceptedAccuracyMeters,
    );
    if (streamed != null) {
      return streamed;
    }

    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      final legacySettings =
          _locationSettings(forceAndroidLocationManager: true);
      final legacyDirect = await _tryCurrentPosition(legacySettings);
      if (legacyDirect != null &&
          _isAcceptablePosition(
            legacyDirect,
            maxAcceptedAge: maxAcceptedAge,
            maxAcceptedAccuracyMeters: maxAcceptedAccuracyMeters,
          )) {
        return legacyDirect;
      }

      final legacyStreamed = await _waitForAccuratePosition(
        settings: legacySettings,
        maxAcceptedAge: maxAcceptedAge,
        maxAcceptedAccuracyMeters: maxAcceptedAccuracyMeters,
      );
      if (legacyStreamed != null) {
        return legacyStreamed;
      }
    }

    return null;
  }

  Future<LatLng?> _tryNativeAndroidLocation({
    required Duration maxAcceptedAge,
    required double maxAcceptedAccuracyMeters,
    required bool showErrors,
  }) async {
    if (!DeviceLocationService.supportsNativePreciseLocation) return null;

    try {
      final result = await DeviceLocationService.getPreciseCurrentLocation(
        timeout: const Duration(seconds: 18),
        maxAge: maxAcceptedAge,
        maxAccuracyMeters: maxAcceptedAccuracyMeters,
      );
      if (result == null) return null;
      if (result.isMocked) {
        if (showErrors && mounted) {
          setState(() {
            _error =
                'Mock location detected. Turn off mock location in developer options.';
            _locationAction = _LocationAction.openLocationSettings;
          });
        }
        return null;
      }
      return LatLng(result.latitude, result.longitude);
    } on DeviceLocationException catch (e) {
      if (!showErrors || !mounted) return null;

      setState(() {
        switch (e.code) {
          case 'IN_PROGRESS':
            _error = null;
            _locationAction = null;
            break;
          case 'SERVICE_DISABLED':
          case 'RESOLUTION_CANCELLED':
            _error = 'Turn on GPS to use your live current location.';
            _locationAction = _LocationAction.openLocationSettings;
            break;
          case 'MOCK_LOCATION':
            _error =
                'Mock location detected. Turn off mock location in developer options.';
            _locationAction = _LocationAction.openLocationSettings;
            break;
          case 'PERMISSION_DENIED':
            _error = 'Allow location permission to use your current location.';
            _locationAction = null;
            break;
          case 'PRECISE_PERMISSION_REQUIRED':
            _error =
                'Enable precise location permission. Approximate location can be wrong.';
            _locationAction = _LocationAction.openAppSettings;
            break;
          case 'PERMISSION_DENIED_FOREVER':
            _error = 'Location permission is blocked. Enable it from app settings.';
            _locationAction = _LocationAction.openAppSettings;
            break;
          default:
            _error = e.message;
            _locationAction = null;
        }
      });
      return null;
    }
  }

  Future<Position?> _tryCurrentPosition(LocationSettings settings) async {
    try {
      return await Geolocator.getCurrentPosition(locationSettings: settings);
    } catch (_) {
      return null;
    }
  }

  Future<Position?> _waitForAccuratePosition({
    required LocationSettings settings,
    required Duration maxAcceptedAge,
    required double maxAcceptedAccuracyMeters,
  }) async {
    Position? best;
    StreamSubscription<Position>? subscription;
    Timer? timer;
    final completer = Completer<Position?>();

    void complete(Position? position) {
      if (!completer.isCompleted) {
        completer.complete(position);
      }
    }

    try {
      subscription = Geolocator.getPositionStream(
        locationSettings: settings,
      ).listen(
        (position) {
          if (!_isPositionFresh(position, maxAcceptedAge)) return;
          if (best == null || position.accuracy < best!.accuracy) {
            best = position;
          }
          if (_isPositionAccurateEnough(position, maxAcceptedAccuracyMeters)) {
            complete(position);
          }
        },
        onError: (_) => complete(null),
      );

      timer = Timer(const Duration(seconds: 10), () => complete(best));
      final position = await completer.future;
      if (position == null) return null;
      return _isAcceptablePosition(
        position,
        maxAcceptedAge: maxAcceptedAge,
        maxAcceptedAccuracyMeters: maxAcceptedAccuracyMeters,
      )
          ? position
          : null;
    } finally {
      timer?.cancel();
      await subscription?.cancel();
    }
  }

  LocationSettings _locationSettings({
    bool forceAndroidLocationManager = false,
  }) {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return AndroidSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        forceLocationManager: forceAndroidLocationManager,
        timeLimit: const Duration(seconds: 15),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        timeLimit: const Duration(seconds: 15),
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.bestForNavigation,
      timeLimit: Duration(seconds: 15),
    );
  }

  bool _isPositionFresh(Position position, Duration maxAcceptedAge) {
    final age = DateTime.now().difference(position.timestamp);
    return age <= maxAcceptedAge;
  }

  bool _isLatestSelection(int version, LatLng position) {
    return version == _selectionVersion && _sameLatLng(_selected, position);
  }

  bool _canPromptAndroidLocationResolution() {
    return !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  }

  bool _isPositionAccurateEnough(
    Position position,
    double maxAcceptedAccuracyMeters,
  ) {
    final accuracy = position.accuracy;
    if (accuracy <= 0) return false;
    return accuracy <= maxAcceptedAccuracyMeters;
  }

  bool _isAcceptablePosition(
    Position position, {
    required Duration maxAcceptedAge,
    required double maxAcceptedAccuracyMeters,
  }) {
    return _isPositionFresh(position, maxAcceptedAge) &&
        _isPositionAccurateEnough(position, maxAcceptedAccuracyMeters);
  }

  bool _sameLatLng(LatLng? a, LatLng b) {
    if (a == null) return false;
    return (a.latitude - b.latitude).abs() < 0.000001 &&
        (a.longitude - b.longitude).abs() < 0.000001;
  }

  String? get _statusMessage {
    switch (_busyAction) {
      case _BusyAction.searching:
        return 'Searching address...';
      case _BusyAction.locating:
        return _isLocating ? 'Getting current location...' : null;
      case _BusyAction.none:
        if (_isLocating) return 'Getting current location...';
        if (_isDraggingPin) return 'Release map to set location';
        if (_isResolvingAddress) return 'Updating address...';
        return null;
    }
  }

  Future<void> _runBusy(
    _BusyAction action,
    Future<void> Function() task,
  ) async {
    if (_isBusy) return;
    setState(() => _busyAction = action);
    try {
      await task();
    } finally {
      if (mounted) setState(() => _busyAction = _BusyAction.none);
    }
  }

  void _clearSelectedLocation() {
    _reverseGeocodeDebounce?.cancel();
    _selectionVersion++;
    _cameraTarget = null;
    _selected = null;
    _pendingCameraTarget = null;
    _isDraggingPin = false;
    _isResolvingAddress = false;
    _lastReverseGeocodedTarget = null;
    _searchController.clear();
  }

  bool get _isBusy => _busyAction != _BusyAction.none;
  bool get _isSearching => _busyAction == _BusyAction.searching;

  Future<LatLng?> _runLocationRequest(
    Future<LatLng?> Function() task,
  ) {
    final inFlight = _activeLocationRequest;
    if (inFlight != null) {
      return inFlight;
    }

    if (mounted) {
      setState(() => _isLocating = true);
    } else {
      _isLocating = true;
    }

    late final Future<LatLng?> trackedRequest;
    trackedRequest = task().whenComplete(() {
      if (!identical(_activeLocationRequest, trackedRequest)) {
        return;
      }
      _activeLocationRequest = null;
      if (mounted) {
        setState(() => _isLocating = false);
      } else {
        _isLocating = false;
      }
    });

    _activeLocationRequest = trackedRequest;
    return trackedRequest;
  }

  void _markUserMapInteraction() {
    _mapInteractionVersion++;
  }

  bool _shouldRefreshAddressFor(LatLng target) {
    final lastTarget = _lastReverseGeocodedTarget;
    if (lastTarget == null) return true;
    if (_searchController.text.trim().isEmpty) return true;
    return _distanceBetween(lastTarget, target) >= _addressRefreshThresholdMeters;
  }

  double _distanceBetween(LatLng a, LatLng b) {
    return Geolocator.distanceBetween(
      a.latitude,
      a.longitude,
      b.latitude,
      b.longitude,
    );
  }

  void _finishAddressResolution(LatLng resolvedTarget) {
    _lastReverseGeocodedTarget = resolvedTarget;
    if (!mounted) return;
    setState(() => _isResolvingAddress = false);
  }

  Future<void> _handleLocationAction() async {
    final action = _locationAction;
    if (action == null) return;

    if (action == _LocationAction.openLocationSettings &&
        _canPromptAndroidLocationResolution()) {
      await _useCurrentLocation();
      return;
    }

    final opened = action == _LocationAction.openAppSettings
        ? await Geolocator.openAppSettings()
        : await Geolocator.openLocationSettings();
    if (!opened || !mounted) return;

    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    setState(() {
      _error = null;
      _locationAction = null;
    });
    await _bootstrapLocationState();
  }
}

class _WebMapsError extends StatelessWidget {
  const _WebMapsError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(20),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.map_outlined, size: 44, color: Colors.black54),
            const SizedBox(height: 12),
            const Text(
              'Map is unavailable on web',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(color: Colors.black54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _MapStatusPill extends StatelessWidget {
  const _MapStatusPill({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final showsSpinner = !message.startsWith('Release map');
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Container(
        key: ValueKey(message),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showsSpinner ? Icons.location_searching : Icons.pan_tool_alt_rounded,
              size: 16,
              color: const Color(0xFF1F2937),
            ),
            if (showsSpinner) ...[
              const SizedBox(width: 8),
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
            const SizedBox(width: 10),
            Text(
              message,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1F2937),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenterPinOverlay extends StatelessWidget {
  const _CenterPinOverlay({required this.isAdjusting});

  final bool isAdjusting;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Center(
        child: AnimatedSlide(
          duration: const Duration(milliseconds: 150),
          offset: isAdjusting ? const Offset(0, -0.08) : Offset.zero,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.location_on_rounded,
                size: 44,
                color: Color(0xFFE53935),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 14,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: const Text(
                  'Move map',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1F2937),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
