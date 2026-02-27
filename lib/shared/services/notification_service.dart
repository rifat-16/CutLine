import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cutline/shared/models/notification_payload.dart';
import 'package:cutline/shared/services/booking_reminder_service.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/features/auth/models/user_role.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Top-level background message handler
/// Must be a top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Ensure Firebase is initialized
  await Firebase.initializeApp();
  // Additional background processing can be added here
}

/// Service for handling FCM notifications
class NotificationService {
  NotificationService() {
    _initializeLocalNotifications();
  }

  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final BookingReminderService _reminderService = BookingReminderService();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  Function(NotificationPayload)? _onNotificationTapped;
  UserRole? _currentUserRole;

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTappedLocal,
    );

    // Create notification channel for Android
    const androidChannel = AndroidNotificationChannel(
      'cutline_notifications',
      'CutLine Notifications',
      description: 'Notifications for booking updates',
      importance: Importance.high,
      playSound: true,
    );

    await _localNotifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(androidChannel);
  }

  /// Handle local notification tap
  void _onNotificationTappedLocal(NotificationResponse response) {
    if (response.payload != null) {
      try {
        // Parse payload if it's JSON
        // For now, we'll handle navigation in the foreground handler
      } catch (e) {
      }
    }
  }

  /// Set current user role for filtering notifications
  void setUserRole(UserRole? role) {
    _currentUserRole = role;
  }

  /// Initialize FCM notification handling
  /// Call this in main.dart after Firebase initialization
  Future<void> initialize({
    BuildContext? context,
    Function(NotificationPayload)? onNotificationTapped,
    UserRole? userRole,
  }) async {
    _currentUserRole = userRole;
    _onNotificationTapped = onNotificationTapped;

    // Set up background message handler
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    // Request permission
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      return;
    }

    // Handle foreground messages
    _foregroundSubscription =
        FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification tap when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification tap when app is terminated
    final initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }
  }

  /// Handle foreground messages (app is open)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {

    final notification = message.notification;
    final data = message.data;

    if (data.isNotEmpty) {
      final payload = NotificationPayload.fromMap(data);
      
      // Filter notifications based on user role
      if (!_shouldShowNotification(payload)) {
        return;
      }

      if (notification != null) {
        // Show local notification only if it's relevant to current user
        await _showLocalNotification(
          title: notification.title ?? 'CutLine',
          body: notification.body ?? '',
          data: data,
        );
      }

      // You can trigger UI updates here if needed
      
      // Schedule reminder for booking_accepted notifications
      final type = NotificationTypeExtension.fromString(payload.type);
      if (type == NotificationType.bookingAccepted && 
          payload.bookingId.isNotEmpty && 
          payload.salonId != null) {
        _scheduleBookingReminder(payload.salonId!, payload.bookingId);
      }
    }
  }
  
  /// Schedule a reminder notification 30 minutes before booking time
  Future<void> _scheduleBookingReminder(String salonId, String bookingId) async {
    try {
      // Fetch booking details from Firestore
      final bookingDoc = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .doc(bookingId)
          .get();
      
      if (!bookingDoc.exists) {
        return;
      }
      
      final bookingData = bookingDoc.data();
      if (bookingData == null) {
        return;
      }
      
      final date = (bookingData['date'] as String?)?.trim() ?? '';
      final time = (bookingData['time'] as String?)?.trim() ?? '';
      final salonName = (bookingData['salonName'] as String?)?.trim() ?? 'Salon';
      
      if (date.isEmpty || time.isEmpty) {
        return;
      }
      
      // Schedule the reminder
      final scheduled = await _reminderService.scheduleReminder(
        bookingId: bookingId,
        salonName: salonName,
        date: date,
        time: time,
        salonId: salonId,
      );
      
      if (scheduled) {
      } else {
      }
    } catch (e) {
    }
  }

  /// Handle notification tap (background or terminated)
  void _handleNotificationTap(RemoteMessage message) {

    final data = message.data;
    if (data.isNotEmpty) {
      final payload = NotificationPayload.fromMap(data);
      
      // Filter notifications based on user role
      if (!_shouldShowNotification(payload)) {
        return;
      }
      
      // Schedule reminder for booking_accepted notifications
      final type = NotificationTypeExtension.fromString(payload.type);
      if (type == NotificationType.bookingAccepted && 
          payload.bookingId.isNotEmpty && 
          payload.salonId != null) {
        _scheduleBookingReminder(payload.salonId!, payload.bookingId);
      }
      
      _navigateToScreen(payload);
    }
  }

  /// Check if notification should be shown based on user role
  bool _shouldShowNotification(NotificationPayload payload) {
    final type = NotificationTypeExtension.fromString(payload.type);
    
    // If no user role is set, show all notifications (fallback)
    if (_currentUserRole == null) {
      return true;
    }

    switch (type) {
      case NotificationType.bookingRequest:
        // Only show to owners
        return _currentUserRole == UserRole.owner;
      
      case NotificationType.bookingAccepted:
        // Only show to customers/users
        return _currentUserRole == UserRole.customer;
      
      case NotificationType.barberWaiting:
        // Only show to barbers
        return _currentUserRole == UserRole.barber;
      
      case NotificationType.unknown:
        // Show unknown notifications to all
        return true;
    }
  }

  /// Show local notification for foreground messages
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    required Map<String, dynamic> data,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'cutline_notifications',
      'CutLine Notifications',
      channelDescription: 'Notifications for booking updates',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      notificationDetails,
      payload: data.toString(), // Can be used for navigation
    );
  }

  /// Navigate to appropriate screen based on notification type
  void _navigateToScreen(NotificationPayload payload) {
    // Use callback if provided
    if (_onNotificationTapped != null) {
      _onNotificationTapped!(payload);
      return;
    }

    // Default navigation logic using navigator key
    final navigatorKey = AppRouter.navigatorKey;
    if (navigatorKey.currentContext == null) {
      return;
    }

    final context = navigatorKey.currentContext!;
    final type = NotificationTypeExtension.fromString(payload.type);

    switch (type) {
      case NotificationType.bookingRequest:
        // Navigate to booking requests screen for owner
        Navigator.of(context).pushNamed(AppRoutes.ownerBookingRequests);
        break;

      case NotificationType.bookingAccepted:
        // Navigate to booking details for user
        if (payload.salonId != null && payload.bookingId.isNotEmpty) {
          Navigator.of(context).pushNamed(
            AppRoutes.bookingReceipt,
            arguments: BookingReceiptArgs(
              salonId: payload.salonId!,
              bookingId: payload.bookingId,
            ),
          );
        } else {
          Navigator.of(context).pushNamed(AppRoutes.myBookings);
        }
        break;

      case NotificationType.barberWaiting:
        // Navigate to barber home (queue screen)
        Navigator.of(context).pushNamed(AppRoutes.barberHome);
        break;

      case NotificationType.unknown:
        // Navigate to notifications screen
        Navigator.of(context).pushNamed(AppRoutes.userNotifications);
        break;
    }
  }

  /// Dispose resources
  void dispose() {
    _foregroundSubscription?.cancel();
    _onNotificationTapped = null;
  }
}

/// Global notification service instance
final notificationService = NotificationService();
