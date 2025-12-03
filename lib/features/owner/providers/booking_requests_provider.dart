import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class BookingRequestsProvider extends ChangeNotifier {
  BookingRequestsProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  List<OwnerBookingRequest> _requests = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<OwnerBookingRequest> get requests => _requests;

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }

    _setLoading(true);
    _setError(null);
    try {
      final snap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('bookingRequests')
          .orderBy('createdAt', descending: true)
          .get();

      _requests = snap.docs
          .map((doc) => _mapRequest(doc.id, doc.data()))
          .whereType<OwnerBookingRequest>()
          .toList();
    } catch (e) {
      _setError('Failed to load requests. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  OwnerBookingRequest? _mapRequest(String id, Map<String, dynamic> data) {
    final services =
        (data['services'] as List?)?.map((e) => e.toString()).toList() ?? [];
    final statusString = (data['status'] as String?) ?? 'pending';
    final status = _statusFromString(statusString);

    final timestamp = data['dateTime'];
    DateTime dateTime;
    if (timestamp is Timestamp) {
      dateTime = timestamp.toDate();
    } else {
      dateTime = DateTime.now();
    }

    return OwnerBookingRequest(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      customerAvatar: (data['customerAvatar'] as String?) ?? '',
      customerPhone: (data['customerPhone'] as String?) ?? '',
      barberName: (data['barberName'] as String?) ?? 'Any',
      services: services,
      dateTime: dateTime,
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 30,
      totalPrice: (data['totalPrice'] as num?)?.toInt() ?? 0,
      status: status,
    );
  }

  OwnerBookingRequestStatus _statusFromString(String status) {
    switch (status) {
      case 'accepted':
        return OwnerBookingRequestStatus.accepted;
      case 'rejected':
        return OwnerBookingRequestStatus.rejected;
      default:
        return OwnerBookingRequestStatus.pending;
    }
  }

  Future<void> updateStatus(String id, OwnerBookingRequestStatus status) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    try {
      await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('bookingRequests')
          .doc(id)
          .set({'status': status.name}, SetOptions(merge: true));
    } catch (_) {
      _setError('Could not update status. Try again.');
    }

    _requests = _requests
        .map((r) => r.id == id ? r.copyWith(status: status) : r)
        .toList();
    notifyListeners();
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }
}
