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
  final Map<String, OwnerBookingRequestStatus> _processingRequests = {};

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<OwnerBookingRequest> get requests => _requests;
  bool isProcessing(String requestId) =>
      _processingRequests.containsKey(requestId);
  OwnerBookingRequestStatus? processingDecisionFor(String requestId) =>
      _processingRequests[requestId];

  Future<void> load() async {
    _setLoading(true);
    _setError(null);
    final scope = await _resolveScope();
    if (scope == null) {
      _setLoading(false);
      return;
    }
    try {
      QuerySnapshot<Map<String, dynamic>> snap;
      final collection = _firestore
          .collection('salons')
          .doc(scope.salonId)
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
          .where((doc) => _canActorAccessRequest(doc.data(), scope))
          .map((doc) => _mapRequest(doc.id, doc.data()))
          .whereType<OwnerBookingRequest>()
          .toList();

      _requests.sort((a, b) => b.dateTime.compareTo(a.dateTime));
      if (scope.isOwner) {
        await _syncPendingRequests(scope.salonId, _requests.length);
      }
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
      barberId:
          (data['barberId'] as String?) ?? (data['barberUid'] as String?) ?? '',
      barberAvatar: (data['barberAvatar'] as String?) ??
          (data['barberPhotoUrl'] as String?) ??
          '',
      services: services,
      dateTime: dateTime,
      date: rawDate.isNotEmpty ? rawDate : null,
      time: rawTime.isNotEmpty ? rawTime : null,
      durationMinutes: _durationMinutes(data, services.length),
      totalPrice: (data['total'] as num?)?.toInt() ??
          (data['totalPrice'] as num?)?.toInt() ??
          0,
      tipAmount: (data['tipAmount'] as num?)?.toInt() ?? 0,
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
    // Statuses like waiting/serving/arrived are active queue items,
    // not booking requests.
    return status == 'pending' || status == 'upcoming' || status.isEmpty;
  }

  Future<bool> updateStatus(String id, OwnerBookingRequestStatus status) async {
    final scope = await _resolveScope();
    if (scope == null) {
      return false;
    }
    if (_processingRequests.containsKey(id)) return false;

    _error = null;
    _processingRequests[id] = status;
    notifyListeners();

    final statusToSave =
        status == OwnerBookingRequestStatus.accepted ? 'waiting' : 'rejected';
    OwnerBookingRequest? request;
    for (final r in _requests) {
      if (r.id == id) {
        request = r;
        break;
      }
    }
    if (request == null) {
      _setError('Booking request not found.');
      _processingRequests.remove(id);
      notifyListeners();
      return false;
    }
    if (!_isRequestAssignedToActor(request, scope)) {
      _setError('You can only decide requests assigned to you.');
      _processingRequests.remove(id);
      notifyListeners();
      return false;
    }

    try {
      await _firestore
          .collection('salons')
          .doc(scope.salonId)
          .collection('bookings')
          .doc(id)
          .set({'status': statusToSave}, SetOptions(merge: true));
    } catch (_) {
      _setError('Could not update status. Try again.');
      _processingRequests.remove(id);
      notifyListeners();
      return false;
    }

    if (status == OwnerBookingRequestStatus.accepted) {
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
        if (request.barberId.isNotEmpty) 'barberId': request.barberId,
        if (request.barberAvatar.isNotEmpty)
          'barberAvatar': request.barberAvatar,
        'price': request.totalPrice,
        'tipAmount': request.tipAmount,
        'status': 'waiting',
        'waitMinutes': request.durationMinutes,
        'slotLabel': timeLabel,
        'customerPhone': request.customerPhone,
        'date': dateKey,
        'time': timeLabel,
        'dateTime': Timestamp.fromDate(scheduledAt),
        if (request.customerUid.isNotEmpty) 'customerUid': request.customerUid,
        if (request.customerAvatar.isNotEmpty)
          'customerAvatar': request.customerAvatar,
      };
      try {
        await _firestore
            .collection('salons')
            .doc(scope.salonId)
            .collection('queue')
            .doc(id)
            .set(queueData, SetOptions(merge: true));
        if (scope.isOwner) {
          await _firestore.collection('salons_summary').doc(scope.salonId).set(
            {
              'waitingCount': FieldValue.increment(1),
              'updatedAt': FieldValue.serverTimestamp(),
            },
            SetOptions(merge: true),
          );
        }
      } catch (_) {
        // keep UI in sync even if queue write fails
      }
    }

    _requests = _requests.where((r) => r.id != id).toList();
    _processingRequests.remove(id);
    notifyListeners();
    if (scope.isOwner) {
      await _syncPendingRequests(scope.salonId, _requests.length);
    }
    return true;
  }

  Future<_BookingScope?> _resolveScope() async {
    final actorUid = _authProvider.currentUser?.uid;
    if (actorUid == null) {
      _setError('Please log in again.');
      return null;
    }

    try {
      final userDoc = await _firestore.collection('users').doc(actorUid).get();
      final userData = userDoc.data() ?? const <String, dynamic>{};
      final role = ((userData['role'] as String?) ?? '').trim().toLowerCase();
      final actorName = ((userData['name'] as String?) ?? '').trim();

      if (role == 'owner') {
        return _BookingScope(
          salonId: actorUid,
          actorUid: actorUid,
          actorName: actorName,
          role: _BookingActorRole.owner,
        );
      }

      final ownerId = ((userData['ownerId'] as String?) ?? '').trim();
      if (role == 'barber' || ownerId.isNotEmpty) {
        if (ownerId.isEmpty) {
          _setError('Salon owner not linked to this barber account.');
          return null;
        }
        return _BookingScope(
          salonId: ownerId,
          actorUid: actorUid,
          actorName: actorName,
          role: _BookingActorRole.barber,
        );
      }

      _setError('You do not have permission to review booking requests.');
      return null;
    } catch (_) {
      _setError('Could not verify account access. Try again.');
      return null;
    }
  }

  bool _canActorAccessRequest(
    Map<String, dynamic> data,
    _BookingScope scope,
  ) {
    if (scope.isOwner) return true;
    final barberId =
        ((data['barberId'] as String?) ?? (data['barberUid'] as String?) ?? '')
            .trim();
    final barberName =
        ((data['barberName'] as String?) ?? (data['barber'] as String?) ?? '')
            .trim();
    return _matchesAssignedBarber(
      barberId: barberId,
      barberName: barberName,
      actorUid: scope.actorUid,
      actorName: scope.actorName,
    );
  }

  bool _isRequestAssignedToActor(
    OwnerBookingRequest request,
    _BookingScope scope,
  ) {
    if (scope.isOwner) return true;
    return _matchesAssignedBarber(
      barberId: request.barberId,
      barberName: request.barberName,
      actorUid: scope.actorUid,
      actorName: scope.actorName,
    );
  }

  bool _matchesAssignedBarber({
    required String barberId,
    required String barberName,
    required String actorUid,
    required String actorName,
  }) {
    final normalizedBarberId = barberId.trim().toLowerCase();
    final normalizedActorUid = actorUid.trim().toLowerCase();
    if (normalizedBarberId.isNotEmpty &&
        normalizedBarberId == normalizedActorUid) {
      return true;
    }

    final normalizedBarberName = barberName.trim().toLowerCase();
    final normalizedActorName = actorName.trim().toLowerCase();
    if (normalizedBarberName.isEmpty || normalizedActorName.isEmpty) {
      return false;
    }
    return normalizedBarberName == normalizedActorName;
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  Future<void> _syncPendingRequests(String ownerId, int count) async {
    try {
      await _firestore.collection('salons_summary').doc(ownerId).set(
        {
          'pendingRequests': count < 0 ? 0 : count,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    } catch (_) {
      // ignore summary sync failures
    }
  }
}

enum _BookingActorRole { owner, barber }

class _BookingScope {
  const _BookingScope({
    required this.salonId,
    required this.actorUid,
    required this.actorName,
    required this.role,
  });

  final String salonId;
  final String actorUid;
  final String actorName;
  final _BookingActorRole role;

  bool get isOwner => role == _BookingActorRole.owner;
}
