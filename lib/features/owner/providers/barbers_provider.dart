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
            .map((e) => _mapBarber(e as Map<String, dynamic>? ?? {}))
            .toList();
      } else {
        final snap = await _firestore
            .collection('barbers')
            .where('ownerId', isEqualTo: ownerId)
            .get();
        _barbers = snap.docs.map((doc) => _mapBarber(doc.data())).toList();
      }
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

  OwnerBarber _mapBarber(Map<String, dynamic> data) {
    return OwnerBarber(
      id: (data['id'] as String?) ??
          DateTime.now().millisecondsSinceEpoch.toString(),
      name: (data['name'] as String?) ?? 'Barber',
      email: (data['email'] as String?) ?? '',
      phone: (data['phone'] as String?) ?? '',
      password: '',
      specialization: (data['specialization'] as String?) ?? 'Haircut',
      rating: (data['rating'] as num?)?.toDouble() ?? 4.5,
      servedToday: (data['servedToday'] as num?)?.toInt() ?? 0,
      status: _statusFromString((data['status'] as String?) ?? 'onFloor'),
      nextClient: data['nextClient'] as String?,
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

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }
}
