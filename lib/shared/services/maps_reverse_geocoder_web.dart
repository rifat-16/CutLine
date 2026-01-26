// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'dart:js_util' as js_util;

import 'google_maps_js_loader.dart';

class MapsReverseGeocoder {
  static String? _lastError;

  static String? get lastError => _lastError;

  static Future<String> reverseGeocode({
    required double latitude,
    required double longitude,
  }) async {
    try {
      await GoogleMapsJsLoader.ensureLoaded();
      if (!_hasGeocoder()) return '';

      final completer = Completer<String>();

      final google = js_util.getProperty(html.window, 'google');
      final maps = js_util.getProperty(google, 'maps');
      final geocoderCtor = js_util.getProperty(maps, 'Geocoder');
      final geocoder = js_util.callConstructor(geocoderCtor, const []);

      final location = js_util.newObject();
      js_util.setProperty(location, 'lat', latitude);
      js_util.setProperty(location, 'lng', longitude);

      final request = js_util.newObject();
      js_util.setProperty(request, 'location', location);

      void completeOnce(String value) {
        if (!completer.isCompleted) completer.complete(value);
      }

      final callback = js_util.allowInterop((dynamic results, dynamic status) {
        try {
          final statusStr = (status ?? '').toString();
          if (statusStr != 'OK') {
            _lastError = statusStr;
            completeOnce('');
            return;
          }
          _lastError = null;

          if (results == null) {
            completeOnce('');
            return;
          }

          final length = js_util.getProperty(results, 'length');
          if (length is! num || length <= 0) {
            completeOnce('');
            return;
          }

          final first = js_util.getProperty(results, '0');
          if (first == null) {
            completeOnce('');
            return;
          }

          final formatted = js_util.getProperty(first, 'formatted_address');
          completeOnce((formatted ?? '').toString());
        } catch (_) {
          completeOnce('');
        }
      });

      js_util.callMethod(geocoder, 'geocode', [request, callback]);
      return completer.future.timeout(const Duration(seconds: 3), onTimeout: () {
        _lastError ??= 'TIMEOUT';
        completeOnce('');
        return '';
      });
    } catch (_) {
      return '';
    }
  }

  static bool _hasGeocoder() {
    try {
      if (!js_util.hasProperty(html.window, 'google')) return false;
      final google = js_util.getProperty(html.window, 'google');
      if (google == null) return false;
      if (!js_util.hasProperty(google, 'maps')) return false;
      final maps = js_util.getProperty(google, 'maps');
      if (maps == null) return false;
      return js_util.hasProperty(maps, 'Geocoder');
    } catch (_) {
      return false;
    }
  }
}
