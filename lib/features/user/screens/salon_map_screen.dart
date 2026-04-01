import 'dart:convert';
import 'dart:ui' as ui;

import 'package:cutline/features/user/providers/user_location_provider.dart';
import 'package:cutline/shared/services/google_maps_js_loader.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
  late final Future<void> _mapsReadyFuture;
  GoogleMapController? _controller;
  BitmapDescriptor? _salonMarkerIcon;
  BitmapDescriptor? _userMarkerIcon;
  bool _isLoadingMarkerIcons = false;
  bool _isFetchingRoute = false;
  Set<Polyline> _routePolylines = {};
  LatLng? _lastRouteOrigin;
  String? _routeDistanceLabel;
  String? _routeDurationLabel;

  LatLng get _salonLatLng => LatLng(widget.salonLat, widget.salonLng);

  @override
  void initState() {
    super.initState();
    _mapsReadyFuture = GoogleMapsJsLoader.ensureLoaded();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureMarkerIcons();
  }

  @override
  void dispose() {
    if (!kIsWeb) _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensureMarkerIcons() async {
    if ((_salonMarkerIcon != null && _userMarkerIcon != null) ||
        _isLoadingMarkerIcons) {
      return;
    }

    _isLoadingMarkerIcons = true;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    try {
      final salonIcon = await _buildLabeledPinMarker(
        label: widget.salonName,
        pinColor: const Color(0xFFE11D48),
        labelBorderColor: const Color(0xFFFBCFE8),
        devicePixelRatio: devicePixelRatio,
      );
      final userIcon = await _buildLabeledPinMarker(
        label: 'You',
        pinColor: Colors.blueAccent,
        labelBorderColor: const Color(0xFFBFDBFE),
        devicePixelRatio: devicePixelRatio,
      );
      if (!mounted) return;
      setState(() {
        _salonMarkerIcon = salonIcon;
        _userMarkerIcon = userIcon;
      });
    } finally {
      _isLoadingMarkerIcons = false;
    }
  }

  Future<BitmapDescriptor> _buildLabeledPinMarker({
    required String label,
    required Color pinColor,
    required Color labelBorderColor,
    required double devicePixelRatio,
  }) async {
    final scale = devicePixelRatio.clamp(1.0, 3.0);
    final maxTextWidth = 74.0 * scale;
    final horizontalPadding = 6.0 * scale;
    final labelHeight = 18.0 * scale;
    final pinSize = 18.0 * scale;
    final gap = 2.0 * scale;
    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: const Color(0xFF111827),
          fontSize: 8.6 * scale,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: maxTextWidth);
    final labelWidth = textPainter.width + horizontalPadding * 2;
    final width = labelWidth > pinSize ? labelWidth : pinSize;
    final height = labelHeight + gap + pinSize;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH((width - labelWidth) / 2, 0, labelWidth, labelHeight),
      Radius.circular(999 * scale),
    );

    canvas.drawRRect(
      labelRect.shift(Offset(0, 2.0 * scale)),
      Paint()..color = Colors.black.withValues(alpha: 0.10),
    );
    canvas.drawRRect(labelRect, Paint()..color = Colors.white);
    canvas.drawRRect(
      labelRect,
      Paint()
        ..color = labelBorderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9 * scale,
    );

    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        (labelHeight - textPainter.height) / 2,
      ),
    );

    final pinPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(Icons.location_on_rounded.codePoint),
        style: TextStyle(
          fontSize: pinSize,
          fontFamily: Icons.location_on_rounded.fontFamily,
          package: Icons.location_on_rounded.fontPackage,
          color: pinColor,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    pinPainter.paint(
      canvas,
      Offset(
        (width - pinPainter.width) / 2,
        labelHeight + gap,
      ),
    );

    canvas.drawCircle(
      Offset(width / 2, labelHeight + gap + pinSize * 0.34),
      pinSize * 0.13,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.18)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.6 * scale,
    );

    final image = await recorder
        .endRecording()
        .toImage(width.ceil(), height.ceil());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final data = bytes?.buffer.asUint8List() ?? Uint8List(0);
    return BitmapDescriptor.bytes(data);
  }

  Future<void> _fitToMarkers(UserLocationProvider locationProvider) async {
    if (!mounted) return;
    final controller = _controller;
    if (controller == null) return;

    final user = locationProvider.location;
    if (user == null) {
      try {
        await controller.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(target: _salonLatLng, zoom: 16),
          ),
        );
      } catch (_) {
        // Ignore camera updates when the map widget gets disposed/recreated.
      }
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

    try {
      await controller.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(southwest: southWest, northeast: northEast),
          70,
        ),
      );
    } catch (_) {
      // Ignore camera updates when the map widget gets disposed/recreated.
    }
  }

  void _maybeUpdateRoute(UserLocationProvider locationProvider) {
    final user = locationProvider.location;
    if (user == null) {
      if (_routePolylines.isNotEmpty ||
          _routeDistanceLabel != null ||
          _routeDurationLabel != null ||
          _isFetchingRoute) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            _isFetchingRoute = false;
            _routePolylines = {};
            _routeDistanceLabel = null;
            _routeDurationLabel = null;
          });
        });
      }
      return;
    }

    final origin = LatLng(user.latitude, user.longitude);
    final last = _lastRouteOrigin;
    if (last != null &&
        (origin.latitude - last.latitude).abs() < 0.00001 &&
        (origin.longitude - last.longitude).abs() < 0.00001) {
      return;
    }

    _lastRouteOrigin = origin;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _fetchAndSetRoute(origin, _salonLatLng);
    });
  }

  Future<void> _fetchAndSetRoute(LatLng origin, LatLng destination) async {
    if (mounted && !_isFetchingRoute) {
      setState(() => _isFetchingRoute = true);
    }
    final route = await _fetchRoutePreview(origin, destination);
    if (!mounted) return;
    setState(() {
      _isFetchingRoute = false;
      _routeDistanceLabel = route.distanceLabel;
      _routeDurationLabel = route.durationLabel;
      _routePolylines = route.points.length < 2
          ? {}
          : {
              Polyline(
                polylineId: const PolylineId('route'),
                points: route.points,
                color: CutlineColors.primary.withValues(alpha: 0.72),
                width: 6,
                startCap: Cap.roundCap,
                endCap: Cap.roundCap,
                jointType: JointType.round,
              ),
            };
    });
  }

  Future<void> _openInGoogleMaps(UserLocationProvider locationProvider) async {
    final user = locationProvider.location;
    final origin = user != null
        ? '${user.latitude},${user.longitude}'
        : null;
    final destination = '${_salonLatLng.latitude},${_salonLatLng.longitude}';
    final fallbackUri = Uri.https(
      'www.google.com',
      '/maps/dir/',
      {
        'api': '1',
        if (origin != null) 'origin': origin,
        'destination': destination,
        'travelmode': 'driving',
      },
    );

    Uri? primaryUri;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      primaryUri = Uri.parse('google.navigation:q=$destination&mode=d');
    } else if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      primaryUri =
          Uri.parse('comgooglemaps://?daddr=$destination&directionsmode=driving');
    }

    var launched = false;
    if (primaryUri != null) {
      launched = await launchUrl(primaryUri, mode: LaunchMode.externalApplication);
    }
    if (!launched) {
      launched = await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
    if (!launched) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  Future<_RoutePreview> _fetchRoutePreview(
    LatLng origin,
    LatLng destination,
  ) async {
    final apiKey = const String.fromEnvironment('MAPS_API_KEY').trim();
    if (apiKey.isEmpty) {
      return const _RoutePreview.empty();
    }
    try {
      final uri = Uri.https(
        'maps.googleapis.com',
        '/maps/api/directions/json',
        {
          'origin': '${origin.latitude},${origin.longitude}',
          'destination': '${destination.latitude},${destination.longitude}',
          'mode': 'driving',
          'key': apiKey,
        },
      );
      final response = await http
          .get(uri)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) {
        return const _RoutePreview.empty();
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return const _RoutePreview.empty();
      }
      final firstRoute = routes.first as Map<String, dynamic>;
      final legs = firstRoute['legs'] as List<dynamic>?;
      final firstLeg = legs != null && legs.isNotEmpty
          ? legs.first as Map<String, dynamic>
          : null;
      final distance = (firstLeg?['distance'] as Map<String, dynamic>?)?['text']
          as String?;
      final duration = (firstLeg?['duration'] as Map<String, dynamic>?)?['text']
          as String?;
      final overview = firstRoute['overview_polyline'] as Map<String, dynamic>?;
      final encoded = overview?['points'] as String?;
      if (encoded == null || encoded.isEmpty) {
        return _RoutePreview(
          points: const <LatLng>[],
          distanceLabel: distance,
          durationLabel: duration,
        );
      }
      final decoded = _decodePolyline(encoded);
      return _RoutePreview(
        points: decoded,
        distanceLabel: distance,
        durationLabel: duration,
      );
    } catch (_) {
      return const _RoutePreview.empty();
    }
  }

  List<LatLng> _decodePolyline(String encoded) {
    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int b;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final deltaLat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lat += deltaLat;

      result = 0;
      shift = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      final deltaLng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
      lng += deltaLng;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return points;
  }

  String? _distanceLabel(UserLocationProvider locationProvider) {
    if (_routeDistanceLabel != null && _routeDistanceLabel!.trim().isNotEmpty) {
      return _routeDistanceLabel;
    }
    final user = locationProvider.location;
    if (user == null) return null;
    final meters = Geolocator.distanceBetween(
      user.latitude,
      user.longitude,
      widget.salonLat,
      widget.salonLng,
    );
    return 'Approx. ${_formatDistance(meters)}';
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} m';
    }
    final km = meters / 1000.0;
    if (km < 10) {
      return '${km.toStringAsFixed(1)} km';
    }
    return '${km.toStringAsFixed(0)} km';
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<UserLocationProvider>();
    _maybeUpdateRoute(locationProvider);
    final user = locationProvider.location;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('salon'),
        position: _salonLatLng,
        infoWindow: InfoWindow(
          title: widget.salonName,
          snippet: 'Salon location',
        ),
        icon: _salonMarkerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 1.0),
      ),
      if (user != null)
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(user.latitude, user.longitude),
          infoWindow: const InfoWindow(
            title: 'Your location',
            snippet: 'Current position',
          ),
          icon: _userMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
          anchor: const Offset(0.5, 1.0),
        ),
    };

    final distanceLabel = _distanceLabel(locationProvider);

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
                initialCameraPosition:
                    CameraPosition(target: _salonLatLng, zoom: 16),
                onMapCreated: (controller) {
                  _controller = controller;
                  _fitToMarkers(locationProvider);
                },
                markers: markers,
                polylines: _routePolylines,
                padding: const EdgeInsets.fromLTRB(16, 96, 16, 220),
                myLocationEnabled: false,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
              );
            },
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.96),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 24,
                      offset: const Offset(0, 12),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: CutlineColors.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.storefront_rounded,
                            color: CutlineColors.primary,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.salonName, style: CutlineTextStyles.title),
                              const SizedBox(height: 2),
                              Text(
                                'Salon location',
                                style: CutlineTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Fit to markers',
                          onPressed: () => _fitToMarkers(locationProvider),
                          icon: const Icon(
                            Icons.center_focus_strong,
                            color: CutlineColors.primary,
                          ),
                        ),
                      ],
                    ),
                    if (distanceLabel != null ||
                        _routeDurationLabel != null ||
                        _isFetchingRoute) ...[
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          if (distanceLabel != null)
                            _MapInfoPill(
                              icon: Icons.near_me_rounded,
                              label: distanceLabel,
                            ),
                          if (_routeDurationLabel != null &&
                              _routeDurationLabel!.trim().isNotEmpty)
                            _MapInfoPill(
                              icon: Icons.schedule_rounded,
                              label: _routeDurationLabel!,
                            ),
                          if (_isFetchingRoute)
                            const _MapInfoPill(
                              icon: Icons.route_rounded,
                              label: 'Loading route...',
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text(
                      widget.address,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: CutlineTextStyles.subtitle,
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: () => _openInGoogleMaps(locationProvider),
                            icon: const Icon(Icons.navigation_rounded),
                            label: const Text('Open in Google Maps'),
                            style: FilledButton.styleFrom(
                              backgroundColor: CutlineColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        OutlinedButton.icon(
                          onPressed: () => _fitToMarkers(locationProvider),
                          icon: const Icon(Icons.my_location_rounded),
                          label: const Text('Center'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: CutlineColors.primary,
                            side: BorderSide(
                              color: CutlineColors.primary.withValues(alpha: 0.25),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (_routePolylines.isEmpty && !_isFetchingRoute) ...[
                      const SizedBox(height: 10),
                      Text(
                        'If live route is unavailable, Google Maps will open full directions.',
                        style: CutlineTextStyles.caption,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RoutePreview {
  const _RoutePreview({
    required this.points,
    this.distanceLabel,
    this.durationLabel,
  });

  const _RoutePreview.empty() : this(points: const <LatLng>[]);

  final List<LatLng> points;
  final String? distanceLabel;
  final String? durationLabel;
}

class _MapInfoPill extends StatelessWidget {
  const _MapInfoPill({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: CutlineColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: CutlineColors.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: CutlineTextStyles.caption.copyWith(
              color: CutlineColors.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _WebMapsError extends StatelessWidget {
  const _WebMapsError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: CutlineColors.background,
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
