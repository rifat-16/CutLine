import 'dart:async';

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
        // Keep the token set tight to avoid stale tokens on shared devices
        // causing notifications to reach the wrong account.
        // If you need multi-device notifications per account, replace this with
        // a server-side token registry that enforces unique ownership.
        await userRef.update({
          'fcmTokens': [token],
          'fcmToken': token,
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
  StreamSubscription<String> listenToTokenRefresh(
    String userId,
    Function(String) onTokenSaved,
  ) {
    return FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await saveToken(userId, newToken);
        onTokenSaved(newToken);
      } catch (e) {
      }
    });
  }
}
