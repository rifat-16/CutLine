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
        _barbers = snap.docs.map((doc) => _mapBarber(doc.data(), ownerId)).toList();
      }
      await _hydrateBarberAvatars(ownerId);
      await _updateBarberAvailability(ownerId);
      await _calculateServedToday(ownerId);
      await _updateNextClient(ownerId);
    } catch (e) {
      _setError('Failed to load barbers.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> addBarber(BarberInput input) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    final barber = OwnerBarber(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
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
      uid: DateTime.now().millisecondsSinceEpoch.toString(),
      isAvailable: true,
    );
    _barbers.add(barber);
    notifyListeners();
    try {
      await _firestore.collection('salons').doc(ownerId).set({
        'barbers': FieldValue.arrayUnion([
          {
            'id': barber.id,
            'ownerId': ownerId,
            'name': barber.name,
            'specialization': barber.specialization,
            'email': barber.email,
            'phone': barber.phone,
            'status': barber.status.name,
            'rating': barber.rating,
            'servedToday': barber.servedToday,
            'nextClient': barber.nextClient,
          }
        ])
      }, SetOptions(merge: true));
    } catch (_) {
      // ignore errors for now
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
    final barbersNeedingAvatars = _barbers
        .where((b) => b.photoUrl.isEmpty && b.uid.isNotEmpty)
        .toList();
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
              _barbers[index] = OwnerBarber(
                id: _barbers[index].id,
                name: _barbers[index].name,
                email: _barbers[index].email,
                phone: _barbers[index].phone,
                password: _barbers[index].password,
                specialization: _barbers[index].specialization,
                rating: _barbers[index].rating,
                servedToday: _barbers[index].servedToday,
                status: _barbers[index].status,
                nextClient: _barbers[index].nextClient,
                photoUrl: avatar,
                uid: _barbers[index].uid,
                isAvailable: _barbers[index].isAvailable,
              );
            }
          }
        }
      } catch (_) {
        // Ignore errors in avatar fetching
      }
    }
    notifyListeners();
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
          _barbers[i] = OwnerBarber(
            id: barber.id,
            name: barber.name,
            email: barber.email,
            phone: barber.phone,
            password: barber.password,
            specialization: barber.specialization,
            rating: barber.rating,
            servedToday: barber.servedToday,
            status: isAvailable ? barber.status : OwnerBarberStatus.offDuty,
            nextClient: barber.nextClient,
            photoUrl: barber.photoUrl,
            uid: barber.uid,
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
    if (barberLower.contains(targetLower) || targetLower.contains(barberLower)) {
      return true;
    }
    return false;
  }

  Future<void> _calculateServedToday(String ownerId) async {
    final today = DateTime.now();
    final todayStr = "${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}";
    final processedBookingIds = <String>{};
    
    // Reset servedToday counts first
    for (int i = 0; i < _barbers.length; i++) {
      _barbers[i] = OwnerBarber(
        id: _barbers[i].id,
        name: _barbers[i].name,
        email: _barbers[i].email,
        phone: _barbers[i].phone,
        password: _barbers[i].password,
        specialization: _barbers[i].specialization,
        rating: _barbers[i].rating,
        servedToday: 0,
        status: _barbers[i].status,
        nextClient: _barbers[i].nextClient,
        photoUrl: _barbers[i].photoUrl,
        uid: _barbers[i].uid,
        isAvailable: _barbers[i].isAvailable,
      );
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
          final barberId = (data['barberId'] as String?) ?? 
                          (data['barberUid'] as String?);
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
              _barbers[i] = OwnerBarber(
                id: barber.id,
                name: barber.name,
                email: barber.email,
                phone: barber.phone,
                password: barber.password,
                specialization: barber.specialization,
                rating: barber.rating,
                servedToday: _barbers[i].servedToday + 1,
                status: barber.status,
                nextClient: barber.nextClient,
                photoUrl: barber.photoUrl,
                uid: barber.uid,
                isAvailable: barber.isAvailable,
              );
              break;
            }
            // Fallback: Match by name (only if UID not found)
            else if (finalBarberId == null && 
                     barberName.isNotEmpty &&
                     _matchesBarberName(barberName, barber.name)) {
              _barbers[i] = OwnerBarber(
                id: barber.id,
                name: barber.name,
                email: barber.email,
                phone: barber.phone,
                password: barber.password,
                specialization: barber.specialization,
                rating: barber.rating,
                servedToday: _barbers[i].servedToday + 1,
                status: barber.status,
                nextClient: barber.nextClient,
                photoUrl: barber.photoUrl,
                uid: barber.uid,
                isAvailable: barber.isAvailable,
              );
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
            final barberId = (data['barberId'] as String?) ?? 
                            (data['barberUid'] as String?);
            final barberName = (data['barberName'] as String?) ?? '';

            for (int i = 0; i < _barbers.length; i++) {
              final barber = _barbers[i];
              // Primary: Match by UID (most reliable)
              if (barberId != null && barberId == barber.uid) {
                _barbers[i] = OwnerBarber(
                  id: barber.id,
                  name: barber.name,
                  email: barber.email,
                  phone: barber.phone,
                  password: barber.password,
                  specialization: barber.specialization,
                  rating: barber.rating,
                  servedToday: _barbers[i].servedToday + 1,
                  status: barber.status,
                  nextClient: barber.nextClient,
                  photoUrl: barber.photoUrl,
                  uid: barber.uid,
                  isAvailable: barber.isAvailable,
                );
                break;
              }
              // Fallback: Match by name (only if UID not found)
              else if (barberId == null && 
                       barberName.isNotEmpty &&
                       _matchesBarberName(barberName, barber.name)) {
                _barbers[i] = OwnerBarber(
                  id: barber.id,
                  name: barber.name,
                  email: barber.email,
                  phone: barber.phone,
                  password: barber.password,
                  specialization: barber.specialization,
                  rating: barber.rating,
                  servedToday: _barbers[i].servedToday + 1,
                  status: barber.status,
                  nextClient: barber.nextClient,
                  photoUrl: barber.photoUrl,
                  uid: barber.uid,
                  isAvailable: barber.isAvailable,
                );
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
        final barberId = (data['barberId'] as String?) ?? 
                        (data['barberUid'] as String?);
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
          _barbers[i] = OwnerBarber(
            id: barber.id,
            name: barber.name,
            email: barber.email,
            phone: barber.phone,
            password: barber.password,
            specialization: barber.specialization,
            rating: barber.rating,
            servedToday: barber.servedToday,
            status: barber.status,
            nextClient: nextClient,
            photoUrl: barber.photoUrl,
            uid: barber.uid,
            isAvailable: barber.isAvailable,
          );
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
