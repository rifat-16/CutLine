import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../models/salon_model.dart';
import '../models/barber_model.dart';
import '../models/booking_model.dart';
import '../utils/constants.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Users
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(user.id)
          .set(user.toMap());
    } catch (e) {
      throw 'Error creating user: ${e.toString()}';
    }
  }

  Future<UserModel?> getUser(String userId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .get();
      
      if (doc.exists) {
        return UserModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw 'Error getting user: ${e.toString()}';
    }
  }

  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromMap(doc.data()!, doc.id) : null);
  }

  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.usersCollection)
          .doc(userId)
          .update(data);
    } catch (e) {
      throw 'Error updating user: ${e.toString()}';
    }
  }

  // Salons
  Future<String> createSalon(SalonModel salon) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.salonsCollection)
          .add(salon.toMap());
      return doc.id;
    } catch (e) {
      throw 'Error creating salon: ${e.toString()}';
    }
  }

  Future<SalonModel?> getSalon(String salonId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.salonsCollection)
          .doc(salonId)
          .get();
      
      if (doc.exists) {
        return SalonModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw 'Error getting salon: ${e.toString()}';
    }
  }

  Stream<List<SalonModel>> getSalonsStream() {
    return _firestore
        .collection(AppConstants.salonsCollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => SalonModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateSalon(String salonId, Map<String, dynamic> data) async {
    try {
      await _firestore
          .collection(AppConstants.salonsCollection)
          .doc(salonId)
          .update(data);
    } catch (e) {
      throw 'Error updating salon: ${e.toString()}';
    }
  }

  // Barbers
  Future<void> createBarber(BarberModel barber) async {
    try {
      await _firestore
          .collection(AppConstants.salonsCollection)
          .doc(barber.salonId)
          .collection(AppConstants.barbersSubcollection)
          .doc(barber.id)
          .set(barber.toMap());
    } catch (e) {
      throw 'Error creating barber: ${e.toString()}';
    }
  }

  Future<BarberModel?> getBarber(String salonId, String barberId) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.salonsCollection)
          .doc(salonId)
          .collection(AppConstants.barbersSubcollection)
          .doc(barberId)
          .get();
      
      if (doc.exists) {
        return BarberModel.fromMap(doc.data()!, doc.id);
      }
      return null;
    } catch (e) {
      throw 'Error getting barber: ${e.toString()}';
    }
  }

  Stream<List<BarberModel>> getBarbersStream(String salonId) {
    return _firestore
        .collection(AppConstants.salonsCollection)
        .doc(salonId)
        .collection(AppConstants.barbersSubcollection)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BarberModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateBarber(
    String salonId,
    String barberId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.salonsCollection)
          .doc(salonId)
          .collection(AppConstants.barbersSubcollection)
          .doc(barberId)
          .update(data);
    } catch (e) {
      throw 'Error updating barber: ${e.toString()}';
    }
  }

  // Bookings
  Future<String> createBooking(BookingModel booking) async {
    try {
      final doc = await _firestore
          .collection(AppConstants.bookingsCollection)
          .add(booking.toMap());
      return doc.id;
    } catch (e) {
      throw 'Error creating booking: ${e.toString()}';
    }
  }

  Stream<List<BookingModel>> getUserBookingsStream(String userId) {
    return _firestore
        .collection(AppConstants.bookingsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Stream<List<BookingModel>> getBarberQueueStream(
    String salonId,
    String barberId,
  ) {
    return _firestore
        .collection(AppConstants.salonsCollection)
        .doc(salonId)
        .collection(AppConstants.barbersSubcollection)
        .doc(barberId)
        .collection(AppConstants.queueSubcollection)
        .orderBy('timestamp', descending: false)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => BookingModel.fromMap(doc.data(), doc.id))
            .toList());
  }

  Future<void> updateBooking(
    String bookingId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.bookingsCollection)
          .doc(bookingId)
          .update(data);
    } catch (e) {
      throw 'Error updating booking: ${e.toString()}';
    }
  }

  Future<void> updateBarberQueueItem(
    String salonId,
    String barberId,
    String queueId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.salonsCollection)
          .doc(salonId)
          .collection(AppConstants.barbersSubcollection)
          .doc(barberId)
          .collection(AppConstants.queueSubcollection)
          .doc(queueId)
          .update(data);
    } catch (e) {
      throw 'Error updating queue item: ${e.toString()}';
    }
  }

  Future<void> addToBarberQueue(
    String salonId,
    String barberId,
    BookingModel booking,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.salonsCollection)
          .doc(salonId)
          .collection(AppConstants.barbersSubcollection)
          .doc(barberId)
          .collection(AppConstants.queueSubcollection)
          .doc(booking.id)
          .set(booking.toMap());
    } catch (e) {
      throw 'Error adding to queue: ${e.toString()}';
    }
  }

  Future<void> removeFromBarberQueue(
    String salonId,
    String barberId,
    String bookingId,
  ) async {
    try {
      await _firestore
          .collection(AppConstants.salonsCollection)
          .doc(salonId)
          .collection(AppConstants.barbersSubcollection)
          .doc(barberId)
          .collection(AppConstants.queueSubcollection)
          .doc(bookingId)
          .delete();
    } catch (e) {
      throw 'Error removing from queue: ${e.toString()}';
    }
  }
}
