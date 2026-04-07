import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/salon_setup_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class BarbersProvider extends ChangeNotifier {
  BarbersProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  List<OwnerBarber> _barbers = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<OwnerBarber> get barbers => _barbers;

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      // Prefer barbers stored on the salon doc as an array.
      final salonDoc = await _firestore.collection('salons').doc(ownerId).get();
      final data = salonDoc.data() ?? {};
      final barbersField = data['barbers'];
      if (barbersField is List) {
        _barbers = barbersField
            .map((e) => _mapBarber(e as Map<String, dynamic>? ?? {}, ownerId))
            .toList();
      } else {
        final snap = await _firestore
            .collection('barbers')
            .where('ownerId', isEqualTo: ownerId)
            .get();
        _barbers =
            snap.docs.map((doc) => _mapBarber(doc.data(), ownerId)).toList();
      }
      await _hydrateBarberAvatars(ownerId);
      await _updateBarberAvailability(ownerId);
      await _hydrateCredentialState(ownerId);
      await _calculateServedToday(ownerId);
      await _updateNextClient(ownerId);
    } catch (e) {
      _setError('Failed to load barbers.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addBarber(BarberInput input, {String? barberUid}) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    final previousBarbers = List<OwnerBarber>.from(_barbers);
    final resolvedUid = (barberUid ?? '').trim().isNotEmpty
        ? barberUid!.trim()
        : DateTime.now().millisecondsSinceEpoch.toString();
    final barber = OwnerBarber(
      id: resolvedUid,
      name: input.name,
      specialization:
          input.specialization.isNotEmpty ? input.specialization : 'Haircut',
      email: input.email,
      phone: input.phone,
      password: input.password,
      rating: 4.5,
      servedToday: 0,
      status: OwnerBarberStatus.onFloor,
      nextClient: null,
      photoUrl: '',
      uid: resolvedUid,
      isAvailable: true,
      mustChangePassword: true,
      passwordVisibleToOwner: true,
    );
    final existingIndex =
        _barbers.indexWhere((b) => b.uid == resolvedUid || b.id == resolvedUid);
    if (existingIndex >= 0) {
      _barbers[existingIndex] = barber;
    } else {
      _barbers.add(barber);
    }
    notifyListeners();
    try {
      final arrayEntry = {
        'id': barber.id,
        'uid': resolvedUid,
        'ownerId': ownerId,
        'name': barber.name,
        'specialization': barber.specialization,
        'email': barber.email,
        'phone': barber.phone,
        'status': barber.status.name,
        'rating': barber.rating,
        'servedToday': barber.servedToday,
        'nextClient': barber.nextClient,
        'isAvailable': barber.isAvailable,
        'available': barber.isAvailable,
      };
      final subcollectionEntry = {
        'uid': resolvedUid,
        'ownerId': ownerId,
        'name': barber.name,
        'specialization': barber.specialization,
        'email': barber.email,
        'phone': barber.phone,
        'status': barber.status.name,
        'rating': barber.rating,
        'servedToday': barber.servedToday,
        'nextClient': barber.nextClient,
        'isAvailable': barber.isAvailable,
        'available': barber.isAvailable,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      final privateCredentialEntry = {
        'uid': resolvedUid,
        'ownerId': ownerId,
        'name': barber.name,
        'email': barber.email,
        'temporaryPassword': input.password,
        'passwordVisibleToOwner': true,
        'mustChangePassword': true,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      final batch = _firestore.batch();
      final salonRef = _firestore.collection('salons').doc(ownerId);
      batch.set(
        salonRef,
        {
          'barbers': FieldValue.arrayUnion([arrayEntry]),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(
        salonRef.collection('barbers').doc(resolvedUid),
        subcollectionEntry,
        SetOptions(merge: true),
      );
      batch.set(
        salonRef.collection('barber_credentials').doc(resolvedUid),
        privateCredentialEntry,
        SetOptions(merge: true),
      );
      await batch.commit();
      _setError(null);
    } catch (e, st) {
      _barbers = previousBarbers;
      notifyListeners();
      debugPrint('addBarber commit failed: $e');
      debugPrintStack(stackTrace: st);
      _setError('Failed to save barber. Please refresh and try again.');
    }
  }

  OwnerBarber _mapBarber(Map<String, dynamic> data, String ownerId) {
    final barberId = (data['id'] as String?) ??
        (data['uid'] as String?) ??
        DateTime.now().millisecondsSinceEpoch.toString();
    final isAvailable = (data['isAvailable'] as bool?) ?? true;
    return OwnerBarber(
      id: barberId,
      name: (data['name'] as String?) ?? 'Barber',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      password: '',
      specialization: (data['specialization'] as String?) ?? 'Haircut',
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      servedToday: (data['servedToday'] as num?)?.toInt() ?? 0,
      status: isAvailable
          ? _statusFromString((data['status'] as String?) ?? 'onFloor')
          : OwnerBarberStatus.offDuty,
      nextClient: data['nextClient'] as String?,
      photoUrl: (data['photoUrl'] as String?) ?? '',
      uid: barberId,
      isAvailable: isAvailable,
      mustChangePassword: data['mustChangePassword'] == true,
    );
  }

  OwnerBarberStatus _statusFromString(String status) {
    switch (status) {
      case 'onBreak':
        return OwnerBarberStatus.onBreak;
      case 'offDuty':
        return OwnerBarberStatus.offDuty;
      default:
        return OwnerBarberStatus.onFloor;
    }
  }

  Future<void> _hydrateBarberAvatars(String ownerId) async {
    final barbersNeedingAvatars =
        _barbers.where((b) => b.photoUrl.isEmpty && b.uid.isNotEmpty).toList();
    if (barbersNeedingAvatars.isEmpty) return;

    final batchSize = 10;
    for (int i = 0; i < barbersNeedingAvatars.length; i += batchSize) {
      final batch = barbersNeedingAvatars.skip(i).take(batchSize).toList();
      final uids = batch.map((b) => b.uid).toList();

      try {
        final snap = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: uids)
            .get();

        final avatarMap = <String, String>{};
        for (final doc in snap.docs) {
          final data = doc.data();
          final photoUrl = (data['photoUrl'] as String?) ?? '';
          if (photoUrl.isNotEmpty) {
            avatarMap[doc.id] = photoUrl;
          }
        }

        for (int j = 0; j < batch.length; j++) {
          final barber = batch[j];
          final avatar = avatarMap[barber.uid];
          if (avatar != null && avatar.isNotEmpty) {
            final index = _barbers.indexWhere((b) => b.id == barber.id);
            if (index != -1) {
              _barbers[index] = _barbers[index].copyWith(photoUrl: avatar);
            }
          }
        }
      } catch (_) {
        // Ignore errors in avatar fetching
      }
    }
    notifyListeners();
  }

  Future<void> _hydrateCredentialState(String ownerId) async {
    try {
      final snap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('barber_credentials')
          .get();

      if (snap.docs.isEmpty) return;

      final credentialsById = <String, Map<String, dynamic>>{
        for (final doc in snap.docs) doc.id: doc.data(),
      };

      var didChange = false;
      for (int i = 0; i < _barbers.length; i++) {
        final barber = _barbers[i];
        final credentials =
            credentialsById[barber.uid] ?? credentialsById[barber.id];
        if (credentials == null) continue;

        final temporaryPassword =
            (credentials['temporaryPassword'] as String?)?.trim() ?? '';
        final canShowPassword = credentials['passwordVisibleToOwner'] == true &&
            temporaryPassword.isNotEmpty;
        final changedAt = _asDateTime(credentials['passwordChangedAt']);

        _barbers[i] = barber.copyWith(
          email: barber.email.isNotEmpty
              ? barber.email
              : ((credentials['email'] as String?) ?? ''),
          password: canShowPassword ? temporaryPassword : '',
          mustChangePassword: credentials['mustChangePassword'] == true,
          passwordVisibleToOwner: canShowPassword,
          passwordChangedAt: changedAt,
          clearPasswordChangedAt:
              changedAt == null && credentials.containsKey('passwordChangedAt'),
        );
        didChange = true;
      }

      if (didChange) {
        notifyListeners();
      }
    } catch (_) {
      // Ignore credential hydration errors
    }
  }

  DateTime? _asDateTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  Future<void> _updateBarberAvailability(String ownerId) async {
    try {
      final barbersSnap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('barbers')
          .get();

      final availabilityMap = <String, bool>{};
      for (final doc in barbersSnap.docs) {
        final data = doc.data();
        final barberId = doc.id;
        final isAvailable = (data['isAvailable'] as bool?) ?? true;
        availabilityMap[barberId] = isAvailable;
      }

      for (int i = 0; i < _barbers.length; i++) {
        final barber = _barbers[i];
        final isAvailable = availabilityMap[barber.uid] ?? barber.isAvailable;
        if (isAvailable != barber.isAvailable) {
          _barbers[i] = barber.copyWith(
            status: isAvailable ? barber.status : OwnerBarberStatus.offDuty,
            isAvailable: isAvailable,
          );
        }
      }
      notifyListeners();
    } catch (_) {
      // Ignore errors
    }
  }

  bool _matchesBarberName(String barberName, String targetName) {
    if (barberName.isEmpty || targetName.isEmpty) return false;
    final barberLower = barberName.toLowerCase().trim();
    final targetLower = targetName.toLowerCase().trim();
    // Exact match
    if (barberLower == targetLower) return true;
    // Partial match - check if one contains the other
    if (barberLower.contains(targetLower) ||
        targetLower.contains(barberLower)) {
      return true;
    }
    return false;
  }

  Future<void> _calculateServedToday(String ownerId) async {
    final today = DateTime.now();
    final todayStr =
        "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final processedBookingIds = <String>{};

    // Reset servedToday counts first
    for (int i = 0; i < _barbers.length; i++) {
      _barbers[i] = _barbers[i].copyWith(servedToday: 0);
    }

    // Check bookings collection
    try {
      final bookingsSnap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('bookings')
          .where('date', isEqualTo: todayStr)
          .get();

      for (final doc in bookingsSnap.docs) {
        final data = doc.data();
        final rootStatus = (data['status'] as String?) ?? '';

        // Check root level status
        bool isCompleted = rootStatus == 'completed' || rootStatus == 'done';

        // Also check services array for completed status
        if (!isCompleted) {
          final services = data['services'] as List?;
          if (services != null) {
            for (final service in services) {
              if (service is Map) {
                final serviceStatus = (service['status'] as String?) ?? '';
                if (serviceStatus == 'completed' || serviceStatus == 'done') {
                  isCompleted = true;
                  break;
                }
              }
            }
          }
        }

        if (isCompleted) {
          processedBookingIds.add(doc.id);
          // First try to get barberId from root level
          final barberId =
              (data['barberId'] as String?) ?? (data['barberUid'] as String?);
          // Also check services array for barberId
          String? serviceBarberId;
          final services = data['services'] as List?;
          if (services != null && services.isNotEmpty) {
            final firstService = services[0];
            if (firstService is Map) {
              serviceBarberId = (firstService['barberId'] as String?) ??
                  (firstService['barberUid'] as String?);
            }
          }

          final finalBarberId = barberId ?? serviceBarberId;
          final barberName = (data['barberName'] as String?) ?? '';

          for (int i = 0; i < _barbers.length; i++) {
            final barber = _barbers[i];
            // Primary: Match by UID (most reliable)
            if (finalBarberId != null && finalBarberId == barber.uid) {
              _barbers[i] =
                  barber.copyWith(servedToday: _barbers[i].servedToday + 1);
              break;
            }
            // Fallback: Match by name (only if UID not found)
            else if (finalBarberId == null &&
                barberName.isNotEmpty &&
                _matchesBarberName(barberName, barber.name)) {
              _barbers[i] =
                  barber.copyWith(servedToday: _barbers[i].servedToday + 1);
              break;
            }
          }
        }
      }
    } catch (_) {
      // Ignore errors
    }

    // Check queue collection (skip if already counted in bookings)
    try {
      final queueSnap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('queue')
          .get();

      for (final doc in queueSnap.docs) {
        if (processedBookingIds.contains(doc.id)) continue;

        final data = doc.data();
        final status = (data['status'] as String?) ?? '';
        if (status == 'completed' || status == 'done') {
          final completedAt = data['completedAt'];
          final updatedAt = data['updatedAt'];
          final date = data['date'] as String?;

          bool isToday = false;
          if (completedAt != null && completedAt is Timestamp) {
            final completedDate = completedAt.toDate();
            isToday = completedDate.year == today.year &&
                completedDate.month == today.month &&
                completedDate.day == today.day;
          } else if (date != null && date == todayStr) {
            isToday = true;
          } else if (updatedAt != null && updatedAt is Timestamp) {
            final updatedDate = updatedAt.toDate();
            isToday = updatedDate.year == today.year &&
                updatedDate.month == today.month &&
                updatedDate.day == today.day;
          }

          if (isToday) {
            final barberId =
                (data['barberId'] as String?) ?? (data['barberUid'] as String?);
            final barberName = (data['barberName'] as String?) ?? '';

            for (int i = 0; i < _barbers.length; i++) {
              final barber = _barbers[i];
              // Primary: Match by UID (most reliable)
              if (barberId != null && barberId == barber.uid) {
                _barbers[i] =
                    barber.copyWith(servedToday: _barbers[i].servedToday + 1);
                break;
              }
              // Fallback: Match by name (only if UID not found)
              else if (barberId == null &&
                  barberName.isNotEmpty &&
                  _matchesBarberName(barberName, barber.name)) {
                _barbers[i] =
                    barber.copyWith(servedToday: _barbers[i].servedToday + 1);
                break;
              }
            }
          }
        }
      }
    } catch (_) {
      // Ignore errors
    }
    notifyListeners();
  }

  Future<void> _updateNextClient(String ownerId) async {
    try {
      final queueSnap = await _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('queue')
          .where('status', isEqualTo: 'waiting')
          .get();

      final waitingCountMap = <String, int>{};
      for (final doc in queueSnap.docs) {
        final data = doc.data();
        final barberId =
            (data['barberId'] as String?) ?? (data['barberUid'] as String?);
        final barberName = (data['barberName'] as String?) ?? '';

        for (final barber in _barbers) {
          // Primary: Match by UID (most reliable)
          if (barberId != null && barberId == barber.uid) {
            waitingCountMap[barber.id] = (waitingCountMap[barber.id] ?? 0) + 1;
            break;
          }
          // Fallback: Match by name (only if UID not found)
          else if (barberId == null &&
              barberName.isNotEmpty &&
              _matchesBarberName(barberName, barber.name)) {
            waitingCountMap[barber.id] = (waitingCountMap[barber.id] ?? 0) + 1;
            break;
          }
        }
      }

      for (int i = 0; i < _barbers.length; i++) {
        final barber = _barbers[i];
        final waitingCount = waitingCountMap[barber.id] ?? 0;
        String? nextClient;
        if (waitingCount == 0) {
          nextClient = null;
        } else if (waitingCount == 1) {
          nextClient = '1 waiting';
        } else {
          nextClient = '$waitingCount waiting';
        }

        if (nextClient != barber.nextClient) {
          _barbers[i] = barber.copyWith(nextClient: nextClient);
        }
      }
      notifyListeners();
    } catch (_) {
      // Ignore errors
    }
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
