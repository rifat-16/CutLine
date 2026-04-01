import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class DeviceLocationException implements Exception {
  const DeviceLocationException({
    required this.code,
    required this.message,
  });

  final String code;
  final String message;
}

class DeviceLocationResult {
  const DeviceLocationResult({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.isMocked,
    required this.timestampMs,
    this.provider,
  });

  final double latitude;
  final double longitude;
  final double accuracy;
  final bool isMocked;
  final int timestampMs;
  final String? provider;

  static DeviceLocationResult? fromMap(Map<Object?, Object?>? raw) {
    if (raw == null) return null;
    final lat = raw['latitude'];
    final lng = raw['longitude'];
    final accuracy = raw['accuracy'];
    final timestampMs = raw['timestampMs'];
    if (lat is! num ||
        lng is! num ||
        accuracy is! num ||
        timestampMs is! num) {
      return null;
    }

    return DeviceLocationResult(
      latitude: lat.toDouble(),
      longitude: lng.toDouble(),
      accuracy: accuracy.toDouble(),
      isMocked: raw['isMocked'] == true,
      timestampMs: timestampMs.toInt(),
      provider: raw['provider']?.toString(),
    );
  }
}

class DeviceLocationService {
  static const MethodChannel _channel =
      MethodChannel('cutline/device_location');

  static bool get supportsNativePreciseLocation =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<DeviceLocationResult?> getPreciseCurrentLocation({
    required Duration timeout,
    required Duration maxAge,
    required double maxAccuracyMeters,
  }) async {
    if (!supportsNativePreciseLocation) return null;

    try {
      final raw = await _channel.invokeMapMethod<Object?, Object?>(
        'getPreciseCurrentLocation',
        {
          'timeoutMs': timeout.inMilliseconds,
          'maxAgeMs': maxAge.inMilliseconds,
          'maxAccuracyMeters': maxAccuracyMeters,
        },
      );
      return DeviceLocationResult.fromMap(raw);
    } on PlatformException catch (e) {
      throw DeviceLocationException(
        code: e.code,
        message: e.message ?? 'Could not get current location.',
      );
    }
  }
}
