// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:js' as js;

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

      final google = js.context['google'];
      if (google is! js.JsObject) return '';
      final maps = google['maps'];
      if (maps is! js.JsObject) return '';
      final geocoderCtor = maps['Geocoder'];
      if (geocoderCtor is! js.JsFunction) return '';
      final geocoder = js.JsObject(geocoderCtor, const []);

      final request = js.JsObject.jsify({
        'location': {
          'lat': latitude,
          'lng': longitude,
        },
      });

      void completeOnce(String value) {
        if (!completer.isCompleted) completer.complete(value);
      }

      final callback = js.JsFunction.withThis((
        _,
        dynamic results,
        dynamic status,
      ) {
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

          if (results is! js.JsArray || results.isEmpty) {
            completeOnce('');
            return;
          }

          final first = results[0];
          if (first is! js.JsObject) {
            completeOnce('');
            return;
          }

          final formatted = first['formatted_address'];
          completeOnce((formatted ?? '').toString());
        } catch (_) {
          completeOnce('');
        }
      });

      geocoder.callMethod('geocode', [request, callback]);
      return completer.future.timeout(const Duration(seconds: 3),
          onTimeout: () {
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
      if (!js.context.hasProperty('google')) return false;
      final google = js.context['google'];
      if (google is! js.JsObject) return false;
      if (!google.hasProperty('maps')) return false;
      final maps = google['maps'];
      if (maps is! js.JsObject) return false;
      return maps.hasProperty('Geocoder');
    } catch (_) {
      return false;
    }
  }
}
