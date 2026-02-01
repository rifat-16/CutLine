import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
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
  GoogleMapController? _controller;
  bool _myLocationEnabled = false;
  BitmapDescriptor? _salonMarkerIcon;
  BitmapDescriptor? _userMarkerIcon;
  Set<Polyline> _routePolylines = {};
  LatLng? _lastRouteOrigin;

  LatLng get _salonLatLng => LatLng(widget.salonLat, widget.salonLng);

  @override
  void initState() {
    super.initState();
    _initMyLocation();
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

  Future<void> _ensureMarkerIcons() async {
    if (_salonMarkerIcon != null && _userMarkerIcon != null) return;
    final devicePixelRatio = MediaQuery.of(context).devicePixelRatio;
    final salonIcon = await _buildLabeledMarker(
      label: widget.salonName,
      accentColor: Colors.redAccent,
      devicePixelRatio: devicePixelRatio,
    );
    final userIcon = await _buildLabeledMarker(
      label: 'You',
      accentColor: Colors.blueAccent,
      devicePixelRatio: devicePixelRatio,
    );
    if (!mounted) return;
    setState(() {
      _salonMarkerIcon = salonIcon;
      _userMarkerIcon = userIcon;
    });
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
      if (_routePolylines.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() => _routePolylines = {});
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
    final points = await _fetchRoutePoints(origin, destination);
    if (!mounted) return;
    setState(() {
      _routePolylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: points,
          color: CutlineColors.primary,
          width: 5,
          geodesic: points.length == 2,
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

  Future<List<LatLng>> _fetchRoutePoints(
    LatLng origin,
    LatLng destination,
  ) async {
    final apiKey = const String.fromEnvironment('MAPS_API_KEY').trim();
    if (apiKey.isEmpty) {
      return [origin, destination];
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
        return [origin, destination];
      }
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final routes = data['routes'] as List<dynamic>?;
      if (routes == null || routes.isEmpty) {
        return [origin, destination];
      }
      final overview = routes.first['overview_polyline'] as Map<String, dynamic>?;
      final encoded = overview?['points'] as String?;
      if (encoded == null || encoded.isEmpty) {
        return [origin, destination];
      }
      final decoded = _decodePolyline(encoded);
      return decoded.isNotEmpty ? decoded : [origin, destination];
    } catch (_) {
      return [origin, destination];
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

  Future<BitmapDescriptor> _buildLabeledMarker({
    required String label,
    required Color accentColor,
    required double devicePixelRatio,
  }) async {
    final scale = devicePixelRatio.clamp(1.0, 3.0);
    final paddingX = 10.0 * scale;
    final paddingY = 6.0 * scale;
    final fontSize = 13.0 * scale;
    final dotRadius = 6.0 * scale;
    final gap = 4.0 * scale;
    final borderRadius = 10.0 * scale;

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          color: Colors.black87,
          fontSize: fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: 200 * scale);

    final labelWidth = textPainter.width + paddingX * 2;
    final labelHeight = textPainter.height + paddingY * 2;
    final width = math.max(labelWidth, dotRadius * 2 + 4 * scale);
    final height = labelHeight + gap + dotRadius * 2;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final labelRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, width, labelHeight),
      Radius.circular(borderRadius),
    );
    final bgPaint = Paint()..color = Colors.white;
    final borderPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 * scale;

    canvas.drawRRect(labelRect, bgPaint);
    canvas.drawRRect(labelRect, borderPaint);

    textPainter.paint(
      canvas,
      Offset(
        (width - textPainter.width) / 2,
        (labelHeight - textPainter.height) / 2,
      ),
    );

    final dotCenter = Offset(width / 2, labelHeight + gap + dotRadius);
    final dotPaint = Paint()..color = accentColor;
    final dotBorder = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;
    canvas.drawCircle(dotCenter, dotRadius, dotPaint);
    canvas.drawCircle(dotCenter, dotRadius, dotBorder);

    final image = await recorder
        .endRecording()
        .toImage(width.toInt(), height.toInt());
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final data = bytes?.buffer.asUint8List() ?? Uint8List(0);
    return BitmapDescriptor.fromBytes(data);
  }

  @override
  Widget build(BuildContext context) {
    final locationProvider = context.watch<UserLocationProvider>();
    final user = locationProvider.location;
    _maybeUpdateRoute(locationProvider);
    final showUserMarker = user != null;

    final markers = <Marker>{
      Marker(
        markerId: const MarkerId('salon'),
        position: _salonLatLng,
        infoWindow: InfoWindow(title: widget.salonName),
        icon: _salonMarkerIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        anchor: const Offset(0.5, 1.0),
      ),
      if (user != null)
        Marker(
          markerId: const MarkerId('user'),
          position: LatLng(user.latitude, user.longitude),
          infoWindow: const InfoWindow(title: 'You'),
          icon: _userMarkerIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                BitmapDescriptor.hueAzure,
              ),
          anchor: const Offset(0.5, 1.0),
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
          FutureBuilder<void>(
            future: GoogleMapsJsLoader.ensureLoaded(),
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
                myLocationEnabled: _myLocationEnabled && !showUserMarker,
                myLocationButtonEnabled: _myLocationEnabled && !showUserMarker,
                zoomControlsEnabled: false,
              );
            },
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
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => _openInGoogleMaps(locationProvider),
                          icon: const Icon(Icons.directions, size: 18),
                          label: const Text('Open in Google Maps'),
                          style: TextButton.styleFrom(
                            foregroundColor: CutlineColors.primary,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                          ),
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
