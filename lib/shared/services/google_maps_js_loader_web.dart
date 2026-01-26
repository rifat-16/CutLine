// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use

import 'dart:async';
import 'dart:html' as html;

import 'dart:js_util' as js_util;

class GoogleMapsJsLoader {
  static bool _loaded = false;
  static Object? _lastError;
  static Completer<void>? _loadCompleter;

  static bool get isLoaded => _loaded || _hasGoogleMaps();

  static Object? get lastError => _lastError;

  static Future<void> ensureLoaded() {
    if (isLoaded) {
      _loaded = true;
      return Future.value();
    }

    final existing = _loadCompleter;
    if (existing != null) return existing.future;

    final completer = Completer<void>();
    _loadCompleter = completer;

    unawaited(_loadImpl(completer));
    return completer.future;
  }

  static Future<void> _loadImpl(Completer<void> completer) async {
    try {
      if (_hasGoogleMaps()) {
        _loaded = true;
        completer.complete();
        return;
      }

      final apiKey = _resolveApiKey();
      if (apiKey == null) {
        throw StateError(
          'Google Maps API key missing for web.\n'
          'Set it via `flutter run -d chrome --dart-define=MAPS_API_KEY=YOUR_KEY` '
          'or add `<meta name="google-maps-api-key" content="YOUR_KEY">` in `web/index.html`.',
        );
      }

      await _injectScript(apiKey).timeout(const Duration(seconds: 20));
      await _waitForGoogleMaps().timeout(const Duration(seconds: 10));

      _loaded = true;
      completer.complete();
    } catch (e, st) {
      _lastError = e;
      completer.completeError(e, st);
    }
  }

  static bool _hasGoogleMaps() {
    try {
      if (!js_util.hasProperty(html.window, 'google')) return false;
      final google = js_util.getProperty(html.window, 'google');
      if (google == null) return false;
      if (!js_util.hasProperty(google, 'maps')) return false;
      final maps = js_util.getProperty(google, 'maps');
      if (maps == null) return false;

      // google_maps_flutter_web expects these to exist.
      if (!js_util.hasProperty(maps, 'MapTypeId')) return false;
      final mapTypeId = js_util.getProperty(maps, 'MapTypeId');
      if (mapTypeId == null) return false;
      if (!js_util.hasProperty(mapTypeId, 'ROADMAP')) return false;

      return true;
    } catch (_) {
      return false;
    }
  }

  static String? _resolveApiKey() {
    final fromDefine = const String.fromEnvironment('MAPS_API_KEY').trim();
    if (fromDefine.isNotEmpty) return fromDefine;

    final meta = html.document.querySelector(
      'meta[name="google-maps-api-key"]',
    );
    final fromMeta = meta?.getAttribute('content')?.trim();
    if (fromMeta != null && fromMeta.isNotEmpty) return fromMeta;

    return null;
  }

  static Future<void> _injectScript(String apiKey) async {
    final existing = html.document.getElementById('google-maps-js');
    if (existing is html.ScriptElement) return;

    final completer = Completer<void>();
    final script = html.ScriptElement()
      ..id = 'google-maps-js'
      ..type = 'text/javascript'
      ..async = true
      ..defer = true
      ..src =
          'https://maps.googleapis.com/maps/api/js?key=$apiKey&v=weekly&loading=async';

    late final StreamSubscription<dynamic> loadSub;
    late final StreamSubscription<dynamic> errorSub;

    void cleanup() {
      loadSub.cancel();
      errorSub.cancel();
    }

    loadSub = script.onLoad.listen((_) {
      if (completer.isCompleted) return;
      cleanup();
      completer.complete();
    });
    errorSub = script.onError.listen((_) {
      if (completer.isCompleted) return;
      cleanup();
      completer.completeError(StateError('Failed to load Google Maps JS API.'));
    });

    html.document.head?.append(script);
    await completer.future;
  }

  static Future<void> _waitForGoogleMaps() async {
    if (_hasGoogleMaps()) return;

    final completer = Completer<void>();
    Timer? timer;
    timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_hasGoogleMaps()) {
        timer?.cancel();
        completer.complete();
      }
    });
    await completer.future;
  }
}
