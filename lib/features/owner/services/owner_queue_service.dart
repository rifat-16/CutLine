import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';

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
    final completed = await _loadCompletedToday(ownerId);
    final merged = _mergeQueue(queue, bookings);
    // Merge completed items
    final allMerged = _mergeQueue(merged, completed);
    // Load avatars - this will update the items in place
    await _hydrateCustomerAvatars(allMerged);
    return allMerged;
  }

  Future<void> _hydrateCustomerAvatars(List<OwnerQueueItem> items) async {
    final itemsNeedingAvatars = items
        .where((item) =>
            item.customerAvatar.isEmpty && item.customerUid.isNotEmpty)
        .toList();
    if (itemsNeedingAvatars.isEmpty) {
      return;
    }

    // Use individual document reads instead of whereIn query to work with current rules
    // This is more compatible with Firestore security rules
    final uniqueUids = itemsNeedingAvatars
        .map((item) => item.customerUid)
        .where((uid) => uid.isNotEmpty)
        .toSet()
        .toList();

    final avatarMap = <String, String>{};

    // Read documents individually - this works better with Firestore rules
    for (final uid in uniqueUids) {
      try {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          final data = doc.data() ?? {};
          final photoUrl = (data['photoUrl'] as String?) ??
              (data['avatarUrl'] as String?) ??
              (data['customerAvatar'] as String?) ??
              '';
          if (photoUrl.isNotEmpty) {
            avatarMap[uid] = photoUrl;
          } else {}
        } else {}
      } catch (e) {
        // Continue with other UIDs
      }
    }

    // Update items with avatars
    int updatedCount = 0;
    for (final item in itemsNeedingAvatars) {
      final avatar = avatarMap[item.customerUid];
      if (avatar != null && avatar.isNotEmpty) {
        final index = items.indexWhere((i) => i.id == item.id);
        if (index != -1) {
          items[index] = OwnerQueueItem(
            id: items[index].id,
            customerName: items[index].customerName,
            service: items[index].service,
            barberName: items[index].barberName,
            price: items[index].price,
            tipAmount: items[index].tipAmount,
            status: items[index].status,
            waitMinutes: items[index].waitMinutes,
            slotLabel: items[index].slotLabel,
            scheduledAt: items[index].scheduledAt,
            customerPhone: items[index].customerPhone,
            note: items[index].note,
            customerAvatar: avatar,
            customerUid: items[index].customerUid,
          );
          updatedCount++;
        }
      }
    }
  }

  Future<void> updateStatus({
    required String ownerId,
    required String id,
    required OwnerQueueStatus status,
  }) async {
    final queueStatus = status.name;
    final bookingStatus = _bookingStatusString(status);

    final queueRef = _firestore
        .collection('salons')
        .doc(ownerId)
        .collection('queue')
        .doc(id);
    final bookingRef = _firestore
        .collection('salons')
        .doc(ownerId)
        .collection('bookings')
        .doc(id);

    try {
      final queueSnap = await queueRef.get();
      final bookingSnap = await bookingRef.get();
      final queueData = queueSnap.data() != null
          ? Map<String, dynamic>.from(queueSnap.data()!)
          : <String, dynamic>{};
      final bookingData = bookingSnap.data() != null
          ? Map<String, dynamic>.from(bookingSnap.data()!)
          : <String, dynamic>{};

      final merged = _buildQueuePayload(
        status: queueStatus,
        queueData: queueData,
        bookingData: bookingData,
      );

      // Set completedAt timestamp when status is set to done
      if (status == OwnerQueueStatus.done) {
        merged['completedAt'] = FieldValue.serverTimestamp();
      }

      await queueRef.set(merged, SetOptions(merge: true));
      if (status == OwnerQueueStatus.done) {
        await _createLedgersForBooking(
          ownerId: ownerId,
          bookingId: id,
          data: bookingData.isNotEmpty ? bookingData : merged,
        );
      }
    } catch (_) {
      // best-effort status update even if merge fails
      final updateData = <String, dynamic>{'status': queueStatus};
      if (status == OwnerQueueStatus.done) {
        updateData['completedAt'] = FieldValue.serverTimestamp();
      }
      await queueRef.set(updateData, SetOptions(merge: true));
    }

    // Mirror to bookings if the id matches a booking doc.
    final bookingUpdateData = <String, dynamic>{'status': bookingStatus};
    if (status == OwnerQueueStatus.done) {
      bookingUpdateData['completedAt'] = FieldValue.serverTimestamp();
    }
    await _firestore
        .collection('salons')
        .doc(ownerId)
        .collection('bookings')
        .doc(id)
        .set(bookingUpdateData, SetOptions(merge: true));

    if (status == OwnerQueueStatus.done) {
      try {
        final bookingSnap = await bookingRef.get();
        final data = bookingSnap.data() ?? <String, dynamic>{};
        await _createLedgersForBooking(
          ownerId: ownerId,
          bookingId: id,
          data: data,
        );
      } catch (_) {
        // ignore ledger failure
      }
    }

    _queueUpdates.add(null);
  }

  Future<void> _createLedgersForBooking({
    required String ownerId,
    required String bookingId,
    required Map<String, dynamic> data,
  }) async {
    final salonId = (data['salonId'] as String?) ?? ownerId;
    final tipAmount = (data['tipAmount'] as num?)?.toInt() ?? 0;
    final serviceCharge = (data['serviceCharge'] as num?)?.toInt() ?? 0;
    String barberId =
        (data['barberId'] as String?) ?? (data['barberUid'] as String?) ?? '';
    String barberName =
        (data['barberName'] as String?) ?? (data['barber'] as String?) ?? '';
    final completedAt = data['completedAt'];

    if (barberId.isEmpty || barberName.isEmpty) {
      try {
        final salonDoc = await _firestore.collection('salons').doc(ownerId).get();
        final salonData = salonDoc.data() ?? <String, dynamic>{};
        final barbersList = salonData['barbers'] as List?;
        if (barbersList != null) {
          for (final barber in barbersList) {
            if (barber is Map) {
              final id = (barber['id'] as String?) ??
                  (barber['uid'] as String?) ??
                  '';
              final name = (barber['name'] as String?) ?? '';
              final matchesName = barberName.isNotEmpty &&
                  name.isNotEmpty &&
                  name.toLowerCase() == barberName.toLowerCase();
              final matchesId = barberId.isNotEmpty && id == barberId;
              if ((barberId.isEmpty && matchesName) ||
                  (barberName.isEmpty && matchesId)) {
                if (barberId.isEmpty) barberId = id;
                if (barberName.isEmpty) barberName = name;
                break;
              }
            }
          }
        }
      } catch (_) {
        // ignore lookup failures
      }
    }

    if (tipAmount > 0) {
      await _firestore.collection('barber_tip_ledger').doc(bookingId).set(
        {
          'bookingId': bookingId,
          'salonId': salonId,
          'barberId': barberId,
          'barberName': barberName,
          'tipAmount': tipAmount,
          'status': 'unpaid',
          'createdAt': FieldValue.serverTimestamp(),
          if (completedAt is Timestamp) 'completedAt': completedAt,
        },
        SetOptions(merge: true),
      );
    }

    if (serviceCharge > 0) {
      await _firestore.collection('platform_fee_ledger').doc(bookingId).set(
        {
          'bookingId': bookingId,
          'salonId': salonId,
          'feeAmount': serviceCharge,
          'status': 'unpaid',
          'createdAt': FieldValue.serverTimestamp(),
          if (completedAt is Timestamp) 'completedAt': completedAt,
        },
        SetOptions(merge: true),
      );
    }
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
    final Timestamp? dateTimeTs = (queueData['dateTime'] as Timestamp?) ??
        (bookingData['dateTime'] as Timestamp?);

    final services = (bookingData['services'] as List?)
            ?.map((e) =>
                (e is Map && e['name'] is String) ? e['name'] as String : '')
            .whereType<String>()
            .where((e) => e.isNotEmpty)
            .toList() ??
        const [];
    final serviceLabel = queueData['service'] as String? ??
        (services.isNotEmpty
            ? services.join(', ')
            : (bookingData['service'] as String?));

    final barberName = (queueData['barberName'] as String?) ??
        (bookingData['barberName'] as String?);
    final customerName = (queueData['customerName'] as String?) ??
        (bookingData['customerName'] as String?);
    final customerPhone = (queueData['customerPhone'] as String?) ??
        (bookingData['customerPhone'] as String?);

    final timeLabel = (queueData['slotLabel'] as String?) ??
        (bookingData['time'] as String?) ??
        (bookingData['dateTime'] is Timestamp
            ? DateFormat('h:mm a')
                .format((bookingData['dateTime'] as Timestamp).toDate())
            : null);

    final durationRaw = (queueData['waitMinutes'] as num?)?.toInt() ??
        (bookingData['durationMinutes'] as num?)?.toInt() ??
        (services.isNotEmpty ? services.length * 30 : null);

    final price = (queueData['price'] as num?)?.toInt() ??
        (bookingData['total'] as num?)?.toInt() ??
        (bookingData['price'] as num?)?.toInt();
    final tipAmount = (queueData['tipAmount'] as num?)?.toInt() ??
        (bookingData['tipAmount'] as num?)?.toInt();

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
      if (serviceLabel != null && serviceLabel.isNotEmpty)
        'service': serviceLabel,
      if (barberName != null && barberName.isNotEmpty) 'barberName': barberName,
      if (customerName != null && customerName.isNotEmpty)
        'customerName': customerName,
      if (customerPhone != null && customerPhone.isNotEmpty)
        'customerPhone': customerPhone,
      if (slotLabel != null && slotLabel.isNotEmpty) 'slotLabel': slotLabel,
      if (date != null && date.isNotEmpty) 'date': date,
      if (time != null && time.isNotEmpty) 'time': time,
      if (dateTimeTs != null) 'dateTime': dateTimeTs,
      if (durationRaw != null) 'waitMinutes': durationRaw,
      if (price != null) 'price': price,
      if (tipAmount != null) 'tipAmount': tipAmount,
    };
  }

  Future<List<OwnerQueueItem>> _loadQueueCollection(String ownerId) async {
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      // Try to load only active queue items first
      try {
        snap = await _firestore
            .collection('salons')
            .doc(ownerId)
            .collection('queue')
            .where('status',
                whereIn: ['waiting', 'turn_ready', 'arrived', 'serving']).get();
      } catch (e) {
        // Fallback: load all and filter
        try {
          snap = await _firestore
              .collection('salons')
              .doc(ownerId)
              .collection('queue')
              .get();
        } catch (e2) {
          rethrow; // Re-throw to be caught by outer catch
        }
      }
    } catch (_) {
      // Fallback to top-level queue collection (for backward compatibility)
      try {
        snap = await _firestore
            .collection('queue')
            .where('status', whereIn: ['waiting', 'serving']).get();
      } catch (_) {
        snap = await _firestore.collection('queue').get();
      }
    }
    return snap.docs
        .map((doc) => _mapQueue(doc.id, doc.data()))
        .whereType<OwnerQueueItem>()
        .where((item) =>
            item.status != OwnerQueueStatus.done &&
            item.status !=
                OwnerQueueStatus
                    .noShow) // Filter out completed and no-show items
        .toList();
  }

  Future<List<OwnerQueueItem>> _loadBookingBackfill(String ownerId) async {
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        // Only load active bookings (waiting or serving)
        snap = await _firestore
            .collection('salons')
            .doc(ownerId)
            .collection('bookings')
            .where('status',
                whereIn: ['waiting', 'turn_ready', 'arrived', 'serving']).get();
      } catch (e) {
        // Fallback: try loading all and filter
        try {
          snap = await _firestore
              .collection('salons')
              .doc(ownerId)
              .collection('bookings')
              .get();
        } catch (e2) {
          return const [];
        }
      }
      return snap.docs
          .map((doc) => _mapBooking(doc.id, doc.data()))
          .whereType<OwnerQueueItem>()
          .where((item) =>
              item.status != OwnerQueueStatus.done &&
              item.status !=
                  OwnerQueueStatus
                      .noShow) // Filter out completed and no-show items
          .toList();
    } catch (e) {
      return const [];
    }
  }

  /// Load today's completed queue items and bookings
  Future<List<OwnerQueueItem>> _loadCompletedToday(String ownerId) async {
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = todayStart.add(const Duration(days: 1));
    final todayStartTimestamp = Timestamp.fromDate(todayStart);
    final todayEndTimestamp = Timestamp.fromDate(todayEnd);
    final todayStr = DateFormat('yyyy-MM-dd').format(today);

    final completedItems = <OwnerQueueItem>[];

    try {
      // Load completed items from queue collection
      QuerySnapshot<Map<String, dynamic>> queueSnap;
      try {
        queueSnap = await _firestore
            .collection('salons')
            .doc(ownerId)
            .collection('queue')
            .where('status', whereIn: ['done', 'completed']).get();
      } catch (e) {
        // Fallback: load all and filter
        try {
          queueSnap = await _firestore
              .collection('salons')
              .doc(ownerId)
              .collection('queue')
              .get();
        } catch (e2) {
          queueSnap = await _firestore.collection('queue').get();
        }
      }

      for (final doc in queueSnap.docs) {
        final data = doc.data();
        final status = (data['status'] as String?) ?? '';
        if (status != 'done' && status != 'completed') continue;

        // Check if completed today
        bool isToday = false;
        final completedAt = data['completedAt'];
        final updatedAt = data['updatedAt'];
        final date = data['date'] as String?;

        if (completedAt != null && completedAt is Timestamp) {
          final completedDate = completedAt.toDate();
          isToday = !completedDate.isBefore(todayStart) &&
              completedDate.isBefore(todayEnd);
        } else if (date != null && date == todayStr) {
          isToday = true;
        } else if (updatedAt != null && updatedAt is Timestamp) {
          final updatedDate = updatedAt.toDate();
          // If updatedAt is today and status is completed, assume it was completed today
          isToday = !updatedDate.isBefore(todayStart) &&
              updatedDate.isBefore(todayEnd);
        }

        if (isToday) {
          final item = _mapQueue(doc.id, data);
          if (item != null) {
            completedItems.add(item);
          }
        }
      }

      // Load completed items from bookings collection
      QuerySnapshot<Map<String, dynamic>> bookingSnap;
      try {
        bookingSnap = await _firestore
            .collection('salons')
            .doc(ownerId)
            .collection('bookings')
            .where('status', whereIn: ['completed', 'done']).get();
      } catch (e) {
        // Fallback: load all and filter
        bookingSnap = await _firestore
            .collection('salons')
            .doc(ownerId)
            .collection('bookings')
            .get();
      }

      for (final doc in bookingSnap.docs) {
        final data = doc.data();
        final status = (data['status'] as String?) ?? '';
        if (status != 'completed' && status != 'done') continue;

        // Check if completed today
        bool isToday = false;
        final completedAt = data['completedAt'];
        final dateTime = data['dateTime'];
        final updatedAt = data['updatedAt'];
        final date = data['date'] as String?;

        if (completedAt != null && completedAt is Timestamp) {
          final completedDate = completedAt.toDate();
          isToday = !completedDate.isBefore(todayStart) &&
              completedDate.isBefore(todayEnd);
        } else if (dateTime != null && dateTime is Timestamp) {
          final bookingDate = dateTime.toDate();
          // If booking dateTime is today and status is completed, include it
          isToday = !bookingDate.isBefore(todayStart) &&
              bookingDate.isBefore(todayEnd);
        } else if (date != null && date == todayStr) {
          isToday = true;
        } else if (updatedAt != null && updatedAt is Timestamp) {
          final updatedDate = updatedAt.toDate();
          // If updatedAt is today and status is completed, assume it was completed today
          isToday = !updatedDate.isBefore(todayStart) &&
              updatedDate.isBefore(todayEnd);
        }

        if (isToday) {
          final item = _mapBooking(doc.id, data);
          if (item != null && item.status == OwnerQueueStatus.done) {
            completedItems.add(item);
          }
        }
      }
    } catch (e) {
      // Return whatever we've collected so far
    }

    return completedItems;
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
    final scheduledAt = _parseScheduledAt(data);
    return OwnerQueueItem(
      id: id,
      customerName: (data['customerName'] as String?) ?? 'Customer',
      service: (data['service'] as String?) ?? 'Service',
      barberName: (data['barberName'] as String?) ?? 'Barber',
      price: (data['price'] as num?)?.toInt() ?? 0,
      tipAmount: (data['tipAmount'] as num?)?.toInt() ?? 0,
      status: status,
      waitMinutes: (data['waitMinutes'] as num?)?.toInt() ?? 0,
      slotLabel: (data['slotLabel'] as String?) ?? id,
      scheduledAt: scheduledAt,
      customerPhone: (data['customerPhone'] as String?) ?? '',
      note: data['note'] as String?,
      customerAvatar: (data['customerAvatar'] as String?) ??
          (data['customerPhotoUrl'] as String?) ??
          (data['photoUrl'] as String?) ??
          '',
      customerUid: (data['customerUid'] as String?) ??
          (data['userId'] as String?) ??
          (data['customerId'] as String?) ??
          (data['uid'] as String?) ??
          '',
    );
  }

  OwnerQueueItem? _mapBooking(String id, Map<String, dynamic> data) {
    final statusString = (data['status'] as String?) ?? 'waiting';
    final status = _statusFromString(statusString);
    final scheduledAt = _parseScheduledAt(data);

    final services = (data['services'] as List?)
            ?.map((e) =>
                (e is Map && e['name'] is String) ? e['name'] as String : '')
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
      tipAmount: (data['tipAmount'] as num?)?.toInt() ?? 0,
      status: status,
      waitMinutes: duration,
      slotLabel: timeLabel.isNotEmpty ? timeLabel : id,
      scheduledAt: scheduledAt,
      customerPhone: (data['customerPhone'] as String?) ?? '',
      note: data['note'] as String?,
      customerAvatar: (data['customerAvatar'] as String?) ??
          (data['customerPhotoUrl'] as String?) ??
          (data['photoUrl'] as String?) ??
          '',
      customerUid: (data['customerUid'] as String?) ??
          (data['userId'] as String?) ??
          (data['customerId'] as String?) ??
          (data['uid'] as String?) ??
          '',
    );
  }

  OwnerQueueStatus _statusFromString(String status) {
    switch (status) {
      case 'turn_ready':
        return OwnerQueueStatus.turnReady;
      case 'arrived':
        return OwnerQueueStatus.arrived;
      case 'serving':
        return OwnerQueueStatus.serving;
      case 'done':
      case 'completed':
        return OwnerQueueStatus.done;
      case 'no_show':
        return OwnerQueueStatus.noShow;
      default:
        return OwnerQueueStatus.waiting;
    }
  }

  String _bookingStatusString(OwnerQueueStatus status) {
    switch (status) {
      case OwnerQueueStatus.turnReady:
        return 'turn_ready';
      case OwnerQueueStatus.arrived:
        return 'arrived';
      case OwnerQueueStatus.serving:
        return 'serving';
      case OwnerQueueStatus.done:
        return 'completed';
      case OwnerQueueStatus.noShow:
        return 'no_show';
      case OwnerQueueStatus.waiting:
        return 'waiting';
    }
  }

  DateTime? _parseScheduledAt(Map<String, dynamic> data) {
    final ts = data['dateTime'];
    if (ts is Timestamp) return ts.toDate();

    final dateStr = (data['date'] as String?)?.trim() ?? '';
    final timeStr = ((data['time'] as String?) ??
                (data['bookingTime'] as String?) ??
                (data['slotLabel'] as String?))
            ?.trim() ??
        '';
    if (dateStr.isEmpty || timeStr.isEmpty) return null;

    try {
      final date = DateTime.parse(dateStr);
      final time = DateFormat('h:mm a').parse(timeStr);
      return DateTime(date.year, date.month, date.day, time.hour, time.minute);
    } catch (_) {
      return null;
    }
  }
}
