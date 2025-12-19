import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
      QuerySnapshot<Map<String, dynamic>> snap;
      final collection = _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('bookings');

      // Booking requests screen should only show new requests (pending/upcoming).
      // Some devices may not have the required index for (status + createdAt),
      // so gracefully fall back to a broader read + local filtering.
      try {
        snap = await collection
            .where('status', whereIn: ['pending', 'upcoming'])
            .orderBy('createdAt', descending: true)
            .get();
      } catch (_) {
        try {
          snap = await collection
              .where('status', whereIn: ['pending', 'upcoming']).get();
        } catch (_) {
          snap = await collection.get();
        }
      }

      _requests = snap.docs
          .map((doc) => _mapRequest(doc.id, doc.data()))
          .whereType<OwnerBookingRequest>()
          .toList();

      _requests.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      await _hydrateCustomerAvatars();
    } catch (_) {
      _setError('Failed to load requests. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _hydrateCustomerAvatars() async {
    final requestsNeedingAvatars = _requests
        .where((r) => r.customerAvatar.isEmpty && r.customerUid.isNotEmpty)
        .toList();
    if (requestsNeedingAvatars.isEmpty) return;

    final batchSize = 10;
    for (int i = 0; i < requestsNeedingAvatars.length; i += batchSize) {
      final batch = requestsNeedingAvatars.skip(i).take(batchSize).toList();
      final uids = batch.map((r) => r.customerUid).toList();

      try {
        final snap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: uids)
            .get();

        final avatarMap = <String, String>{};
        for (final doc in snap.docs) {
          final data = doc.data();
          final photoUrl = (data['photoUrl'] as String?) ??
              (data['avatarUrl'] as String?) ??
              (data['customerAvatar'] as String?) ??
              '';
          if (photoUrl.isNotEmpty) {
            avatarMap[doc.id] = photoUrl;
          }
        }

        for (final request in batch) {
          final avatar = avatarMap[request.customerUid];
          if (avatar != null && avatar.isNotEmpty) {
            final index = _requests.indexWhere((r) => r.id == request.id);
            if (index != -1) {
              _requests[index] =
                  _requests[index].copyWith(customerAvatar: avatar);
            }
          }
        }
      } catch (_) {
        // Ignore errors in avatar fetching
      }
    }
    notifyListeners();
  }

  OwnerBookingRequest? _mapRequest(String id, Map<String, dynamic> data) {
    final rawStatus = ((data['status'] as String?) ?? 'pending').toLowerCase();
    if (!_isBookingRequestStatus(rawStatus)) return null;

    final services = _mapServices(data['services']);
    final status = _statusFromString(rawStatus);

    final rawDate =
        (data['date'] is String) ? (data['date'] as String).trim() : '';
    final rawTime = (data['time'] is String)
        ? _normalizeTimeString(data['time'] as String)
        : '';
    final dateTime = _parseDateTime(rawDate, rawTime) ??
        _parseTimestamp(data['dateTime']) ??
        DateTime.now();

    return OwnerBookingRequest(
      id: id,
      customerName: (data['customerName'] as String?)?.trim() ?? 'Customer',
      customerAvatar: (data['customerAvatar'] as String?) ??
          (data['customerPhotoUrl'] as String?) ??
          (data['photoUrl'] as String?) ??
          '',
      customerUid: (data['customerUid'] as String?) ??
          (data['customerId'] as String?) ??
          (data['uid'] as String?) ??
          '',
      customerPhone: (data['customerPhone'] as String?)?.trim() ?? '',
      barberName: (data['barberName'] as String?)?.trim() ?? 'Any',
      services: services,
      dateTime: dateTime,
      date: rawDate.isNotEmpty ? rawDate : null,
      time: rawTime.isNotEmpty ? rawTime : null,
      durationMinutes: _durationMinutes(data, services.length),
      totalPrice: (data['total'] as num?)?.toInt() ??
          (data['totalPrice'] as num?)?.toInt() ??
          0,
      status: status,
    );
  }

  List<String> _mapServices(dynamic raw) {
    if (raw is! List) return [];
    return raw
        .map((e) {
          if (e is Map<String, dynamic>) {
            final name = e['name'];
            if (name is String && name.trim().isNotEmpty) return name.trim();
          } else if (e is String && e.trim().isNotEmpty) {
            return e.trim();
          }
          return null;
        })
        .whereType<String>()
        .toList();
  }

  int _durationMinutes(Map<String, dynamic> data, int serviceCount) {
    return (data['durationMinutes'] as num?)?.toInt() ??
        (data['duration'] as num?)?.toInt() ??
        (serviceCount > 0 ? serviceCount * 30 : 30);
  }

  DateTime? _parseTimestamp(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  String _normalizeTimeString(String value) {
    return value
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u202F', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  DateTime? _parseDateTime(String date, String time) {
    if (date.isEmpty || time.isEmpty) return null;
    try {
      final parsedDate = DateTime.parse(date);
      final parsedTime =
          DateFormat('h:mm a', 'en_US').parse(_normalizeTimeString(time));
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
          parsedTime.hour, parsedTime.minute);
    } catch (_) {
      return null;
    }
  }

  OwnerBookingRequestStatus _statusFromString(String status) {
    switch (status) {
      case 'accepted':
        return OwnerBookingRequestStatus.accepted;
      case 'waiting':
        return OwnerBookingRequestStatus.accepted;
      case 'rejected':
        return OwnerBookingRequestStatus.rejected;
      case 'cancelled':
      case 'completed':
        return OwnerBookingRequestStatus.rejected;
      case 'upcoming':
        return OwnerBookingRequestStatus.pending;
      default:
        return OwnerBookingRequestStatus.pending;
    }
  }

  bool _isBookingRequestStatus(String status) {
    // Only show items that still need an owner decision.
    // Statuses like waiting/serving/arrived/turn_ready are active queue items,
    // not booking requests.
    return status == 'pending' || status == 'upcoming' || status.isEmpty;
  }

  Future<void> updateStatus(String id, OwnerBookingRequestStatus status) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    final statusToSave =
        status == OwnerBookingRequestStatus.accepted ? 'waiting' : 'rejected';
    OwnerBookingRequest? request;
    for (final r in _requests) {
      if (r.id == id) {
        request = r;
        break;
      }
    }

    try {
      await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('bookings')
          .doc(id)
          .set({'status': statusToSave}, SetOptions(merge: true));
    } catch (_) {
      _setError('Could not update status. Try again.');
    }

    if (status == OwnerBookingRequestStatus.accepted && request != null) {
      final dateKey = (request.date?.trim().isNotEmpty == true)
          ? request.date!.trim()
          : DateFormat('yyyy-MM-dd').format(request.dateTime);
      final timeLabel = (request.time?.trim().isNotEmpty == true)
          ? _normalizeTimeString(request.time!)
          : DateFormat('h:mm a').format(request.dateTime);
      final scheduledAt =
          _parseDateTime(dateKey, timeLabel) ?? request.dateTime;
      final queueData = {
        'customerName': request.customerName,
        'service': request.services.join(', '),
        'barberName': request.barberName,
        'price': request.totalPrice,
        'status': 'waiting',
        'waitMinutes': request.durationMinutes,
        'slotLabel': timeLabel,
        'customerPhone': request.customerPhone,
        'date': dateKey,
        'time': timeLabel,
        'dateTime': Timestamp.fromDate(scheduledAt),
      };
      try {
        await _firestore
            .collection('salons')
            .doc(ownerId)
            .collection('queue')
            .doc(id)
            .set(queueData, SetOptions(merge: true));
      } catch (_) {
        // keep UI in sync even if queue write fails
      }
    }

    _requests = _requests.where((r) => r.id != id).toList();
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
