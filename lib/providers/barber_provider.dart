import 'package:flutter/material.dart';
import '../models/barber_model.dart';
import '../models/booking_model.dart';
import '../services/firestore_service.dart';

class BarberProvider with ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();

  BarberModel? _currentBarber;
  List<BookingModel> _queue = [];
  bool _isLoading = false;
  String? _error;

  BarberModel? get currentBarber => _currentBarber;
  List<BookingModel> get queue => _queue;
  bool get isLoading => _isLoading;
  String? get error => _error;

  // Load barber data
  Future<void> loadBarber(String salonId, String barberId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      _currentBarber = await _firestoreService.getBarber(salonId, barberId);
    } catch (e) {
      _error = e.toString();
      print('Error loading barber: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Stream of barber's queue
  Stream<List<BookingModel>> getQueueStream(String salonId, String barberId) {
    return _firestoreService.getBarberQueueStream(salonId, barberId);
  }

  // Load queue
  Future<void> loadQueue(String salonId, String barberId) async {
    try {
      _queue = await _firestoreService.getBarberQueueStream(salonId, barberId).first;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      print('Error loading queue: $e');
    }
  }

  // Toggle availability
  Future<bool> toggleAvailability(String salonId, String barberId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      if (_currentBarber == null) {
        await loadBarber(salonId, barberId);
      }

      final newAvailability = !_currentBarber!.available;
      await _firestoreService.updateBarber(
        salonId,
        barberId,
        {'available': newAvailability},
      );

      _currentBarber = _currentBarber!.copyWith(available: newAvailability);
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error toggling availability: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark as served
  Future<bool> markAsServed(String salonId, String barberId, String bookingId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestoreService.updateBarberQueueItem(
        salonId,
        barberId,
        bookingId,
        {'status': BookingStatus.served.toString()},
      );

      await loadQueue(salonId, barberId);
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error marking as served: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark as in progress
  Future<bool> markInProgress(String salonId, String barberId, String bookingId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestoreService.updateBarberQueueItem(
        salonId,
        barberId,
        bookingId,
        {'status': BookingStatus.inProgress.toString()},
      );

      await loadQueue(salonId, barberId);
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error marking in progress: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Skip customer
  Future<bool> skipCustomer(String salonId, String barberId, String bookingId) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      await _firestoreService.updateBarberQueueItem(
        salonId,
        barberId,
        bookingId,
        {'status': BookingStatus.skipped.toString()},
      );

      await loadQueue(salonId, barberId);
      return true;
    } catch (e) {
      _error = e.toString();
      print('Error skipping customer: $e');
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void clearBarber() {
    _currentBarber = null;
    _queue = [];
    notifyListeners();
  }
}
