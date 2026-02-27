import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class QueueServiceOption {
  final String id;
  final String name;
  final int price;
  final int durationMinutes;

  const QueueServiceOption({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
  });
}

class QueueBarberOption {
  final String id;
  final String name;

  const QueueBarberOption({
    required this.id,
    required this.name,
  });
}

class QueueSerialService {
  QueueSerialService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<QueueServiceOption>> loadServices({
    required String salonId,
  }) async {
    if (salonId.trim().isEmpty) return const [];
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await _firestore
            .collection('salons')
            .doc(salonId)
            .collection('all_services')
            .orderBy('order')
            .get();
      } catch (_) {
        snap = await _firestore
            .collection('salons')
            .doc(salonId)
            .collection('all_services')
            .get();
      }

      return snap.docs
          .map((doc) {
            final data = doc.data();
            final name = (data['name'] as String?)?.trim() ?? '';
            if (name.isEmpty) return null;
            return QueueServiceOption(
              id: doc.id,
              name: name,
              price: (data['price'] as num?)?.toInt() ?? 0,
              durationMinutes: (data['durationMinutes'] as num?)?.toInt() ??
                  (data['duration'] as num?)?.toInt() ??
                  30,
            );
          })
          .whereType<QueueServiceOption>()
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<QueueBarberOption>> loadBarbers({
    required String salonId,
  }) async {
    if (salonId.trim().isEmpty) return const [];
    final mapped = <QueueBarberOption>[];
    try {
      final barbersSnap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('barbers')
          .get();
      for (final doc in barbersSnap.docs) {
        final data = doc.data();
        final name = (data['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        final uid = (data['uid'] as String?)?.trim() ?? '';
        mapped.add(
          QueueBarberOption(
            id: uid.isNotEmpty ? uid : doc.id,
            name: name,
          ),
        );
      }
    } catch (_) {
      // fall through to embedded fallback
    }

    if (mapped.isNotEmpty) {
      mapped
          .sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return mapped;
    }

    try {
      final salonDoc = await _firestore.collection('salons').doc(salonId).get();
      final salonData = salonDoc.data() ?? <String, dynamic>{};
      final embedded = salonData['barbers'];
      if (embedded is! List) return const [];

      final list = <QueueBarberOption>[];
      for (final item in embedded) {
        if (item is! Map) continue;
        final map = item.cast<String, dynamic>();
        final name = (map['name'] as String?)?.trim() ?? '';
        if (name.isEmpty) continue;
        final id = (map['uid'] as String?)?.trim() ??
            (map['id'] as String?)?.trim() ??
            '';
        list.add(QueueBarberOption(id: id, name: name));
      }
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    } catch (_) {
      return const [];
    }
  }

  Future<int> reservePerBarberSerial({
    required String salonId,
    required String serialDate,
    required String serialBarberKey,
  }) async {
    final sanitizedDate = serialDate.trim().isEmpty
        ? DateFormat('yyyy-MM-dd').format(DateTime.now())
        : serialDate.trim();
    final barberKey = _sanitizeKey(serialBarberKey);
    return _firestore.runTransaction((tx) async {
      return _reservePerBarberSerialInTx(
        tx: tx,
        salonId: salonId,
        serialDate: sanitizedDate,
        serialBarberKey: barberKey,
      );
    });
  }

  Future<String> createManualByOwner({
    required String salonId,
    required String actorUid,
    required String customerName,
    required QueueBarberOption barber,
    required QueueServiceOption service,
  }) {
    return _createManualEntry(
      salonId: salonId,
      actorUid: actorUid,
      actorRole: 'owner',
      customerName: customerName,
      barber: barber,
      service: service,
    );
  }

  Future<String> createManualByBarber({
    required String salonId,
    required String actorUid,
    required String customerName,
    required QueueBarberOption barber,
    required QueueServiceOption service,
  }) {
    return _createManualEntry(
      salonId: salonId,
      actorUid: actorUid,
      actorRole: 'barber',
      customerName: customerName,
      barber: barber,
      service: service,
    );
  }

  Future<void> updateManualEntry({
    required String salonId,
    required String entryId,
    required String actorUid,
    required String actorRole,
    required String customerName,
    required QueueBarberOption barber,
    required QueueServiceOption service,
  }) async {
    final queueRef = _firestore
        .collection('salons')
        .doc(salonId)
        .collection('queue')
        .doc(entryId);
    final bookingRef = _firestore
        .collection('salons')
        .doc(salonId)
        .collection('bookings')
        .doc(entryId);

    try {
      await _firestore.runTransaction((tx) async {
        final queueSnap = await tx.get(queueRef);
        final bookingSnap = await tx.get(bookingRef);
        if (!queueSnap.exists && !bookingSnap.exists) {
          throw Exception('Entry not found.');
        }

        final base = <String, dynamic>{};
        if (bookingSnap.exists) base.addAll(bookingSnap.data() ?? {});
        if (queueSnap.exists) base.addAll(queueSnap.data() ?? {});

        final existingSource = (base['entrySource'] as String?)?.trim();
        if ((existingSource ?? '').isNotEmpty && existingSource != 'manual') {
          throw Exception('Only manual entries are editable.');
        }

        final serialDate =
            (base['serialDate'] as String?)?.trim().isNotEmpty == true
                ? (base['serialDate'] as String).trim()
                : DateFormat('yyyy-MM-dd').format(DateTime.now());
        final targetBarberKey = _barberKey(barber.id, barber.name);

        final existingBarberKey =
            (base['serialBarberKey'] as String?)?.trim().toLowerCase() ?? '';
        final existingDate = (base['serialDate'] as String?)?.trim() ?? '';
        int serialNo = (base['serialNo'] as num?)?.toInt() ?? 0;

        if (serialNo <= 0 ||
            existingBarberKey != targetBarberKey ||
            existingDate != serialDate) {
          serialNo = await _reservePerBarberSerialInTx(
            tx: tx,
            salonId: salonId,
            serialDate: serialDate,
            serialBarberKey: targetBarberKey,
          );
        }

        final now = DateTime.now();
        final payload = _baseManualPayload(
          salonId: salonId,
          customerName: customerName,
          barber: barber,
          service: service,
          serialNo: serialNo,
          serialDate: serialDate,
          serialBarberKey: targetBarberKey,
          actorUid: actorUid,
          actorRole: actorRole,
          now: now,
        );
        payload.remove('createdAt');

        tx.set(queueRef, payload, SetOptions(merge: true));
        tx.set(
          bookingRef,
          {
            ...payload,
            'status': 'waiting',
          },
          SetOptions(merge: true),
        );
      });
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      await _updateManualEntryWithoutCounter(
        queueRef: queueRef,
        bookingRef: bookingRef,
        salonId: salonId,
        actorUid: actorUid,
        actorRole: actorRole,
        customerName: customerName,
        barber: barber,
        service: service,
      );
    }
  }

  Future<void> deleteManualEntry({
    required String salonId,
    required String entryId,
  }) async {
    final queueRef = _firestore
        .collection('salons')
        .doc(salonId)
        .collection('queue')
        .doc(entryId);
    final bookingRef = _firestore
        .collection('salons')
        .doc(salonId)
        .collection('bookings')
        .doc(entryId);

    final queueSnap = await queueRef.get();
    final bookingSnap = await bookingRef.get();
    if (!queueSnap.exists && !bookingSnap.exists) return;

    final source = ((queueSnap.data() ??
            bookingSnap.data() ??
            {})['entrySource'] as String?)
        ?.trim();
    if (source != null && source.isNotEmpty && source != 'manual') {
      throw Exception('Only manual entries can be deleted.');
    }

    final batch = _firestore.batch();
    if (queueSnap.exists) batch.delete(queueRef);
    if (bookingSnap.exists) batch.delete(bookingRef);
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // Keep queue state consistent even when booking mirror rules are stale.
      if (queueSnap.exists) {
        await queueRef.delete();
      }
    }
  }

  Future<String> _createManualEntry({
    required String salonId,
    required String actorUid,
    required String actorRole,
    required String customerName,
    required QueueBarberOption barber,
    required QueueServiceOption service,
  }) async {
    final queueRef =
        _firestore.collection('salons').doc(salonId).collection('queue').doc();
    final bookingRef = _firestore
        .collection('salons')
        .doc(salonId)
        .collection('bookings')
        .doc(queueRef.id);

    try {
      await _firestore.runTransaction((tx) async {
        final now = DateTime.now();
        final serialDate = DateFormat('yyyy-MM-dd').format(now);
        final serialBarberKey = _barberKey(barber.id, barber.name);
        final serialNo = await _reservePerBarberSerialInTx(
          tx: tx,
          salonId: salonId,
          serialDate: serialDate,
          serialBarberKey: serialBarberKey,
        );

        final payload = _baseManualPayload(
          salonId: salonId,
          customerName: customerName,
          barber: barber,
          service: service,
          serialNo: serialNo,
          serialDate: serialDate,
          serialBarberKey: serialBarberKey,
          actorUid: actorUid,
          actorRole: actorRole,
          now: now,
        );

        tx.set(queueRef, payload, SetOptions(merge: true));
        tx.set(
          bookingRef,
          {
            ...payload,
            'status': 'waiting',
          },
          SetOptions(merge: true),
        );
      });
    } on FirebaseException catch (e) {
      // If serial counter path is blocked by old rules, fallback to
      // deriving serial from existing queue+booking docs.
      if (e.code != 'permission-denied') rethrow;
      await _createManualEntryWithoutCounter(
        queueRef: queueRef,
        bookingRef: bookingRef,
        salonId: salonId,
        actorUid: actorUid,
        actorRole: actorRole,
        customerName: customerName,
        barber: barber,
        service: service,
      );
    }

    return queueRef.id;
  }

  Future<void> _createManualEntryWithoutCounter({
    required DocumentReference<Map<String, dynamic>> queueRef,
    required DocumentReference<Map<String, dynamic>> bookingRef,
    required String salonId,
    required String actorUid,
    required String actorRole,
    required String customerName,
    required QueueBarberOption barber,
    required QueueServiceOption service,
  }) async {
    final now = DateTime.now();
    final serialDate = DateFormat('yyyy-MM-dd').format(now);
    final serialBarberKey = _barberKey(barber.id, barber.name);
    final serialNo = await _deriveNextSerialNo(
      salonId: salonId,
      serialDate: serialDate,
      serialBarberKey: serialBarberKey,
    );
    final payload = _baseManualPayload(
      salonId: salonId,
      customerName: customerName,
      barber: barber,
      service: service,
      serialNo: serialNo,
      serialDate: serialDate,
      serialBarberKey: serialBarberKey,
      actorUid: actorUid,
      actorRole: actorRole,
      now: now,
    );

    await _writeQueueWithBookingMirrorFallback(
      queueRef: queueRef,
      bookingRef: bookingRef,
      queuePayload: payload,
      bookingPayload: {
        ...payload,
        'status': 'waiting',
      },
    );
  }

  Future<int> _deriveNextSerialNo({
    required String salonId,
    required String serialDate,
    required String serialBarberKey,
  }) async {
    int maxSerial = 0;
    try {
      final queueSnap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('queue')
          .where('serialDate', isEqualTo: serialDate)
          .where('serialBarberKey', isEqualTo: serialBarberKey)
          .get();
      for (final doc in queueSnap.docs) {
        final value = (doc.data()['serialNo'] as num?)?.toInt() ?? 0;
        if (value > maxSerial) maxSerial = value;
      }
    } catch (_) {
      // Ignore partial lookup failures.
    }

    try {
      final bookingSnap = await _firestore
          .collection('salons')
          .doc(salonId)
          .collection('bookings')
          .where('serialDate', isEqualTo: serialDate)
          .where('serialBarberKey', isEqualTo: serialBarberKey)
          .get();
      for (final doc in bookingSnap.docs) {
        final value = (doc.data()['serialNo'] as num?)?.toInt() ?? 0;
        if (value > maxSerial) maxSerial = value;
      }
    } catch (_) {
      // Ignore partial lookup failures.
    }

    return maxSerial + 1;
  }

  Future<void> _updateManualEntryWithoutCounter({
    required DocumentReference<Map<String, dynamic>> queueRef,
    required DocumentReference<Map<String, dynamic>> bookingRef,
    required String salonId,
    required String actorUid,
    required String actorRole,
    required String customerName,
    required QueueBarberOption barber,
    required QueueServiceOption service,
  }) async {
    final queueSnap = await queueRef.get();
    final bookingSnap = await bookingRef.get();
    if (!queueSnap.exists && !bookingSnap.exists) {
      throw Exception('Entry not found.');
    }

    final base = <String, dynamic>{};
    if (bookingSnap.exists) base.addAll(bookingSnap.data() ?? {});
    if (queueSnap.exists) base.addAll(queueSnap.data() ?? {});

    final existingSource = (base['entrySource'] as String?)?.trim();
    if ((existingSource ?? '').isNotEmpty && existingSource != 'manual') {
      throw Exception('Only manual entries are editable.');
    }

    final serialDate =
        (base['serialDate'] as String?)?.trim().isNotEmpty == true
            ? (base['serialDate'] as String).trim()
            : DateFormat('yyyy-MM-dd').format(DateTime.now());
    final targetBarberKey = _barberKey(barber.id, barber.name);
    final existingBarberKey =
        (base['serialBarberKey'] as String?)?.trim().toLowerCase() ?? '';
    final existingDate = (base['serialDate'] as String?)?.trim() ?? '';
    int serialNo = (base['serialNo'] as num?)?.toInt() ?? 0;
    if (serialNo <= 0 ||
        existingBarberKey != targetBarberKey ||
        existingDate != serialDate) {
      serialNo = await _deriveNextSerialNo(
        salonId: salonId,
        serialDate: serialDate,
        serialBarberKey: targetBarberKey,
      );
    }

    final now = DateTime.now();
    final payload = _baseManualPayload(
      salonId: salonId,
      customerName: customerName,
      barber: barber,
      service: service,
      serialNo: serialNo,
      serialDate: serialDate,
      serialBarberKey: targetBarberKey,
      actorUid: actorUid,
      actorRole: actorRole,
      now: now,
    );
    payload.remove('createdAt');

    await _writeQueueWithBookingMirrorFallback(
      queueRef: queueRef,
      bookingRef: bookingRef,
      queuePayload: payload,
      bookingPayload: {
        ...payload,
        'status': 'waiting',
      },
    );
  }

  Future<void> _writeQueueWithBookingMirrorFallback({
    required DocumentReference<Map<String, dynamic>> queueRef,
    required DocumentReference<Map<String, dynamic>> bookingRef,
    required Map<String, dynamic> queuePayload,
    required Map<String, dynamic> bookingPayload,
  }) async {
    final batch = _firestore.batch();
    batch.set(queueRef, queuePayload, SetOptions(merge: true));
    batch.set(bookingRef, bookingPayload, SetOptions(merge: true));
    try {
      await batch.commit();
    } on FirebaseException catch (e) {
      if (e.code != 'permission-denied') rethrow;
      // Queue should remain operational even if booking mirror writes are blocked.
      await queueRef.set(queuePayload, SetOptions(merge: true));
    }
  }

  Map<String, dynamic> _baseManualPayload({
    required String salonId,
    required String customerName,
    required QueueBarberOption barber,
    required QueueServiceOption service,
    required int serialNo,
    required String serialDate,
    required String serialBarberKey,
    required String actorUid,
    required String actorRole,
    required DateTime now,
  }) {
    final safeDuration =
        service.durationMinutes > 0 ? service.durationMinutes : 30;
    final timeLabel = DateFormat('h:mm a').format(now);
    return {
      'entrySource': 'manual',
      'salonId': salonId,
      'customerName': customerName.trim(),
      'barberId': barber.id,
      'barberName': barber.name,
      'serviceId': service.id,
      'service': service.name,
      'price': service.price,
      'total': service.price,
      'waitMinutes': safeDuration,
      'durationMinutes': safeDuration,
      'tipAmount': 0,
      'status': 'waiting',
      'serialNo': serialNo,
      'serialDate': serialDate,
      'serialBarberKey': serialBarberKey,
      'slotLabel': '#$serialNo',
      'date': serialDate,
      'time': timeLabel,
      'dateTime': Timestamp.fromDate(now),
      'createdByUid': actorUid,
      'createdByRole': actorRole,
      'customerPhone': '',
      'paymentMethod': 'Cash',
      'updatedAt': FieldValue.serverTimestamp(),
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  Future<int> _reservePerBarberSerialInTx({
    required Transaction tx,
    required String salonId,
    required String serialDate,
    required String serialBarberKey,
  }) async {
    final counterRef = _counterRef(
      salonId: salonId,
      serialDate: serialDate,
      serialBarberKey: serialBarberKey,
    );
    final snap = await tx.get(counterRef);
    final nextSerial = (snap.data()?['nextSerial'] as num?)?.toInt() ?? 1;
    tx.set(
      counterRef,
      {
        'serialDate': serialDate,
        'serialBarberKey': serialBarberKey,
        'nextSerial': nextSerial + 1,
        'updatedAt': FieldValue.serverTimestamp(),
      },
      SetOptions(merge: true),
    );
    return nextSerial;
  }

  DocumentReference<Map<String, dynamic>> _counterRef({
    required String salonId,
    required String serialDate,
    required String serialBarberKey,
  }) {
    final key = _sanitizeKey(serialBarberKey);
    final docId = '${serialDate}_$key';
    return _firestore
        .collection('salons')
        .doc(salonId)
        .collection('serial_counters')
        .doc(docId);
  }

  String _barberKey(String barberId, String barberName) {
    final candidate =
        barberId.trim().isNotEmpty ? barberId.trim() : barberName.trim();
    return _sanitizeKey(candidate);
  }

  String _sanitizeKey(String value) {
    final lower = value.toLowerCase();
    final cleaned = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final compact = cleaned.replaceAll(RegExp(r'_+'), '_').trim();
    final trimmed = compact.replaceAll(RegExp(r'^_+|_+$'), '');
    return trimmed.isEmpty ? 'unknown' : trimmed;
  }
}
