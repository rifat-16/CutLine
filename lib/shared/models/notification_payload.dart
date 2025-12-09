/// Notification payload models for FCM messages
class NotificationPayload {
  final String type;
  final String bookingId;
  final String? salonId;
  final String? customerName;

  const NotificationPayload({
    required this.type,
    required this.bookingId,
    this.salonId,
    this.customerName,
  });

  factory NotificationPayload.fromMap(Map<String, dynamic> data) {
    return NotificationPayload(
      type: data['type'] as String? ?? '',
      bookingId: data['bookingId'] as String? ?? '',
      salonId: data['salonId'] as String?,
      customerName: data['customerName'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'bookingId': bookingId,
      if (salonId != null) 'salonId': salonId,
      if (customerName != null) 'customerName': customerName,
    };
  }
}

/// Notification types
enum NotificationType {
  bookingRequest,
  bookingAccepted,
  barberWaiting,
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
      default:
        return NotificationType.unknown;
    }
  }
}

