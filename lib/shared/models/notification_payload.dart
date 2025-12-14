/// Notification payload models for FCM messages
class NotificationPayload {
  final String type;
  final String bookingId;
  final String? salonId;
  final String? customerName;
  final String? salonName;

  const NotificationPayload({
    required this.type,
    required this.bookingId,
    this.salonId,
    this.customerName,
    this.salonName,
  });

  factory NotificationPayload.fromMap(Map<String, dynamic> data) {
    return NotificationPayload(
      type: data['type'] as String? ?? '',
      bookingId: data['bookingId'] as String? ?? '',
      salonId: data['salonId'] as String?,
      customerName: data['customerName'] as String?,
      salonName: data['salonName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'bookingId': bookingId,
      if (salonId != null) 'salonId': salonId,
      if (customerName != null) 'customerName': customerName,
      if (salonName != null) 'salonName': salonName,
    };
  }
}

/// Notification types
enum NotificationType {
  bookingRequest,
  bookingAccepted,
  barberWaiting,
  turnReady,
  unknown,
}

extension NotificationTypeExtension on NotificationType {
  String get value {
    switch (this) {
      case NotificationType.bookingRequest:
        return 'booking_request';
      case NotificationType.bookingAccepted:
        return 'booking_accepted';
      case NotificationType.barberWaiting:
        return 'barber_waiting';
      case NotificationType.turnReady:
        return 'turn_ready';
      case NotificationType.unknown:
        return 'unknown';
    }
  }

  static NotificationType fromString(String value) {
    switch (value) {
      case 'booking_request':
        return NotificationType.bookingRequest;
      case 'booking_accepted':
        return NotificationType.bookingAccepted;
      case 'barber_waiting':
        return NotificationType.barberWaiting;
      case 'turn_ready':
        return NotificationType.turnReady;
      default:
        return NotificationType.unknown;
    }
  }
}

