import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';

class BarberProfileProvider extends ChangeNotifier {
  BarberProfileProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  BarberProfile? _profile;
  int _clientsServed = 0;

  bool get isLoading => _isLoading;
  String? get error => _error;
  BarberProfile? get profile => _profile;
  int get clientsServed => _clientsServed;

  Future<void> load() async {
    final uid = _authProvider.currentUser?.uid;
    if (uid == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final profile = await _fetchProfile(uid);
      if (profile == null) {
        _setError('Could not load profile.');
        return;
      }
      _profile = profile;
      _clientsServed = await _fetchServedCount(profile);
    } catch (_) {
      _setError('Failed to load profile. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  Future<BarberProfile?> _fetchProfile(String uid) async {
    try {
      final snap = await _firestore.collection('users').doc(uid).get();
      if (!snap.exists) return null;
      final data = snap.data() ?? {};
      return BarberProfile(
        uid: uid,
        ownerId: (data['ownerId'] as String?) ?? '',
        name: (data['name'] as String?) ?? '',
        specialization: (data['specialization'] as String?) ?? '',
        phone: (data['phone'] as String?) ?? '',
        email: (data['email'] as String?) ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  Future<int> _fetchServedCount(BarberProfile profile) async {
    if (profile.ownerId.isEmpty) return 0;
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await _firestore
          .collection('salons')
          .doc(profile.ownerId)
          .collection('queue')
          .get();
    } catch (_) {
      snap = await _firestore.collection('queue').get();
    }
    int count = 0;
    for (final doc in snap.docs) {
      final data = doc.data();
      final status = (data['status'] as String?) ?? '';
      if (!_matchesBarber(data, profile)) continue;
      if (status == 'done' || status == 'completed') {
        count++;
      }
    }
    return count;
  }

  bool _matchesBarber(Map<String, dynamic> data, BarberProfile profile) {
    final barberId = data['barberId'] ?? data['barberUid'];
    if (barberId is String && barberId == profile.uid) return true;
    final barberName =
        (data['barberName'] as String?) ?? (data['barber'] as String?);
    if (barberName != null &&
        profile.name.isNotEmpty &&
        barberName.toLowerCase() == profile.name.toLowerCase()) {
      return true;
    }
    return false;
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

class BarberProfile {
  final String uid;
  final String ownerId;
  final String name;
  final String specialization;
  final String phone;
  final String email;

  const BarberProfile({
    required this.uid,
    required this.ownerId,
    required this.name,
    required this.specialization,
    required this.phone,
    required this.email,
  });
}
