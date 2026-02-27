import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/shared/models/barber_tip_models.dart';
import 'package:cutline/shared/services/firestore_cache.dart';
import 'package:flutter/material.dart';

class OwnerBarberPayoutsProvider extends ChangeNotifier {
  OwnerBarberPayoutsProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  String? _error;
  List<BarberPayoutOverview> _barbers = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<BarberPayoutOverview> get barbers => _barbers;

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }

    _setLoading(true);
    _setError(null);
    try {
      final salonDoc = await FirestoreCache.getDocCacheFirst(
          _firestore.collection('salons').doc(ownerId));
      final salonData = salonDoc.data() ?? <String, dynamic>{};
      final barbersList = salonData['barbers'] as List?;

      final nameById = <String, String>{};
      if (barbersList != null) {
        for (final barber in barbersList) {
          if (barber is Map) {
            final id =
                (barber['id'] as String?) ?? (barber['uid'] as String?) ?? '';
            final name = (barber['name'] as String?) ?? '';
            if (id.isNotEmpty) {
              nameById[id] = name.isNotEmpty ? name : 'Barber';
            }
          }
        }
      }

      final ledgerSnap = await FirestoreCache.getQuery(_firestore
          .collection('barber_tip_ledger')
          .where('salonId', isEqualTo: ownerId));
      final payoutSnap = await FirestoreCache.getQuery(_firestore
          .collection('barber_payouts')
          .where('salonId', isEqualTo: ownerId));

      final ledgerItems = ledgerSnap.docs
          .map((doc) => BarberTipLedgerItem.fromDoc(doc.id, doc.data()))
          .toList();
      final payoutItems = payoutSnap.docs
          .map((doc) => BarberPayoutItem.fromDoc(doc.id, doc.data()))
          .toList();

      final totalByBarber = <String, int>{};
      final paidByBarber = <String, int>{};
      final fallbackNameById = <String, String>{};

      for (final item in ledgerItems) {
        if (item.barberId.isEmpty) continue;
        totalByBarber[item.barberId] =
            (totalByBarber[item.barberId] ?? 0) + item.tipAmount;
        if (item.barberName.isNotEmpty) {
          fallbackNameById[item.barberId] = item.barberName;
        }
      }

      for (final item in payoutItems) {
        if (item.barberId.isEmpty) continue;
        if (!item.isConfirmed) continue;
        paidByBarber[item.barberId] =
            (paidByBarber[item.barberId] ?? 0) + item.amount;
      }

      final idsFromData = <String>{
        ...totalByBarber.keys,
        ...paidByBarber.keys,
      };
      final ids = idsFromData.isNotEmpty ? idsFromData : nameById.keys;

      _barbers = ids.map((id) {
        final totalTips = totalByBarber[id] ?? 0;
        final paidTips = paidByBarber[id] ?? 0;
        final dueTips = totalTips - paidTips;
        final name = nameById[id] ?? fallbackNameById[id] ?? 'Barber';
        return BarberPayoutOverview(
          barberId: id,
          barberName: name,
          totalTips: totalTips,
          paidTips: paidTips,
          dueTips: dueTips < 0 ? 0 : dueTips,
        );
      }).toList()
        ..sort((a, b) => b.dueTips.compareTo(a.dueTips));
    } catch (_) {
      _setError('Failed to load barber payouts.');
    } finally {
      _setLoading(false);
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

class BarberPayoutOverview {
  final String barberId;
  final String barberName;
  final int totalTips;
  final int paidTips;
  final int dueTips;

  const BarberPayoutOverview({
    required this.barberId,
    required this.barberName,
    required this.totalTips,
    required this.paidTips,
    required this.dueTips,
  });
}
