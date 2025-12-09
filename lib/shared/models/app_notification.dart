import 'package:cloud_firestore/cloud_firestore.dart';

/// App notification model for Firestore
class AppNotification {
  final String id;
  final String userId;
  final String type;
  final String title;
  final String body;
  final String? bookingId;
  final String? salonId;
  final String? customerName;
  final bool isRead;
  final DateTime createdAt;

  AppNotification({
    required this.id,
    required this.userId,
    required this.type,
    required this.title,
    required this.body,
    this.bookingId,
    this.salonId,
    this.customerName,
    this.isRead = false,
    required this.createdAt,
  });

  factory AppNotification.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return AppNotification(
      id: doc.id,
      userId: data['userId'] as String,
      type: data['type'] as String,
      title: data['title'] as String,
      body: data['body'] as String,
      bookingId: data['bookingId'] as String?,
      salonId: data['salonId'] as String?,
      customerName: data['customerName'] as String?,
      isRead: data['isRead'] as bool? ?? false,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'title': title,
      'body': body,
      if (bookingId != null) 'bookingId': bookingId,
      if (salonId != null) 'salonId': salonId,
      if (customerName != null) 'customerName': customerName,
      'isRead': isRead,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  AppNotification copyWith({
    String? id,
    String? userId,
    String? type,
    String? title,
    String? body,
    String? bookingId,
    String? salonId,
    String? customerName,
    bool? isRead,
    DateTime? createdAt,
  }) {
    return AppNotification(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      type: type ?? this.type,
      title: title ?? this.title,
      body: body ?? this.body,
      bookingId: bookingId ?? this.bookingId,
      salonId: salonId ?? this.salonId,
      customerName: customerName ?? this.customerName,
      isRead: isRead ?? this.isRead,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

