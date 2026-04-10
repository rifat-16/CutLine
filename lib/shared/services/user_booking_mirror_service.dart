import 'package:cloud_firestore/cloud_firestore.dart';

class UserBookingMirrorService {
  UserBookingMirrorService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  static String normalizeStatus(String? rawStatus) {
    final status = (rawStatus ?? '').trim().toLowerCase();
    switch (status) {
      case '':
        return 'upcoming';
      case 'accepted':
        return 'waiting';
      case 'canceled':
        return 'cancelled';
      case 'done':
      case 'served':
        return 'completed';
      case 'no-show':
      case 'noshow':
        return 'no_show';
      default:
        return status;
    }
  }

  static bool isCompletedStatus(String? status) {
    return normalizeStatus(status) == 'completed';
  }

  static bool isCancelledStatus(String? status) {
    final normalized = normalizeStatus(status);
    return normalized == 'cancelled' ||
        normalized == 'no_show' ||
        normalized == 'rejected';
  }

  static bool isTerminalStatus(String? status) {
    return isCompletedStatus(status) || isCancelledStatus(status);
  }

  static bool shouldReconcileFromSource(String? status) {
    return !isTerminalStatus(status);
  }

  static String displayLabel(String? status) {
    switch (normalizeStatus(status)) {
      case 'pending':
        return 'Pending';
      case 'waiting':
        return 'Waiting';
      case 'arrived':
        return 'Arrived';
      case 'serving':
        return 'Serving';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      case 'no_show':
        return 'No Show';
      case 'rejected':
        return 'Rejected';
      default:
        return 'Upcoming';
    }
  }

  Future<void> updateStatus({
    required String userId,
    required String bookingId,
    required String status,
    Map<String, dynamic>? extraFields,
  }) async {
    final trimmedUserId = userId.trim();
    final trimmedBookingId = bookingId.trim();
    if (trimmedUserId.isEmpty || trimmedBookingId.isEmpty) return;

    final normalizedStatus = normalizeStatus(status);
    final userRef = _firestore.collection('users').doc(trimmedUserId);
    final batch = _firestore.batch();

    batch.set(
      userRef,
      {
        if (isTerminalStatus(normalizedStatus))
          'activeBookingIds': FieldValue.arrayRemove([trimmedBookingId]),
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );

    batch.set(
      userRef.collection('bookings').doc(trimmedBookingId),
      {
        'status': normalizedStatus,
        'updatedAt': FieldValue.serverTimestamp(),
        if (extraFields != null) ...extraFields,
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }
}
