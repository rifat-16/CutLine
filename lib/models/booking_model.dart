import 'package:uuid/uuid.dart';

enum BookingStatus {
  waiting,
  inProgress,
  served,
  skipped,
  cancelled;

  String toString() {
    switch (this) {
      case BookingStatus.waiting:
        return 'waiting';
      case BookingStatus.inProgress:
        return 'inProgress';
      case BookingStatus.served:
        return 'served';
      case BookingStatus.skipped:
        return 'skipped';
      case BookingStatus.cancelled:
        return 'cancelled';
    }
  }

  static BookingStatus fromString(String status) {
    switch (status) {
      case 'inProgress':
        return BookingStatus.inProgress;
      case 'served':
        return BookingStatus.served;
      case 'skipped':
        return BookingStatus.skipped;
      case 'cancelled':
        return BookingStatus.cancelled;
      default:
        return BookingStatus.waiting;
    }
  }
}

class BookingModel {
  final String id;
  final String userId;
  final String userName;
  final String salonId;
  final String salonName;
  final String barberId;
  final String barberName;
  final String serviceId;
  final String serviceName;
  final double servicePrice;
  final BookingStatus status;
  final DateTime timestamp;
  final int queuePosition;

  BookingModel({
    String? id,
    required this.userId,
    required this.userName,
    required this.salonId,
    required this.salonName,
    required this.barberId,
    required this.barberName,
    required this.serviceId,
    required this.serviceName,
    required this.servicePrice,
    this.status = BookingStatus.waiting,
    required this.timestamp,
    this.queuePosition = 0,
  }) : id = id ?? const Uuid().v4();

  factory BookingModel.fromMap(Map<String, dynamic> map, [String? id]) {
    return BookingModel(
      id: id ?? map['id'],
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      salonId: map['salonId'] ?? '',
      salonName: map['salonName'] ?? '',
      barberId: map['barberId'] ?? '',
      barberName: map['barberName'] ?? '',
      serviceId: map['serviceId'] ?? '',
      serviceName: map['serviceName'] ?? '',
      servicePrice: (map['servicePrice'] ?? 0.0).toDouble(),
      status: BookingStatus.fromString(map['status'] ?? 'waiting'),
      timestamp: map['timestamp']?.toDate() ?? DateTime.now(),
      queuePosition: map['queuePosition'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'userName': userName,
      'salonId': salonId,
      'salonName': salonName,
      'barberId': barberId,
      'barberName': barberName,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'servicePrice': servicePrice,
      'status': status.toString(),
      'timestamp': timestamp,
      'queuePosition': queuePosition,
    };
  }

  BookingModel copyWith({
    String? id,
    String? userId,
    String? userName,
    String? salonId,
    String? salonName,
    String? barberId,
    String? barberName,
    String? serviceId,
    String? serviceName,
    double? servicePrice,
    BookingStatus? status,
    DateTime? timestamp,
    int? queuePosition,
  }) {
    return BookingModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      userName: userName ?? this.userName,
      salonId: salonId ?? this.salonId,
      salonName: salonName ?? this.salonName,
      barberId: barberId ?? this.barberId,
      barberName: barberName ?? this.barberName,
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      servicePrice: servicePrice ?? this.servicePrice,
      status: status ?? this.status,
      timestamp: timestamp ?? this.timestamp,
      queuePosition: queuePosition ?? this.queuePosition,
    );
  }
}
