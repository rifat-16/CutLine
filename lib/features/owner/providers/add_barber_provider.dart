import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/salon_setup_provider.dart';
import 'package:cutline/features/owner/services/barber_service.dart';
import 'package:flutter/material.dart';

class AddBarberProvider extends ChangeNotifier {
  AddBarberProvider({
    required AuthProvider authProvider,
    BarberService? barberService,
  })  : _authProvider = authProvider,
        _barberService = barberService ?? BarberService();

  final AuthProvider _authProvider;
  final BarberService _barberService;

  bool _isSaving = false;
  String? _error;
  BarberCreationResult? _result;

  bool get isSaving => _isSaving;
  String? get error => _error;
  BarberCreationResult? get result => _result;

  Future<bool> createBarber({
    required BarberInput input,
  }) async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return false;
    }

    _setSaving(true);
    _setError(null);
    _result = null;
    try {
      final results = await _barberService.createBarbers(
        ownerId: ownerId,
        barbers: [input],
      );
      if (results.isNotEmpty && results.first.isSuccess) {
        _result = results.first;
        return true;
      }
      _setError(results.first.error ?? 'Could not create barber.');
      return false;
    } catch (_) {
      _setError('Could not create barber.');
      return false;
    } finally {
      _setSaving(false);
    }
  }

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }
}
