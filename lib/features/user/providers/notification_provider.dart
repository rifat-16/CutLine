import 'dart:async';

import 'package:cutline/shared/models/app_notification.dart';
import 'package:cutline/shared/services/notification_storage_service.dart';
import 'package:flutter/material.dart';

class NotificationProvider extends ChangeNotifier {
  NotificationProvider({
    required String userId,
    NotificationStorageService? storageService,
  })  : _userId = userId,
        _storageService = storageService ?? NotificationStorageService() {
    _loadNotifications();
  }

  final String _userId;
  final NotificationStorageService _storageService;
  StreamSubscription<List<AppNotification>>? _subscription;

  List<AppNotification> _notifications = [];
  bool _isLoading = false;
  String? _error;
  int _unreadCount = 0;

  List<AppNotification> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get error => _error;
  int get unreadCount => _unreadCount;

  void _loadNotifications() {
    _subscription?.cancel();
    _subscription = _storageService.getNotifications(_userId).listen((notifications) {
      _notifications = notifications;
      _unreadCount = notifications.where((n) => !n.isRead).length;
      notifyListeners();
    }, onError: (error) {
      _error = 'Failed to load notifications';
      notifyListeners();
    });
  }

  Future<void> markAsRead(String notificationId) async {
    await _storageService.markAsRead(notificationId);
  }

  Future<void> markAllAsRead() async {
    await _storageService.markAllAsRead(_userId);
  }

  Future<void> deleteNotification(String notificationId) async {
    await _storageService.deleteNotification(notificationId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
