import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LocalTtlCache {
  LocalTtlCache._();

  static const _prefix = 'cutline_cache:';

  static String _key(String key) => '$_prefix$key';

  static Future<T?> get<T>(String key) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key(key));
      if (raw == null || raw.isEmpty) return null;
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final expiresAt = decoded['expiresAt'];
      if (expiresAt is! int) return null;
      if (DateTime.now().millisecondsSinceEpoch >= expiresAt) {
        await prefs.remove(_key(key));
        return null;
      }
      return decoded['value'] as T?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> set(String key, dynamic value, Duration ttl) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final payload = {
        'expiresAt':
            DateTime.now().add(ttl).millisecondsSinceEpoch,
        'value': value,
      };
      await prefs.setString(_key(key), jsonEncode(payload));
    } catch (_) {
      // ignore cache failures
    }
  }
}
