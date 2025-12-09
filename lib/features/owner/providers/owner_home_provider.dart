import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'dart:async';

import 'package:cutline/features/owner/services/owner_queue_service.dart';
import 'package:cutline/features/owner/utils/constants.dart';
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
  List<OwnerQueueItem> _queueItems = [];
  int _pendingRequests = 0;
  bool _isOpen = true;
  bool _isUpdatingStatus = false;

  bool get isLoading => _isLoading;
  String? get error => _error;
  String? get salonName => _salonName;
  String? get photoUrl => _photoUrl;
  List<OwnerQueueItem> get queueItems => _queueItems;
  int get pendingRequests => _pendingRequests;
  bool get isOpen => _isOpen;
  bool get isUpdatingStatus => _isUpdatingStatus;

  Future<void> fetchAll() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      debugPrint('fetchAll: ownerId is null');
      _setError('Please log in again.');
      return;
    }
    
    // Verify authentication and user document
    try {
      final userDoc = await _firestore.collection('users').doc(ownerId).get();
      if (!userDoc.exists) {
        debugPrint('fetchAll: User document does not exist for ownerId: $ownerId');
        _setError('User profile not found. Please sign up again.');
        _setLoading(false);
        return;
      }
      final userData = userDoc.data();
      final userRole = userData?['role'] as String?;
      debugPrint('fetchAll: User role: $userRole');
      if (userRole != 'owner') {
        debugPrint('fetchAll: User role is not owner: $userRole');
        _setError('You do not have owner permissions.');
        _setLoading(false);
        return;
      }
    } catch (e, stackTrace) {
      debugPrint('fetchAll: Error verifying user document: $e');
      debugPrint('Stack trace: $stackTrace');
      if (e is FirebaseException && e.code == 'permission-denied') {
        _setError('Permission denied. Please check Firestore rules are deployed.');
        _setLoading(false);
        return;
      }
      // Continue even if verification fails - might be network issue
    }
    
    debugPrint('fetchAll: Starting for ownerId: $ownerId');
    _setLoading(true);
    _setError(null);
    try {
      // Load salon first (this might not exist for new owners)
      await _loadSalon(ownerId);
      
      // Load queue and booking requests (these can fail gracefully)
      try {
        await _loadQueue(ownerId);
        debugPrint('fetchAll: Queue loaded, ${_queueItems.length} items');
      } catch (e, stackTrace) {
        debugPrint('fetchAll: Error loading queue: $e');
        debugPrint('Stack trace: $stackTrace');
        // Queue might be empty, that's okay
        _queueItems = [];
        if (e is FirebaseException && e.code == 'permission-denied') {
          debugPrint('fetchAll: Permission denied for queue. Check Firestore rules.');
        }
      }
      
      try {
        await _loadBookingRequests(ownerId);
        debugPrint('fetchAll: Booking requests loaded: $_pendingRequests');
      } catch (e, stackTrace) {
        debugPrint('fetchAll: Error loading booking requests: $e');
        debugPrint('Stack trace: $stackTrace');
        // Booking requests might be empty, that's okay
        _pendingRequests = 0;
        if (e is FirebaseException && e.code == 'permission-denied') {
          debugPrint('fetchAll: Permission denied for bookings. Check Firestore rules.');
        }
      }
      
      // Set up listeners (these can fail silently)
      try {
        _listenToBookingRequests(ownerId);
        debugPrint('fetchAll: Booking requests listener set up');
      } catch (e) {
        debugPrint('fetchAll: Error setting up booking requests listener: $e');
        // Listener setup failed, but continue
      }
      
      try {
        _listenToQueue(ownerId);
        debugPrint('fetchAll: Queue listener set up');
      } catch (e) {
        debugPrint('fetchAll: Error setting up queue listener: $e');
        // Listener setup failed, but continue
      }
      
      debugPrint('fetchAll: Completed. salonName=$_salonName, queueItems=${_queueItems.length}, pendingRequests=$_pendingRequests');
      
      // Only show error if salon doesn't exist and no data loaded
      if (_salonName == null && _queueItems.isEmpty && _pendingRequests == 0) {
        // This is likely a new owner who hasn't set up salon yet
        // Don't show error, just show empty state
        _setError(null);
      }
    } catch (e, stackTrace) {
      // Only show error for unexpected failures
      debugPrint('Error in fetchAll: $e');
      debugPrint('Stack trace: $stackTrace');
      
      // Provide specific error messages
      String errorMessage = 'Failed to load data. Pull to refresh.';
      if (e is FirebaseException) {
        if (e.code == 'permission-denied') {
          errorMessage = 'Permission denied. Please check Firestore rules are deployed in Firebase Console.';
        } else if (e.code == 'unavailable') {
          errorMessage = 'Network error. Check your connection.';
        } else if (e.code == 'failed-precondition') {
          errorMessage = 'Firestore index required. Please check Firebase Console.';
        } else {
          errorMessage = 'Firebase error: ${e.message ?? e.code}';
        }
      }
      
      // Don't set error for expected cases (new owner, empty data)
      if (_salonName != null || _queueItems.isNotEmpty || _pendingRequests > 0) {
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
      debugPrint('_loadSalon: Attempting to read salons/$ownerId');
      final doc = await _firestore.collection('salons').doc(ownerId).get();
      debugPrint('_loadSalon: Document exists: ${doc.exists}');
      if (doc.exists) {
        final data = doc.data() ?? {};
        _salonName = data['name'] as String?;
        _isOpen = (data['isOpen'] as bool?) ?? _isOpen;
        _photoUrl = (data['photoUrl'] as String?)?.trim();
        if (_photoUrl != null && _photoUrl!.isEmpty) {
          _photoUrl = null;
        }
        debugPrint('Loaded salon: name=$_salonName, isOpen=$_isOpen, photoUrl=${_photoUrl != null ? "set" : "null"}');
      } else {
        debugPrint('Salon document does not exist for ownerId: $ownerId. Owner needs to create salon profile.');
      }
      // If salon doesn't exist, that's okay - owner might not have set up yet
    } catch (e, stackTrace) {
      debugPrint('Error loading salon for ownerId $ownerId: $e');
      debugPrint('Error code: ${e is FirebaseException ? e.code : "unknown"}');
      debugPrint('Error message: ${e is FirebaseException ? e.message : e.toString()}');
      debugPrint('Stack trace: $stackTrace');
      // Re-throw to be caught by parent try-catch if it's a permission error
      if (e is FirebaseException && e.code == 'permission-denied') {
        debugPrint('_loadSalon: PERMISSION DENIED - Check Firestore rules are deployed!');
        rethrow;
      }
      // Silently fail - salon might not exist yet
    }
  }

  Future<void> _loadQueue(String ownerId) async {
    try {
      debugPrint('_loadQueue: Attempting to load queue for ownerId: $ownerId');
      _queueItems = await _queueService.loadQueue(ownerId);
      debugPrint('_loadQueue: Loaded ${_queueItems.length} queue items');
      notifyListeners();
    } catch (e, stackTrace) {
      debugPrint('Error loading queue: $e');
      debugPrint('Error code: ${e is FirebaseException ? e.code : "unknown"}');
      debugPrint('Error message: ${e is FirebaseException ? e.message : e.toString()}');
      debugPrint('Stack trace: $stackTrace');
      // If queue fails to load, set empty list (might be no queue yet)
      _queueItems = [];
      notifyListeners();
      // Re-throw permission errors
      if (e is FirebaseException && e.code == 'permission-denied') {
        debugPrint('_loadQueue: PERMISSION DENIED - Check Firestore rules for salons/$ownerId/queue');
        rethrow;
      }
    }
  }

  Future<void> _loadBookingRequests(String ownerId) async {
    final collection = _firestore
        .collection('salons')
        .doc(ownerId)
        .collection('bookings');
    try {
      debugPrint('_loadBookingRequests: Attempting to load bookings for ownerId: $ownerId');
      QuerySnapshot<Map<String, dynamic>> snap;
      try {
        snap = await collection
            .where('status', whereIn: ['pending', 'upcoming'])
            .get();
        debugPrint('Loaded booking requests: ${snap.size} pending/upcoming');
      } catch (e, stackTrace) {
        debugPrint('Error loading booking requests with whereIn: $e');
        debugPrint('Error code: ${e is FirebaseException ? e.code : "unknown"}');
        debugPrint('Stack trace: $stackTrace');
        // Check if it's a missing index error
        if (e is FirebaseException && e.code == 'failed-precondition') {
          debugPrint('Missing Firestore index! Please create index for bookings.status in Firebase Console');
        } else if (e is FirebaseException && e.code == 'permission-denied') {
          debugPrint('_loadBookingRequests: PERMISSION DENIED - Check Firestore rules for salons/$ownerId/bookings');
        }
        try {
          snap = await collection.where('status', isEqualTo: 'upcoming').get();
          debugPrint('Loaded booking requests (fallback): ${snap.size} upcoming');
        } catch (e2, stackTrace2) {
          debugPrint('Error loading booking requests (fallback): $e2');
          debugPrint('Error code: ${e2 is FirebaseException ? e2.code : "unknown"}');
          debugPrint('Stack trace: $stackTrace2');
          snap = await collection.get();
          debugPrint('Loaded all booking requests: ${snap.size}');
        }
      }
      _pendingRequests = snap.size;
    } catch (e, stackTrace) {
      debugPrint('Error in _loadBookingRequests for ownerId $ownerId: $e');
      debugPrint('Error code: ${e is FirebaseException ? e.code : "unknown"}');
      debugPrint('Stack trace: $stackTrace');
      _pendingRequests = 0;
      // Re-throw permission errors
      if (e is FirebaseException && e.code == 'permission-denied') {
        debugPrint('_loadBookingRequests: PERMISSION DENIED - Check Firestore rules!');
        rethrow;
      }
    }
  }

  void _listenToBookingRequests(String ownerId) {
    _bookingRequestsSubscription?.cancel();
    final collection = _firestore
        .collection('salons')
        .doc(ownerId)
        .collection('bookings');
    try {
      _bookingRequestsSubscription = collection
          .where('status', whereIn: ['pending', 'upcoming'])
          .snapshots()
          .listen((snapshot) {
        _pendingRequests = snapshot.size;
        debugPrint('Booking requests updated: $_pendingRequests');
        notifyListeners();
      }, onError: (e) {
        debugPrint('Error in booking requests listener: $e');
      });
    } catch (e) {
      debugPrint('Error setting up booking requests listener: $e');
      try {
        _bookingRequestsSubscription = collection
            .where('status', isEqualTo: 'upcoming')
            .snapshots()
            .listen((snapshot) {
          _pendingRequests = snapshot.size;
          notifyListeners();
        }, onError: (e2) {
          debugPrint('Error in booking requests listener (fallback): $e2');
        });
      } catch (e3) {
        debugPrint('Error setting up booking requests listener (fallback): $e3');
      }
    }
  }

  void _listenToQueue(String ownerId) {
    _queueLiveSubscription?.cancel();
    try {
      // Listen only to active queue items
      try {
        _queueLiveSubscription = _firestore
            .collection('salons')
            .doc(ownerId)
            .collection('queue')
            .where('status', whereIn: ['waiting', 'serving'])
            .snapshots()
            .listen((_) {
          debugPrint('Queue updated (nested collection with whereIn)');
          _refreshQueue();
        }, onError: (e) {
          debugPrint('Error in queue listener (nested with whereIn): $e');
        });
      } catch (e) {
        debugPrint('Error setting up queue listener (nested with whereIn): $e');
        // Fallback: listen to all and filter in service
        try {
          _queueLiveSubscription = _firestore
              .collection('salons')
              .doc(ownerId)
              .collection('queue')
              .snapshots()
              .listen((_) {
            debugPrint('Queue updated (nested collection, all items)');
            _refreshQueue();
          }, onError: (e2) {
            debugPrint('Error in queue listener (nested, all items): $e2');
          });
        } catch (e3) {
          debugPrint('Error setting up queue listener (nested, all items): $e3');
          // fall back to top-level queue collection if nested path fails
          try {
            _queueLiveSubscription = _firestore
                .collection('queue')
                .where('status', whereIn: ['waiting', 'serving'])
                .snapshots()
                .listen((_) {
              debugPrint('Queue updated (top-level with whereIn)');
              _refreshQueue();
            }, onError: (e4) {
              debugPrint('Error in queue listener (top-level with whereIn): $e4');
            });
          } catch (e5) {
            debugPrint('Error setting up queue listener (top-level with whereIn): $e5');
            _queueLiveSubscription = _firestore
                .collection('queue')
                .snapshots()
                .listen((_) {
              debugPrint('Queue updated (top-level, all items)');
              _refreshQueue();
            }, onError: (e6) {
              debugPrint('Error in queue listener (top-level, all items): $e6');
            });
          }
        }
      }
    } catch (e) {
      debugPrint('Error in _listenToQueue: $e');
    }
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
      await _firestore
          .collection('salons')
          .doc(ownerId)
          .set({'isOpen': value}, SetOptions(merge: true));
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
    try {
      await _queueService.updateStatus(ownerId: ownerId, id: id, status: status);
    } catch (_) {
      // ignore write failures for now
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
      debugPrint('Cannot refresh queue: ownerId is null');
      return;
    }
    try {
      _queueItems = await _queueService.loadQueue(ownerId);
      debugPrint('Refreshed queue: ${_queueItems.length} items');
      // Notify listeners immediately, then again after avatars load
      notifyListeners();
      // Load avatars asynchronously and notify again when done
      // Note: loadQueue already calls _hydrateCustomerAvatars internally,
      // but we notify again to ensure UI updates after async avatar loading
      Future.delayed(const Duration(milliseconds: 500), () {
        notifyListeners();
      });
    } catch (e) {
      debugPrint('Error refreshing queue: $e');
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
