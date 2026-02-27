import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'dart:async';

import 'package:cutline/features/owner/services/owner_queue_service.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/shared/models/salon_verification_status.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class OwnerHomeProvider extends ChangeNotifier {
  OwnerHomeProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
    OwnerQueueService? queueService,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _queueService =
            queueService ?? OwnerQueueService(firestore: firestore) {
    _queueSubscription = _queueService.onChanged.listen((_) {
      _refreshQueue();
    });
  }

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  final OwnerQueueService _queueService;
  StreamSubscription<void>? _queueSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _bookingRequestsSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>?
      _queueLiveSubscription;

  bool _isLoading = false;
  String? _error;
  String? _salonName;
  String? _photoUrl;
  SalonVerificationStatus _verificationStatus =
      SalonVerificationStatus.verified;
  String? _reviewNote;
  bool _hasLoadedSalon = false;
  bool _salonDocExists = false;
  List<OwnerQueueItem> _queueItems = [];
  int _pendingRequests = 0;
  bool _isOpen = false;
  bool _isUpdatingStatus = false;
  int _lastSyncedPendingRequests = -1;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get salonName => _salonName;
  String? get photoUrl => _photoUrl;
  SalonVerificationStatus get verificationStatus => _verificationStatus;
  String? get reviewNote => _reviewNote;
  bool get hasLoadedSalon => _hasLoadedSalon;
  bool get salonDocExists => _salonDocExists;
  bool get isVerified =>
      _verificationStatus == SalonVerificationStatus.verified;
  List<OwnerQueueItem> get queueItems => _queueItems;
  int get pendingRequests => _pendingRequests;
  bool get isOpen => _isOpen;
  bool get isUpdatingStatus => _isUpdatingStatus;

  Future<void> fetchAll() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }

    // Verify authentication and user document
    try {
      final userDoc = await _firestore.collection('users').doc(ownerId).get();
      if (!userDoc.exists) {
        _setError('User profile not found. Please sign up again.');
        _setLoading(false);
        return;
      }
      final userData = userDoc.data();
      final userRole = userData?['role'] as String?;
      if (userRole != 'owner') {
        _setError('You do not have owner permissions.');
        _setLoading(false);
        return;
      }
    } catch (e, stackTrace) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        _setError(
            'Permission denied. Please check Firestore rules are deployed.');
        _setLoading(false);
        return;
      }
      // Continue even if verification fails - might be network issue
    }

    _setLoading(true);
    _setError(null);
    try {
      // Load salon first (this might not exist for new owners)
      await _loadSalon(ownerId);

      // Load queue and booking requests (these can fail gracefully)
      try {
        await _loadQueue(ownerId);
      } catch (e, stackTrace) {
        // Queue might be empty, that's okay
        _queueItems = [];
        if (e is FirebaseException && e.code == 'permission-denied') {}
      }

      try {
        await _loadBookingRequests(ownerId);
      } catch (e, stackTrace) {
        // Booking requests might be empty, that's okay
        _pendingRequests = 0;
        if (e is FirebaseException && e.code == 'permission-denied') {}
      }

      // Set up listeners (these can fail silently)
      try {
        _listenToBookingRequests(ownerId);
      } catch (e) {
        // Listener setup failed, but continue
      }

      try {
        _listenToQueue(ownerId);
      } catch (e) {
        // Listener setup failed, but continue
      }

      // Only show error if salon doesn't exist and no data loaded
      if (_salonName == null && _queueItems.isEmpty && _pendingRequests == 0) {
        // This is likely a new owner who hasn't set up salon yet
        // Don't show error, just show empty state
        _setError(null);
      }
    } catch (e, stackTrace) {
      // Only show error for unexpected failures

      // Provide specific error messages
      String errorMessage = 'Failed to load data. Pull to refresh.';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          errorMessage =
              'Permission denied. Please check Firestore rules are deployed in Firebase Console.';
        } else if (e.code == 'unavailable') {
          errorMessage = 'Network error. Check your connection.';
        } else if (e.code == 'failed-precondition') {
          errorMessage =
              'Firestore index required. Please check Firebase Console.';
        } else {
          errorMessage = 'Firebase error: ${e.message ?? e.code}';
        }
      }

      // Don't set error for expected cases (new owner, empty data)
      if (_salonName != null ||
          _queueItems.isNotEmpty ||
          _pendingRequests > 0) {
        // Some data loaded, don't show error
        _setError(null);
      } else {
        _setError(errorMessage);
      }
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadSalon(String ownerId) async {
    try {
      final doc = await _firestore.collection('salons').doc(ownerId).get();
      _salonDocExists = doc.exists;
      if (doc.exists) {
        final data = doc.data() ?? {};
        _salonName = data['name'] as String?;
        _isOpen = (data['isOpen'] as bool?) ?? false;
        _photoUrl = (data['photoUrl'] as String?)?.trim();
        _verificationStatus =
            salonVerificationStatusFromFirestore(data['verificationStatus']);
        _reviewNote = (data['reviewNote'] as String?)?.trim();
        if (_photoUrl != null && _photoUrl!.isEmpty) {
          _photoUrl = null;
        }
      } else {}
      // If salon doesn't exist, that's okay - owner might not have set up yet
    } catch (e, stackTrace) {
      // Re-throw to be caught by parent try-catch if it's a permission error
      if (e is FirebaseException && e.code == 'permission-denied') {
        rethrow;
      }
      // Silently fail - salon might not exist yet
    } finally {
      final shouldNotify = !_hasLoadedSalon;
      _hasLoadedSalon = true;
      if (shouldNotify) notifyListeners();
    }
  }

  Future<void> _loadQueue(String ownerId) async {
    try {
      _queueItems = await _queueService.loadQueue(ownerId);
      notifyListeners();
    } catch (e, stackTrace) {
      // If queue fails to load, set empty list (might be no queue yet)
      _queueItems = [];
      notifyListeners();
      // Re-throw permission errors
      if (e is FirebaseException && e.code == 'permission-denied') {
        rethrow;
      }
    }
  }

  Future<void> _loadBookingRequests(String ownerId) async {
    final collection =
        _firestore.collection('salons').doc(ownerId).collection('bookings');
    int? summaryPending;
    try {
      try {
        final summarySnap =
            await _firestore.collection('salons_summary').doc(ownerId).get();
        final summaryData = summarySnap.data();
        final pending = (summaryData?['pendingRequests'] as num?)?.toInt();
        if (pending != null) {
          summaryPending = pending < 0 ? 0 : pending;
          _pendingRequests = summaryPending;
          notifyListeners();
        }
      } catch (_) {
        // summary unavailable; fall back to bookings query
      }

      _pendingRequests = await _countPendingRequests(collection);
      await _syncPendingRequests(ownerId, _pendingRequests);
    } catch (e, stackTrace) {
      _pendingRequests = summaryPending ?? 0;
      // Re-throw permission errors
      if (summaryPending == null &&
          e is FirebaseException &&
          e.code == 'permission-denied') {
        rethrow;
      }
    }
  }

  void _listenToBookingRequests(String ownerId) {
    _bookingRequestsSubscription?.cancel();
    final collection =
        _firestore.collection('salons').doc(ownerId).collection('bookings');

    void applyCount(int count) {
      final normalized = count < 0 ? 0 : count;
      if (_pendingRequests != normalized) {
        _pendingRequests = normalized;
        notifyListeners();
      }
      _syncPendingRequests(ownerId, normalized);
    }

    void startFallbackListener() {
      _bookingRequestsSubscription?.cancel();
      _bookingRequestsSubscription = collection.snapshots().listen((snapshot) {
        applyCount(_countPendingFromDocs(snapshot.docs));
      }, onError: (e) {});
    }

    try {
      _bookingRequestsSubscription = collection
          .where('status', whereIn: ['pending', 'upcoming'])
          .snapshots()
          .listen((snapshot) {
            applyCount(snapshot.size);
          }, onError: (e) {
            startFallbackListener();
          });
    } catch (e) {
      startFallbackListener();
    }
  }

  Future<int> _countPendingRequests(
      CollectionReference<Map<String, dynamic>> collection) async {
    try {
      final snap =
          await collection.where('status', whereIn: ['pending', 'upcoming']).get();
      return snap.size;
    } catch (_) {
      final snap = await collection.get();
      return _countPendingFromDocs(snap.docs);
    }
  }

  int _countPendingFromDocs(
      Iterable<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    return docs.where((doc) {
      final rawStatus = doc.data()['status'];
      final status =
          rawStatus is String ? rawStatus.trim().toLowerCase() : '';
      return status == 'pending' || status == 'upcoming' || status.isEmpty;
    }).length;
  }

  Future<void> _syncPendingRequests(String ownerId, int count) async {
    if (count == _lastSyncedPendingRequests) return;
    _lastSyncedPendingRequests = count;
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

  void _listenToQueue(String ownerId) {
    _queueLiveSubscription?.cancel();
    try {
      // Listen only to active queue items for this salon
      _queueLiveSubscription = _firestore
          .collection('salons')
          .doc(ownerId)
          .collection('queue')
          .where('status', whereIn: ['waiting', 'serving'])
          .snapshots()
          .listen((_) {
            _refreshQueue();
          }, onError: (e) {});
    } catch (e) {}
  }

  Future<void> setSalonOpen(bool value) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    final previous = _isOpen;
    _isOpen = value;
    _isUpdatingStatus = true;
    _setError(null);
    notifyListeners();
    try {
      final batch = _firestore.batch();
      batch.set(
        _firestore.collection('salons').doc(ownerId),
        {'isOpen': value},
        SetOptions(merge: true),
      );
      batch.set(
        _firestore.collection('salons_summary').doc(ownerId),
        {'isOpen': value, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
      await batch.commit();
    } catch (_) {
      _isOpen = previous;
      _setError('Could not update status. Try again.');
    } finally {
      _isUpdatingStatus = false;
      notifyListeners();
    }
  }

  Future<void> updateQueueStatus(String id, OwnerQueueStatus status) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    var didUpdate = true;
    try {
      await _queueService.updateStatus(
          ownerId: ownerId, id: id, status: status);
    } catch (_) {
      didUpdate = false;
    }
    if (!didUpdate) {
      _setError('Could not update status. Try again.');
      return;
    }
    final index = _queueItems.indexWhere((item) => item.id == id);
    if (index != -1) {
      _queueItems[index] = _queueItems[index].copyWith(status: status);
      notifyListeners();
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

  Future<void> _refreshQueue() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      return;
    }
    try {
      _queueItems = await _queueService.loadQueue(ownerId);
      // Notify listeners immediately, then again after avatars load
      notifyListeners();
      // Load avatars asynchronously and notify again when done
      // Note: loadQueue already calls _hydrateCustomerAvatars internally,
      // but we notify again to ensure UI updates after async avatar loading
      Future.delayed(const Duration(milliseconds: 500), () {
        notifyListeners();
      });
    } catch (e) {
      // silent fail
    }
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    _bookingRequestsSubscription?.cancel();
    _queueLiveSubscription?.cancel();
    super.dispose();
  }
}
