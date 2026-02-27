import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/services/owner_queue_service.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/shared/services/queue_serial_service.dart';
import 'package:flutter/material.dart';

class ManageQueueProvider extends ChangeNotifier {
  ManageQueueProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
    OwnerQueueService? queueService,
    QueueSerialService? serialService,
  })  : _authProvider = authProvider,
        _queueService = queueService ?? OwnerQueueService(firestore: firestore),
        _serialService =
            serialService ?? QueueSerialService(firestore: firestore) {
    _queueSubscription = _queueService.onChanged.listen((_) {
      _refreshSilent();
    });
  }

  final AuthProvider _authProvider;
  final OwnerQueueService _queueService;
  final QueueSerialService _serialService;
  StreamSubscription<void>? _queueSubscription;

  bool _isLoading = false;
  bool _isSavingManual = false;
  String? _error;
  List<OwnerQueueItem> _queue = [];
  List<QueueServiceOption> _services = [];
  List<QueueBarberOption> _barbers = [];

  bool get isLoading => _isLoading;
  bool get isSavingManual => _isSavingManual;
  String? get error => _error;
  List<OwnerQueueItem> get queue => _queue;
  List<QueueServiceOption> get services => _services;
  List<QueueBarberOption> get barbers => _barbers;

  Future<void> load() async {
    await Future.wait([
      _fetchQueue(showLoading: true),
      loadCatalog(),
    ]);
  }

  Future<void> updateStatus(String id, OwnerQueueStatus status) async {
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

    _queue = _queue.map((item) {
      if (item.id != id) return item;
      return item.copyWith(status: status);
    }).toList();
    notifyListeners();
  }

  Future<void> loadCatalog({bool force = false}) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    if (!force && _services.isNotEmpty && _barbers.isNotEmpty) return;
    try {
      final values = await Future.wait([
        _serialService.loadServices(salonId: ownerId),
        _serialService.loadBarbers(salonId: ownerId),
      ]);
      _services = values[0] as List<QueueServiceOption>;
      _barbers = values[1] as List<QueueBarberOption>;
      notifyListeners();
    } catch (_) {
      // keep previous values on failures
    }
  }

  Future<bool> createManualByOwner({
    required String customerName,
    required String barberId,
    required String serviceId,
  }) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return false;
    }
    await loadCatalog();
    final barber = _barbers.where((b) => b.id == barberId).toList();
    final service = _services.where((s) => s.id == serviceId).toList();
    if (barber.isEmpty || service.isEmpty) {
      _setError('Please select a valid barber and service.');
      return false;
    }

    _setSavingManual(true);
    _setError(null);
    try {
      await _serialService.createManualByOwner(
        salonId: ownerId,
        actorUid: ownerId,
        customerName: customerName,
        barber: barber.first,
        service: service.first,
      );
      await _refreshSilent();
      return true;
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        _setError(
            'Permission denied while adding manual customer. Check Firestore rules deployment and salon verification status.');
      } else {
        _setError('Could not add manual customer.');
      }
      return false;
    } finally {
      _setSavingManual(false);
    }
  }

  Future<bool> updateManualEntry({
    required String entryId,
    required String customerName,
    required String barberId,
    required String serviceId,
  }) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return false;
    }
    await loadCatalog();
    final barber = _barbers.where((b) => b.id == barberId).toList();
    final service = _services.where((s) => s.id == serviceId).toList();
    if (barber.isEmpty || service.isEmpty) {
      _setError('Please select a valid barber and service.');
      return false;
    }

    _setSavingManual(true);
    _setError(null);
    try {
      await _serialService.updateManualEntry(
        salonId: ownerId,
        entryId: entryId,
        actorUid: ownerId,
        actorRole: 'owner',
        customerName: customerName,
        barber: barber.first,
        service: service.first,
      );
      await _refreshSilent();
      return true;
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        _setError(
            'Permission denied while updating manual entry. Check Firestore rules deployment and salon verification status.');
      } else {
        _setError('Could not update manual entry.');
      }
      return false;
    } finally {
      _setSavingManual(false);
    }
  }

  Future<bool> deleteManualEntry(String entryId) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return false;
    }
    _setSavingManual(true);
    _setError(null);
    try {
      await _serialService.deleteManualEntry(
        salonId: ownerId,
        entryId: entryId,
      );
      await _refreshSilent();
      return true;
    } catch (e) {
      if (e is FirebaseException && e.code == 'permission-denied') {
        _setError(
            'Permission denied while deleting manual entry. Check Firestore rules deployment and salon verification status.');
      } else {
        _setError('Could not delete manual entry.');
      }
      return false;
    } finally {
      _setSavingManual(false);
    }
  }

  Future<void> _fetchQueue({bool showLoading = false}) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    if (showLoading) {
      _setLoading(true);
      _setError(null);
    }
    try {
      _queue = await _queueService.loadQueue(ownerId);
      _error = null;
    } catch (_) {
      if (showLoading) _setError('Failed to load queue.');
    } finally {
      if (showLoading) _setLoading(false);
      notifyListeners();
    }
  }

  Future<void> _refreshSilent() => _fetchQueue(showLoading: false);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSavingManual(bool value) {
    _isSavingManual = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _queueSubscription?.cancel();
    super.dispose();
  }
}
