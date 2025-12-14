import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

/// Service for scheduling booking reminder notifications
/// Sends notifications 30 minutes before booking time
class BookingReminderService {
  BookingReminderService({
    FlutterLocalNotificationsPlugin? localNotifications,
  }) : _localNotifications = localNotifications ?? FlutterLocalNotificationsPlugin() {
    _initializeTimezone();
  }

  final FlutterLocalNotificationsPlugin _localNotifications;
  bool _timezoneInitialized = false;

  /// Initialize timezone data
  Future<void> _initializeTimezone() async {
    if (!_timezoneInitialized) {
      tz.initializeTimeZones();
      _timezoneInitialized = true;
    }
  }

  /// Schedule a reminder notification 30 minutes before booking time
  /// 
  /// [bookingId] - Unique booking identifier
  /// [salonName] - Name of the salon
  /// [date] - Booking date in format 'yyyy-MM-dd'
  /// [time] - Booking time in format 'h:mm a' (e.g., '2:30 PM')
  /// [salonId] - Salon ID for navigation
  /// 
  /// Returns true if scheduled successfully, false otherwise
  Future<bool> scheduleReminder({
    required String bookingId,
    required String salonName,
    required String date,
    required String time,
    required String salonId,
  }) async {
    try {
      // Parse the booking date and time
      final bookingDateTime = _parseBookingDateTime(date, time);
      if (bookingDateTime == null) {
        debugPrint('BookingReminderService: Failed to parse booking date/time');
        return false;
      }

      // Calculate reminder time (30 minutes before booking)
      final reminderTime = bookingDateTime.subtract(const Duration(minutes: 30));

      // Check if reminder time is in the past
      if (reminderTime.isBefore(DateTime.now())) {
        debugPrint('BookingReminderService: Reminder time is in the past, skipping');
        return false;
      }

      // Ensure timezone is initialized
      await _initializeTimezone();

      // Convert to TZDateTime
      final tzReminderTime = tz.TZDateTime.from(reminderTime, tz.local);

      // Create notification channel for Android (if not exists)
      const androidChannel = AndroidNotificationChannel(
        'cutline_booking_reminders',
        'Booking Reminders',
        description: 'Reminders for upcoming bookings',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      // Schedule the notification
      await _localNotifications.zonedSchedule(
        _getNotificationId(bookingId),
        'আপনার টার্ন আসছে!',
        'আপনার $salonName এ বুকিং এর ৩০ মিনিট পরেই আপনার টার্ন। এখনই সেলুনে চলে যান।',
        tzReminderTime,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'cutline_booking_reminders',
            'Booking Reminders',
            channelDescription: 'Reminders for upcoming bookings',
            importance: Importance.high,
            priority: Priority.high,
            showWhen: true,
            playSound: true,
            enableVibration: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: 'booking_reminder|$salonId|$bookingId',
      );

      debugPrint(
        'BookingReminderService: Scheduled reminder for booking $bookingId at ${DateFormat('yyyy-MM-dd h:mm a').format(reminderTime)}',
      );
      return true;
    } catch (e) {
      debugPrint('BookingReminderService: Error scheduling reminder: $e');
      return false;
    }
  }

  /// Cancel a scheduled reminder for a booking
  Future<void> cancelReminder(String bookingId) async {
    try {
      await _localNotifications.cancel(_getNotificationId(bookingId));
      debugPrint('BookingReminderService: Cancelled reminder for booking $bookingId');
    } catch (e) {
      debugPrint('BookingReminderService: Error cancelling reminder: $e');
    }
  }

  /// Cancel all scheduled reminders
  Future<void> cancelAllReminders() async {
    try {
      await _localNotifications.cancelAll();
      debugPrint('BookingReminderService: Cancelled all reminders');
    } catch (e) {
      debugPrint('BookingReminderService: Error cancelling all reminders: $e');
    }
  }

  /// Parse booking date and time strings into DateTime
  DateTime? _parseBookingDateTime(String date, String time) {
    try {
      // Parse date (format: 'yyyy-MM-dd')
      final parsedDate = DateTime.parse(date);

      // Parse time (format: 'h:mm a' like '2:30 PM')
      final parsedTime = DateFormat('h:mm a').parse(time);

      // Combine date and time
      return DateTime(
        parsedDate.year,
        parsedDate.month,
        parsedDate.day,
        parsedTime.hour,
        parsedTime.minute,
      );
    } catch (e) {
      debugPrint('BookingReminderService: Error parsing date/time: $e');
      return null;
    }
  }

  /// Generate a unique notification ID from booking ID
  /// This ensures we can cancel/update specific reminders
  int _getNotificationId(String bookingId) {
    // Use a hash of the booking ID to generate a consistent integer ID
    // This ensures the same booking always gets the same notification ID
    return bookingId.hashCode.abs() % 2147483647; // Max int32 value
  }
}

