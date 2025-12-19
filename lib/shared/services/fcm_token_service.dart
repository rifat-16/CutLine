import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

/// Service for managing FCM tokens in Firestore
class FcmTokenService {
  FcmTokenService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  /// Save or update FCM token for a user
  /// Supports both single token (fcmToken) and array (fcmTokens)
  Future<void> saveToken(String userId, String token) async {
    if (userId.isEmpty || token.isEmpty) {
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final existingTokens = data['fcmTokens'] as List<dynamic>?;
        final singleToken = data['fcmToken'] as String?;

        List<String> tokens = [];
        if (existingTokens != null) {
          tokens = existingTokens
              .whereType<String>()
              .where((t) => t.isNotEmpty)
              .toList();
        } else if (singleToken != null && singleToken.isNotEmpty) {
          tokens = [singleToken];
        }

        // Add new token if not already present
        if (!tokens.contains(token)) {
          tokens.add(token);
        }

        // Update document with array of tokens
        await userRef.update({
          'fcmTokens': tokens,
          'fcmToken': token, // Keep single token for backward compatibility
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // Create document if it doesn't exist
        await userRef.set({
          'fcmTokens': [token],
          'fcmToken': token,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Remove a specific token (e.g., on logout)
  Future<void> removeToken(String userId, String token) async {
    if (userId.isEmpty || token.isEmpty) {
      return;
    }

    try {
      final userRef = _firestore.collection('users').doc(userId);
      final userDoc = await userRef.get();

      if (userDoc.exists) {
        final data = userDoc.data() ?? {};
        final existingTokens = data['fcmTokens'] as List<dynamic>?;

        if (existingTokens != null) {
          final tokens = existingTokens
              .whereType<String>()
              .where((t) => t.isNotEmpty && t != token)
              .toList();

          await userRef.update({
            'fcmTokens': tokens,
            if (tokens.isEmpty) 'fcmToken': FieldValue.delete(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      // Don't rethrow - token removal is best effort
    }
  }

  /// Initialize token and listen for refresh
  /// Returns the current token
  Future<String?> initializeToken() async {
    try {
      // Request permission (iOS)
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        // Get token
        final token = await FirebaseMessaging.instance.getToken();
        return token;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Listen for token refresh and save automatically
  void listenToTokenRefresh(String userId, Function(String) onTokenSaved) {
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await saveToken(userId, newToken);
        onTokenSaved(newToken);
      } catch (e) {
      }
    });
  }
}

