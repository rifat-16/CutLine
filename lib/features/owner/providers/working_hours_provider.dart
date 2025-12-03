import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class WorkingHoursProvider extends ChangeNotifier {
  WorkingHoursProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  List<OwnerWorkingDay> _days = [];
  List<OwnerWorkingDay> _originalDays = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<OwnerWorkingDay> get days => _days;
  bool get hasChanges => !_listEquals(_days, _originalDays);

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }
    _setLoading(true);
    _setError(null);
    try {
      final doc = await _firestore.collection('salons').doc(ownerId).get();
      final data = doc.data() ?? {};
      final hours = data['workingHours'];
      if (hours is Map<String, dynamic>) {
        _days = _mapDays(hours);
        _originalDays = List.of(_days);
      } else {
        _days = List.of(kOwnerDefaultWorkingDays);
        _originalDays = List.of(_days);
      }
    } catch (_) {
      _days = List.of(kOwnerDefaultWorkingDays);
      _originalDays = List.of(_days);
      _setError('Showing cached data. Pull to refresh.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> save() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) return;
    try {
      await _firestore.collection('salons').doc(ownerId).set({
        'workingHours': {
          for (final day in _days)
            day.day: {
              'open': day.isOpen,
              'openTime': _formatTime(day.openTime),
              'closeTime': _formatTime(day.closeTime),
            }
        }
      }, SetOptions(merge: true));
      _originalDays = List.of(_days);
      notifyListeners();
    } catch (_) {
      _setError('Failed to save schedule.');
    }
  }

  void updateDay(int index, OwnerWorkingDay updated) {
    _days[index] = updated;
    notifyListeners();
  }

  List<OwnerWorkingDay> _mapDays(Map<String, dynamic> data) {
    final defaults = {for (var d in kOwnerDefaultWorkingDays) d.day: d};
    return defaults.keys.map((dayName) {
      final entry = data[dayName];
      if (entry is Map<String, dynamic>) {
        final open = entry['open'] == true;
        final openTime = _parseTime(entry['openTime'] as String?);
        final closeTime = _parseTime(entry['closeTime'] as String?);
        return OwnerWorkingDay(
          day: dayName,
          isOpen: open,
          openTime: openTime ?? defaults[dayName]!.openTime,
          closeTime: closeTime ?? defaults[dayName]!.closeTime,
        );
      }
      return defaults[dayName]!;
    }).toList();
  }

  TimeOfDay? _parseTime(String? time) {
    if (time == null || !time.contains(':')) return null;
    final parts = time.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTime(TimeOfDay time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }

  bool _listEquals(List<OwnerWorkingDay> a, List<OwnerWorkingDay> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].day != b[i].day ||
          a[i].isOpen != b[i].isOpen ||
          a[i].openTime != b[i].openTime ||
          a[i].closeTime != b[i].closeTime) {
        return false;
      }
    }
    return true;
  }
}
