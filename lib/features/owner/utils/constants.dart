import 'package:flutter/material.dart';

enum OwnerQueueStatus { waiting, serving, done }

enum OwnerBookingStatus { upcoming, completed, cancelled }

enum OwnerBookingRequestStatus { pending, accepted, rejected }

enum OwnerNotificationType { bookingRequest, bookingCancelled }

enum OwnerBarberStatus { onFloor, onBreak, offDuty }

class OwnerQueueItem {
  final String id;
  final String customerName;
  final String service;
  final String barberName;
  final int price;
  final OwnerQueueStatus status;
  final int waitMinutes;
  final String slotLabel;
  final String customerPhone;
  final String? note;
  final String customerAvatar;
  final String customerUid;

  const OwnerQueueItem({
    required this.id,
    required this.customerName,
    required this.service,
    required this.barberName,
    required this.price,
    required this.status,
    required this.waitMinutes,
    required this.slotLabel,
    required this.customerPhone,
    this.note,
    this.customerAvatar = '',
    this.customerUid = '',
  });

  OwnerQueueItem copyWith({OwnerQueueStatus? status}) {
    return OwnerQueueItem(
      id: id,
      customerName: customerName,
      service: service,
      barberName: barberName,
      price: price,
      status: status ?? this.status,
      waitMinutes: waitMinutes,
      slotLabel: slotLabel,
      customerPhone: customerPhone,
      note: note,
      customerAvatar: customerAvatar,
      customerUid: customerUid,
    );
  }
}

class OwnerBooking {
  final String id;
  final String customerName;
  final String customerAvatar;
  final String customerUid;
  final String salonName;
  final String service;
  final int price;
  final DateTime dateTime;
  final OwnerBookingStatus status;
  final String paymentMethod;

  const OwnerBooking({
    required this.id,
    required this.customerName,
    required this.customerAvatar,
    required this.customerUid,
    required this.salonName,
    required this.service,
    required this.price,
    required this.dateTime,
    required this.status,
    required this.paymentMethod,
  });
}

class OwnerServiceInfo {
  final String name;
  final int price;
  final int durationMinutes;

  const OwnerServiceInfo({
    required this.name,
    required this.price,
    required this.durationMinutes,
  });

  OwnerServiceInfo copyWith({
    String? name,
    int? price,
    int? durationMinutes,
  }) {
    return OwnerServiceInfo(
      name: name ?? this.name,
      price: price ?? this.price,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}

class OwnerComboInfo {
  final String name;
  final String services;
  final String highlight;
  final int price;
  final String emoji;

  const OwnerComboInfo({
    required this.name,
    required this.services,
    required this.highlight,
    required this.price,
    required this.emoji,
  });

  OwnerComboInfo copyWith({
    String? name,
    String? services,
    String? highlight,
    int? price,
    String? emoji,
  }) {
    return OwnerComboInfo(
      name: name ?? this.name,
      services: services ?? this.services,
      highlight: highlight ?? this.highlight,
      price: price ?? this.price,
      emoji: emoji ?? this.emoji,
    );
  }
}

const String kOwnerSalonName = 'Edge & Fade Studio';
const String kOwnerName = 'Rifat Karim';
const String kOwnerSalonPhone = '+880 1788-112233';
const String kOwnerSalonEmail = 'hello@edgefade.com';
const String kOwnerSalonAddress = 'House 15, Road 17, Banani, Dhaka';
const String kOwnerSalonDescription =
    'Premium grooming studio specialising in detailed fades, hair spa, and modern styling for men & women.';

final Map<String, TimeOfDay> kOwnerWorkingHours = {
  'open': const TimeOfDay(hour: 9, minute: 0),
  'close': const TimeOfDay(hour: 21, minute: 0),
};

const List<OwnerServiceInfo> kOwnerDefaultServices = [
  OwnerServiceInfo(name: 'Classic Haircut', price: 350, durationMinutes: 25),
  OwnerServiceInfo(
      name: 'Signature Beard Trim', price: 250, durationMinutes: 20),
  OwnerServiceInfo(name: 'Premium Grooming', price: 600, durationMinutes: 45),
];

const List<OwnerComboInfo> kOwnerDefaultCombos = [
  OwnerComboInfo(
    name: 'Full Grooming Combo',
    services: 'Haircut + Beard + Facial',
    highlight: 'Save 20% today!',
    price: 850,
    emoji: '💎',
  ),
  OwnerComboInfo(
    name: 'Classic Style Combo',
    services: 'Haircut + Beard Trim',
    highlight: 'Save 15% on this combo!',
    price: 650,
    emoji: '🔥',
  ),
  OwnerComboInfo(
    name: 'Luxury Spa Combo',
    services: 'Facial + Head Massage + Steam',
    highlight: 'Save 25% today!',
    price: 1200,
    emoji: '✨',
  ),
];

final List<OwnerQueueItem> kOwnerQueueItems = [
  const OwnerQueueItem(
    id: 'Q1',
    customerName: 'Tahmid Hasan',
    service: 'Haircut & Beard',
    barberName: 'Alex',
    price: 480,
    status: OwnerQueueStatus.waiting,
    waitMinutes: 12,
    slotLabel: 'Token #12',
    customerPhone: '+880 1700-112255',
    note: 'Prefers skin fade',
  ),
  const OwnerQueueItem(
    id: 'Q2',
    customerName: 'Shila Akter',
    service: 'Hair Spa',
    barberName: 'Sara',
    price: 650,
    status: OwnerQueueStatus.waiting,
    waitMinutes: 25,
    slotLabel: 'Token #13',
    customerPhone: '+880 1844-559921',
    note: 'Color treated hair',
  ),
  const OwnerQueueItem(
    id: 'Q3',
    customerName: 'Rafiul Islam',
    service: 'Full Grooming',
    barberName: 'Kamal',
    price: 820,
    status: OwnerQueueStatus.serving,
    waitMinutes: 5,
    slotLabel: 'Token #14',
    customerPhone: '+880 1990-447755',
  ),
  const OwnerQueueItem(
    id: 'Q4',
    customerName: 'Sabbir Ahmed',
    service: 'Kids Cut',
    barberName: 'Nayeem',
    price: 300,
    status: OwnerQueueStatus.done,
    waitMinutes: 0,
    slotLabel: 'Completed',
    customerPhone: '+880 1670-998822',
  ),
];

final List<OwnerBooking> kOwnerBookings = [
  OwnerBooking(
    id: 'B1',
    customerName: 'Ridwan Karim',
    customerAvatar:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=60',
    customerUid: '',
    salonName: kOwnerSalonName,
    service: 'Premium Grooming',
    price: 720,
    dateTime: DateTime(2025, 1, 12, 14, 30),
    status: OwnerBookingStatus.upcoming,
    paymentMethod: 'Cash',
  ),
  OwnerBooking(
    id: 'B2',
    customerName: 'Siam Hossain',
    customerAvatar:
        'https://images.unsplash.com/photo-1542206395-9feb3edaa68e?auto=format&fit=crop&w=400&q=60',
    customerUid: '',
    salonName: kOwnerSalonName,
    service: 'Haircut & Beard',
    price: 480,
    dateTime: DateTime(2025, 1, 11, 16, 0),
    status: OwnerBookingStatus.completed,
    paymentMethod: 'Card',
  ),
  OwnerBooking(
    id: 'B3',
    customerName: 'Mim Rahman',
    customerAvatar:
        'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?auto=format&fit=crop&w=400&q=60',
    customerUid: '',
    salonName: kOwnerSalonName,
    service: 'Hair Treatment',
    price: 900,
    dateTime: DateTime(2025, 1, 10, 11, 0),
    status: OwnerBookingStatus.cancelled,
    paymentMethod: 'bKash',
  ),
];

class OwnerBookingRequest {
  final String id;
  final String customerName;
  final String customerPhone;
  final String customerAvatar;
  final String customerUid;
  final String barberName;
  final DateTime dateTime;
  final List<String> services;
  final int durationMinutes;
  final int totalPrice;
  final OwnerBookingRequestStatus status;

  const OwnerBookingRequest({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    required this.customerAvatar,
    required this.customerUid,
    required this.barberName,
    required this.dateTime,
    required this.services,
    required this.durationMinutes,
    required this.totalPrice,
    this.status = OwnerBookingRequestStatus.pending,
  });

  OwnerBookingRequest copyWith({
    OwnerBookingRequestStatus? status,
    String? customerAvatar,
  }) {
    return OwnerBookingRequest(
      id: id,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAvatar: customerAvatar ?? this.customerAvatar,
      customerUid: customerUid,
      barberName: barberName,
      dateTime: dateTime,
      services: services,
      durationMinutes: durationMinutes,
      totalPrice: totalPrice,
      status: status ?? this.status,
    );
  }
}

final List<OwnerBookingRequest> kOwnerBookingRequests = [
  OwnerBookingRequest(
    id: 'BR1',
    customerName: 'Rumi Ahsan',
    customerPhone: '+880 1700-223344',
    customerAvatar:
        'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?auto=format&fit=crop&w=400&q=60',
    customerUid: '',
    barberName: 'Sara Rahman',
    dateTime: DateTime(2025, 1, 13, 11, 30),
    services: ['Balayage Color', 'Hair Spa'],
    durationMinutes: 90,
    totalPrice: 1450,
  ),
  OwnerBookingRequest(
    id: 'BR2',
    customerName: 'Ahnaf Islam',
    customerPhone: '+880 1680-777666',
    customerAvatar:
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?auto=format&fit=crop&w=400&q=60',
    customerUid: '',
    barberName: 'Tanvir Hasan',
    dateTime: DateTime(2025, 1, 13, 15, 0),
    services: ['Classic Haircut'],
    durationMinutes: 30,
    totalPrice: 350,
  ),
  OwnerBookingRequest(
    id: 'BR3',
    customerName: 'Lubna Rahman',
    customerPhone: '+880 1715-991122',
    customerAvatar:
        'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&w=400&q=60',
    customerUid: '',
    barberName: 'Shaila Akter',
    dateTime: DateTime(2025, 1, 14, 10, 45),
    services: ['Premium Grooming', 'Nail Care'],
    durationMinutes: 75,
    totalPrice: 980,
  ),
  OwnerBookingRequest(
    id: 'BR4',
    customerName: 'Emon Chowdhury',
    customerPhone: '+880 1911-334455',
    customerAvatar:
        'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=crop&w=400&q=60',
    customerUid: '',
    barberName: 'Kamrul Huda',
    dateTime: DateTime(2025, 1, 14, 18, 15),
    services: ['Beard Trim', 'Facial'],
    durationMinutes: 50,
    totalPrice: 680,
  ),
];

class OwnerNotificationItem {
  final String id;
  final OwnerNotificationType type;
  final String customerName;
  final String serviceName;
  final String barberName;
  final DateTime bookingTime;
  final DateTime timestamp;

  const OwnerNotificationItem({
    required this.id,
    required this.type,
    required this.customerName,
    required this.serviceName,
    required this.barberName,
    required this.bookingTime,
    required this.timestamp,
  });
}

final List<OwnerNotificationItem> kOwnerNotifications = [
  OwnerNotificationItem(
    id: 'N1',
    type: OwnerNotificationType.bookingRequest,
    customerName: 'Rumi Ahsan',
    serviceName: 'Balayage + Hair Spa',
    barberName: 'Sara Rahman',
    bookingTime: DateTime(2025, 1, 13, 11, 30),
    timestamp: DateTime(2025, 1, 12, 9, 5),
  ),
  OwnerNotificationItem(
    id: 'N2',
    type: OwnerNotificationType.bookingRequest,
    customerName: 'Ahnaf Islam',
    serviceName: 'Classic Haircut',
    barberName: 'Alex Martin',
    bookingTime: DateTime(2025, 1, 13, 15, 0),
    timestamp: DateTime(2025, 1, 12, 9, 40),
  ),
  OwnerNotificationItem(
    id: 'N3',
    type: OwnerNotificationType.bookingCancelled,
    customerName: 'Lubna Rahman',
    serviceName: 'Premium Grooming',
    barberName: 'Kamal Uddin',
    bookingTime: DateTime(2025, 1, 12, 17, 0),
    timestamp: DateTime(2025, 1, 12, 10, 55),
  ),
  OwnerNotificationItem(
    id: 'N4',
    type: OwnerNotificationType.bookingCancelled,
    customerName: 'Ridwan Karim',
    serviceName: 'Beard Design',
    barberName: 'Nayeem Khan',
    bookingTime: DateTime(2025, 1, 12, 19, 30),
    timestamp: DateTime(2025, 1, 12, 11, 5),
  ),
];

class OwnerWorkingDay {
  final String day;
  final bool isOpen;
  final TimeOfDay openTime;
  final TimeOfDay closeTime;

  const OwnerWorkingDay({
    required this.day,
    required this.isOpen,
    required this.openTime,
    required this.closeTime,
  });

  OwnerWorkingDay copyWith({
    bool? isOpen,
    TimeOfDay? openTime,
    TimeOfDay? closeTime,
  }) {
    return OwnerWorkingDay(
      day: day,
      isOpen: isOpen ?? this.isOpen,
      openTime: openTime ?? this.openTime,
      closeTime: closeTime ?? this.closeTime,
    );
  }
}

const List<OwnerWorkingDay> kOwnerDefaultWorkingDays = [
  OwnerWorkingDay(
      day: 'Monday',
      isOpen: true,
      openTime: TimeOfDay(hour: 9, minute: 0),
      closeTime: TimeOfDay(hour: 21, minute: 0)),
  OwnerWorkingDay(
      day: 'Tuesday',
      isOpen: true,
      openTime: TimeOfDay(hour: 9, minute: 0),
      closeTime: TimeOfDay(hour: 21, minute: 0)),
  OwnerWorkingDay(
      day: 'Wednesday',
      isOpen: true,
      openTime: TimeOfDay(hour: 9, minute: 0),
      closeTime: TimeOfDay(hour: 21, minute: 0)),
  OwnerWorkingDay(
      day: 'Thursday',
      isOpen: true,
      openTime: TimeOfDay(hour: 9, minute: 0),
      closeTime: TimeOfDay(hour: 21, minute: 0)),
  OwnerWorkingDay(
      day: 'Friday',
      isOpen: true,
      openTime: TimeOfDay(hour: 9, minute: 0),
      closeTime: TimeOfDay(hour: 21, minute: 0)),
  OwnerWorkingDay(
      day: 'Saturday',
      isOpen: true,
      openTime: TimeOfDay(hour: 10, minute: 0),
      closeTime: TimeOfDay(hour: 22, minute: 0)),
  OwnerWorkingDay(
      day: 'Sunday',
      isOpen: false,
      openTime: TimeOfDay(hour: 10, minute: 0),
      closeTime: TimeOfDay(hour: 20, minute: 0)),
];

class OwnerBarber {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String password;
  final String specialization;
  final double rating;
  final int servedToday;
  final OwnerBarberStatus status;
  final String? nextClient;
  final String photoUrl;
  final String uid;
  final bool isAvailable;

  OwnerBarber({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.password,
    required this.specialization,
    required this.rating,
    required this.servedToday,
    required this.status,
    this.nextClient,
    this.photoUrl = '',
    this.uid = '',
    this.isAvailable = true,
  });
}

final List<OwnerBarber> kOwnerBarbers = [
  OwnerBarber(
    id: 'B1',
    name: 'Alex Rahman',
    email: 'alex@edgefade.com',
    phone: '+880 1788-220011',
    password: 'alex123',
    specialization: 'Fade & Beard',
    rating: 4.9,
    servedToday: 7,
    status: OwnerBarberStatus.onFloor,
    nextClient: 'Tahmid • Fade refresh',
  ),
  OwnerBarber(
    id: 'B2',
    name: 'Sara Noor',
    email: 'sara@edgefade.com',
    phone: '+880 1799-440022',
    password: 'sara123',
    specialization: 'Hair Spa & Color',
    rating: 4.8,
    servedToday: 5,
    status: OwnerBarberStatus.onFloor,
    nextClient: 'Shila • Hair spa',
  ),
  OwnerBarber(
    id: 'B3',
    name: 'Kamal Uddin',
    email: 'kamal@edgefade.com',
    phone: '+880 1888-557799',
    password: 'kamal123',
    specialization: 'Full Grooming',
    rating: 4.6,
    servedToday: 4,
    status: OwnerBarberStatus.onBreak,
    nextClient: 'Break until 3:10 PM',
  ),
  OwnerBarber(
    id: 'B4',
    name: 'Nayeem Khan',
    email: 'nayeem@edgefade.com',
    phone: '+880 1999-880022',
    password: 'nayeem123',
    specialization: 'Kids cut',
    rating: 4.7,
    servedToday: 2,
    status: OwnerBarberStatus.offDuty,
  ),
];
