import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class NotificationProvider with ChangeNotifier {
  final NotificationService _notificationService = NotificationService();

  bool _isInitialized = false;
  bool _hasPermission = false;
  String? _error;

  bool get isInitialized => _isInitialized;
  bool get hasPermission => _hasPermission;
  String? get error => _error;

  // Initialize notifications
  Future<void> initialize() async {
    try {
      await _notificationService.initialize();
      _isInitialized = true;
      _hasPermission = true;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error initializing notifications: $e');
      notifyListeners();
    }
  }

  // Get FCM token
  Future<String?> getFCMToken() async {
    try {
      return await _notificationService.getFCMToken();
    } catch (e) {
      _error = e.toString();
      return null;
    }
  }

  // Subscribe to topic
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _notificationService.subscribeToTopic(topic);
    } catch (e) {
      _error = e.toString();
      print('Error subscribing to topic: $e');
    }
  }

  // Unsubscribe from topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _notificationService.unsubscribeFromTopic(topic);
    } catch (e) {
      _error = e.toString();
      print('Error unsubscribing from topic: $e');
    }
  }

  // Send local notification
  Future<void> sendNotification({
    required String title,
    required String body,
    Map<String, dynamic>? data,
  }) async {
    try {
      await _notificationService.sendNotification(
        title: title,
        body: body,
        data: data,
      );
    } catch (e) {
      _error = e.toString();
      print('Error sending notification: $e');
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
