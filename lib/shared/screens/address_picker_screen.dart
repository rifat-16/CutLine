import 'dart:async';

import 'package:cutline/shared/models/picked_location.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class AddressPickerScreen extends StatefulWidget {
  const AddressPickerScreen({
    super.key,
    this.title,
    this.confirmLabel,
    this.initialAddress,
    this.initialLocation,
  });

  final String? title;
  final String? confirmLabel;
  final String? initialAddress;
  final LatLng? initialLocation;

  @override
  State<AddressPickerScreen> createState() => _AddressPickerScreenState();
}

class _AddressPickerScreenState extends State<AddressPickerScreen> {
  static const _defaultLocation = LatLng(23.8103, 90.4125); // Dhaka

  late final TextEditingController _searchController;
  GoogleMapController? _mapController;
  LatLng? _selected;
  bool _isBusy = false;
  String? _error;
  Timer? _reverseGeocodeDebounce;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialAddress);
    _selected = widget.initialLocation;
  }

  @override
  void dispose() {
    _reverseGeocodeDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
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
                ],
              ],
            ),
          ),
          Expanded(
            child: Stack(
              children: [
                GoogleMap(
                  initialCameraPosition: CameraPosition(
                    target: selected ?? _defaultLocation,
                    zoom: selected == null ? 12 : 16,
                  ),
                  onMapCreated: (controller) => _mapController = controller,
                  myLocationButtonEnabled: false,
                  myLocationEnabled: false,
                  zoomControlsEnabled: false,
                  markers: {
                    if (selected != null)
                      Marker(
                        markerId: const MarkerId('selected'),
                        position: selected,
                        draggable: true,
                        onDragEnd: (pos) => _setSelected(pos, reverseGeocode: true),
                      ),
                  },
                  onTap: (pos) => _setSelected(pos, reverseGeocode: true),
                ),
                if (_isBusy)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withValues(alpha: 0.05),
                      child: const Center(child: CircularProgressIndicator()),
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
                  onPressed: selected == null || _isBusy ? null : _confirm,
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
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _searchAddress(),
            decoration: InputDecoration(
              hintText: 'Search address or area',
              filled: true,
              fillColor: Colors.white,
              prefixIcon: const Icon(Icons.search),
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
        IconButton.filled(
          onPressed: _isBusy ? null : _useCurrentLocation,
          icon: const Icon(Icons.my_location),
          tooltip: 'Use current location',
        ),
      ],
    );
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() => _error = 'Enter an address to search.');
      return;
    }

    await _runBusy(() async {
      setState(() => _error = null);
      try {
        final results = await locationFromAddress(query);
        if (results.isEmpty) {
          setState(() => _error = 'No results found for that address.');
          return;
        }
        final first = results.first;
        final pos = LatLng(first.latitude, first.longitude);
        await _moveCamera(pos);
        _setSelected(pos, reverseGeocode: true);
      } on Exception {
        setState(() => _error = 'Could not search that address. Try another.');
      }
    });
  }

  Future<void> _useCurrentLocation() async {
    await _runBusy(() async {
      setState(() => _error = null);
      try {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          permission = await Geolocator.requestPermission();
        }
        if (permission == LocationPermission.denied ||
            permission == LocationPermission.deniedForever) {
          setState(() => _error = 'Location permission is required.');
          return;
        }

        final pos = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );
        final latLng = LatLng(pos.latitude, pos.longitude);
        await _moveCamera(latLng);
        _setSelected(latLng, reverseGeocode: true);
      } on Exception {
        setState(() => _error = 'Could not get your current location.');
      }
    });
  }

  Future<void> _moveCamera(LatLng target) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: target, zoom: 16),
      ),
    );
  }

  void _setSelected(LatLng pos, {required bool reverseGeocode}) {
    setState(() {
      _selected = pos;
      _error = null;
    });
    if (!reverseGeocode) return;

    _reverseGeocodeDebounce?.cancel();
    _reverseGeocodeDebounce = Timer(const Duration(milliseconds: 350), () async {
      final current = _selected;
      if (current == null) return;
      try {
        final placemarks = await placemarkFromCoordinates(
          current.latitude,
          current.longitude,
        );
        final address = _formatPlacemark(placemarks);
        if (!mounted) return;
        if (address.isNotEmpty) {
          _searchController.text = address;
        }
      } on Exception {
        // Ignore reverse geocode failures; user can still confirm.
      }
    });
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

  Future<void> _confirm() async {
    final selected = _selected;
    if (selected == null) return;

    final address = _searchController.text.trim();
    if (address.isEmpty) {
      setState(() => _error = 'Please enter or confirm the address.');
      return;
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

  Future<void> _runBusy(Future<void> Function() task) async {
    if (_isBusy) return;
    setState(() => _isBusy = true);
    try {
      await task();
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }
}
