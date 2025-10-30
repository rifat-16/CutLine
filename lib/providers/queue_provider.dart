import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../services/notification_service.dart';

class QueueProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final NotificationService _notificationService = NotificationService();

  List<BookingModel> _userBookings = [];
  BookingModel? _currentBooking;
  bool _isLoading = false;
  String? _error;

  List<BookingModel> get userBookings => _userBookings;
  BookingModel? get currentBooking => _currentBooking;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Stream of user bookings
  Stream<List<BookingModel>> getUserBookingsStream(String userId) {
    return _firestoreService.getUserBookingsStream(userId);
  }

  // Load user bookings
  Future<void> loadUserBookings(String userId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _userBookings = await _firestoreService.getUserBookingsStream(userId).first;
    } catch (e) {
      _error = e.toString();
      print('Error loading user bookings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Book a slot
  Future<bool> bookSlot({
    required UserModel user,
    required String salonId,
    required String salonName,
    required String barberId,
    required String barberName,
    required String serviceId,
    required String serviceName,
    required double servicePrice,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Get current queue length for position
      final queue = await _firestoreService.getBarberQueueStream(salonId, barberId).first;
      final activeQueue = queue.where((b) => 
        b.status == BookingStatus.waiting || b.status == BookingStatus.inProgress
      ).toList();
      final queuePosition = activeQueue.length + 1;

      final booking = BookingModel(
        userId: user.id,
        userName: user.name,
        salonId: salonId,
        salonName: salonName,
        barberId: barberId,
        barberName: barberName,
        serviceId: serviceId,
        serviceName: serviceName,
        servicePrice: servicePrice,
        status: BookingStatus.waiting,
        timestamp: DateTime.now(),
        queuePosition: queuePosition,
      );

      // Create booking in main collection
      await _firestoreService.createBooking(booking);

      // Add to barber's queue
      await _firestoreService.addToBarberQueue(salonId, barberId, booking);

      _currentBooking = booking;

      // Send notification (would typically be done from backend)
      await _notificationService.sendNotification(
        title: 'Booking Confirmed! 🎉',
        body: 'You are #$queuePosition in the queue for $barberName',
      );

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error booking slot: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Cancel booking
  Future<bool> cancelBooking(String bookingId) async {
    try {
      if (_currentBooking == null) return false;

      _isLoading = true;
      _error = null;
      notifyListeners();

      final booking = _currentBooking!;

      // Update main booking
      await _firestoreService.updateBooking(
        bookingId,
        {'status': BookingStatus.cancelled.toString()},
      );

      // Remove from barber's queue
      await _firestoreService.removeFromBarberQueue(
        booking.salonId,
        booking.barberId,
        bookingId,
      );

      _currentBooking = null;
      await loadUserBookings(booking.userId);

      return true;
    } catch (e) {
      _error = e.toString();
      print('Error cancelling booking: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Track queue position
  Future<int> getQueuePosition(String salonId, String barberId, String userId) async {
    try {
      final queue = await _firestoreService.getBarberQueueStream(salonId, barberId).first;
      final activeQueue = queue.where((b) => 
        b.status == BookingStatus.waiting || b.status == BookingStatus.inProgress
      ).toList();
      
      int position = 0;
      for (int i = 0; i < activeQueue.length; i++) {
        if (activeQueue[i].userId == userId) {
          position = i + 1;
          break;
        }
      }
      return position;
    } catch (e) {
      print('Error getting queue position: $e');
      return 0;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearCurrentBooking() {
    _currentBooking = null;
    notifyListeners();
  }
}
