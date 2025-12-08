import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'dart:async';
import 'package:intl/intl.dart';

/// Centralized queue fetching/merging logic shared by owner home and manage queue.
class OwnerQueueService {
  OwnerQueueService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;
  final StreamController<void> _queueUpdates =
      StreamController<void>.broadcast();

  Stream<void> get onChanged => _queueUpdates.stream;

  Future<List<OwnerQueueItem>> loadQueue(String ownerId) async {
    final queue = await _loadQueueCollection(ownerId);
    final bookings = await _loadBookingBackfill(ownerId);
    return _mergeQueue(queue, bookings);
  }

  Future<void> updateStatus({
    required String ownerId,
    required String id,
    required OwnerQueueStatus status,
  }) async {
    final queueStatus = status.name;
    final bookingStatus = _bookingStatusString(status);

    final queueRef =
        _firestore.collection('salons').doc(ownerId).collection('queue').doc(id);
    final bookingRef = _firestore
        .collection('salons')
        .doc(ownerId)
        .collection('bookings')
        .doc(id);

    try {
      final queueSnap = await queueRef.get();
      final bookingSnap = await bookingRef.get();
      final queueData =
          queueSnap.data() != null ? Map<String, dynamic>.from(queueSnap.data()!) : <String, dynamic>{};
      final bookingData =
          bookingSnap.data() != null ? Map<String, dynamic>.from(bookingSnap.data()!) : <String, dynamic>{};

      final merged = _buildQueuePayload(
        status: queueStatus,
        queueData: queueData,
        bookingData: bookingData,
      );

      await queueRef.set(merged, SetOptions(merge: true));
    } catch (_) {
      // best-effort status update even if merge fails
      await queueRef.set({'status': queueStatus}, SetOptions(merge: true));
    }

    // Mirror to bookings if the id matches a booking doc.
    await _firestore
        .collection('salons')
        .doc(ownerId)
        .collection('bookings')
        .doc(id)
        .set({'status': bookingStatus}, SetOptions(merge: true));

    _queueUpdates.add(null);
  }

  Map<String, dynamic> _buildQueuePayload({
    required String status,
    required Map<String, dynamic> queueData,
    required Map<String, dynamic> bookingData,
  }) {
    final String? date =
        (queueData['date'] as String?) ?? (bookingData['date'] as String?);
    final String? time =
        (queueData['time'] as String?) ?? (bookingData['time'] as String?);
    final Timestamp? dateTimeTs =
        (queueData['dateTime'] as Timestamp?) ?? (bookingData['dateTime'] as Timestamp?);

    final services = (bookingData['services'] as List?)
            ?.map((e) => (e is Map && e['name'] is String) ? e['name'] as String : '')
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    final serviceLabel = queueData['service'] as String? ??
        (services.isNotEmpty
            ? services.join(', ')
            : (bookingData['service'] as String?));

    final barberName =
        (queueData['barberName'] as String?) ?? (bookingData['barberName'] as String?);
    final customerName =
        (queueData['customerName'] as String?) ?? (bookingData['customerName'] as String?);
    final customerPhone =
        (queueData['customerPhone'] as String?) ?? (bookingData['customerPhone'] as String?);

    final timeLabel = (queueData['slotLabel'] as String?) ??
        (bookingData['time'] as String?) ??
        (bookingData['dateTime'] is Timestamp
            ? DateFormat('h:mm a').format((bookingData['dateTime'] as Timestamp).toDate())
            : null);

    final durationRaw = (queueData['waitMinutes'] as num?)?.toInt() ??
        (bookingData['durationMinutes'] as num?)?.toInt() ??
        (services.isNotEmpty ? services.length * 30 : null);

    final price = (queueData['price'] as num?)?.toInt() ??
        (bookingData['total'] as num?)?.toInt() ??
        (bookingData['price'] as num?)?.toInt();

    // Slot label fallback: use time, otherwise build from dateTime if present.
    final slotLabel = timeLabel ??
        (() {
          final dt = bookingData['dateTime'];
          if (dt is Timestamp) {
            return DateFormat('h:mm a').format(dt.toDate());
          }
          return null;
        }());

    return {
      'status': status,
      if (serviceLabel != null && serviceLabel.isNotEmpty) 'service': serviceLabel,
      if (barberName != null && barberName.isNotEmpty) 'barberName': barberName,
      if (customerName != null && customerName.isNotEmpty) 'customerName': customerName,
      if (customerPhone != null && customerPhone.isNotEmpty) 'customerPhone': customerPhone,
      if (slotLabel != null && slotLabel.isNotEmpty) 'slotLabel': slotLabel,
      if (date != null && date.isNotEmpty) 'date': date,
      if (time != null && time.isNotEmpty) 'time': time,
      if (dateTimeTs != null) 'dateTime': dateTimeTs,
      if (durationRaw != null) 'waitMinutes': durationRaw,
      if (price != null) 'price': price,
    };
  }

  Future<List<OwnerQueueItem>> _loadQueueCollection(String ownerId) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('queue')
          .get();
    } catch (_) {
      snap = await _firestore.collection('queue').get();
    }
    return snap.docs
        .map((doc) => _mapQueue(doc.id, doc.data()))
        .whereType<OwnerQueueItem>()
        .toList();
  }

  Future<List<OwnerQueueItem>> _loadBookingBackfill(String ownerId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _firestore
            .collection('salons')
            .doc(ownerId)
            .collection('bookings')
            .where('status',
                whereIn: ['waiting', 'serving', 'completed', 'done'])
            .get();
      } catch (_) {
        return const [];
      }
      return snap.docs
          .map((doc) => _mapBooking(doc.id, doc.data()))
          .whereType<OwnerQueueItem>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  List<OwnerQueueItem> _mergeQueue(
      List<OwnerQueueItem> queue, List<OwnerQueueItem> bookings) {
    final Map<String, OwnerQueueItem> map = {
      for (final item in queue) item.id: item
    };
    for (final item in bookings) {
      map[item.id] = item;
    }
    return map.values.toList();
  }

  OwnerQueueItem? _mapQueue(String id, Map<String, dynamic> data) {
    final statusString = (data['status'] as String?) ?? 'waiting';
    final status = _statusFromString(statusString);
    return OwnerQueueItem(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      service: (data['service'] as String?) ?? 'Service',
      barberName: (data['barberName'] as String?) ?? 'Barber',
      price: (data['price'] as num?)?.toInt() ?? 0,
      status: status,
      waitMinutes: (data['waitMinutes'] as num?)?.toInt() ?? 0,
      slotLabel: (data['slotLabel'] as String?) ?? id,
      customerPhone: (data['customerPhone'] as String?) ?? '',
      note: data['note'] as String?,
    );
  }

  OwnerQueueItem? _mapBooking(String id, Map<String, dynamic> data) {
    final statusString = (data['status'] as String?) ?? 'waiting';
    final status = _statusFromString(statusString);

    final services = (data['services'] as List?)
            ?.map((e) => (e is Map && e['name'] is String) ? e['name'] as String : '')
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    final serviceLabel = services.isNotEmpty
        ? services.join(', ')
        : (data['service'] as String?) ?? 'Service';

    final timeLabel = (data['time'] as String?) ??
        (data['dateTime'] is Timestamp
            ? DateFormat('h:mm a')
                .format((data['dateTime'] as Timestamp).toDate())
            : '');

    final durationRaw = (data['durationMinutes'] as num?)?.toInt();
    final duration =
        durationRaw ?? (services.isNotEmpty ? services.length * 30 : 30);

    return OwnerQueueItem(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      service: serviceLabel,
      barberName: (data['barberName'] as String?) ?? 'Barber',
      price: (data['total'] as num?)?.toInt() ?? 0,
      status: status,
      waitMinutes: duration,
      slotLabel: timeLabel.isNotEmpty ? timeLabel : id,
      customerPhone: (data['customerPhone'] as String?) ?? '',
      note: data['note'] as String?,
    );
  }

  OwnerQueueStatus _statusFromString(String status) {
    switch (status) {
      case 'serving':
        return OwnerQueueStatus.serving;
      case 'done':
      case 'completed':
        return OwnerQueueStatus.done;
      default:
        return OwnerQueueStatus.waiting;
    }
  }

  String _bookingStatusString(OwnerQueueStatus status) {
    switch (status) {
      case OwnerQueueStatus.serving:
        return 'serving';
      case OwnerQueueStatus.done:
        return 'completed';
      case OwnerQueueStatus.waiting:
        return 'waiting';
    }
  }
}
