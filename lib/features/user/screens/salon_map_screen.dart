import 'package:cutline/features/user/providers/user_location_provider.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

class SalonMapScreen extends StatefulWidget {
  const SalonMapScreen({
    super.key,
    required this.salonName,
    required this.salonLat,
    required this.salonLng,
    required this.address,
  });

  final String salonName;
  final double salonLat;
  final double salonLng;
  final String address;

  @override
  State<SalonMapScreen> createState() => _SalonMapScreenState();
}

class _SalonMapScreenState extends State<SalonMapScreen> {
  GoogleMapController? _controller;
  bool _myLocationEnabled = false;

  LatLng get _salonLatLng => LatLng(widget.salonLat, widget.salonLng);

  @override
  void initState() {
    super.initState();
    _initMyLocation();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _initMyLocation() async {
    try {
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;
      final permission = await Geolocator.checkPermission();
      final allowed = permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
      if (!mounted) return;
      setState(() => _myLocationEnabled = allowed);
    } catch (_) {
      // Ignore, map still works without user location.
    }
  }

  Future<void> _fitToMarkers(UserLocationProvider locationProvider) async {
    final controller = _controller;
    if (controller == null) return;

    final user = locationProvider.location;
    if (user == null) {
      await controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _salonLatLng, zoom: 16),
        ),
      );
      return;
    }

    final points = [
      _salonLatLng,
      LatLng(user.latitude, user.longitude),
    ];

    final southWest = LatLng(
      points.map((p) => p.latitude).reduce((a, b) => a < b ? a : b),
      points.map((p) => p.longitude).reduce((a, b) => a < b ? a : b),
    );
    final northEast = LatLng(
      points.map((p) => p.latitude).reduce((a, b) => a > b ? a : b),
      points.map((p) => p.longitude).reduce((a, b) => a > b ? a : b),
    );

    await controller.animateCamera(
      CameraUpdate.newLatLngBounds(
        LatLngBounds(southwest: southWest, northeast: northEast),
        70,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<UserLocationProvider>();
    final user = locationProvider.location;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('salon'),
        position: _salonLatLng,
        infoWindow: InfoWindow(title: widget.salonName),
      ),
      if (user != null)
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(user.latitude, user.longitude),
          infoWindow: const InfoWindow(title: 'You'),
          icon: BitmapDescriptor.defaultMarkerWithHue(
            BitmapDescriptor.hueAzure,
          ),
        ),
    };

    return Scaffold(
      backgroundColor: CutlineColors.background,
      appBar: AppBar(
        title: Text(widget.salonName),
        backgroundColor: Colors.white,
        foregroundColor: CutlineColors.primary,
        elevation: 0,
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _salonLatLng, zoom: 16),
            onMapCreated: (controller) {
              _controller = controller;
              _fitToMarkers(locationProvider);
            },
            markers: markers,
            myLocationEnabled: _myLocationEnabled,
            myLocationButtonEnabled: _myLocationEnabled,
            zoomControlsEnabled: false,
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: CutlineDecorations.card(
                solidColor: Colors.white,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.place_outlined,
                      color: CutlineColors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.salonName,
                            style: CutlineTextStyles.title),
                        const SizedBox(height: 4),
                        Text(
                          widget.address,
                          style: CutlineTextStyles.subtitle,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Fit to markers',
                    onPressed: () => _fitToMarkers(locationProvider),
                    icon: const Icon(Icons.center_focus_strong,
                        color: CutlineColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

