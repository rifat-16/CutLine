import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/shared/models/barber_tip_models.dart';
import 'package:cutline/shared/services/firestore_cache.dart';
import 'package:flutter/material.dart';

class BarberTipsProvider extends ChangeNotifier {
  BarberTipsProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  BarberTipSummary _summary = const BarberTipSummary.empty();
  List<BarberTipLedgerItem> _ledger = [];
  List<BarberPayoutItem> _payouts = [];

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  BarberTipSummary get summary => _summary;
  List<BarberTipLedgerItem> get ledger => _ledger;
  List<BarberPayoutItem> get payouts => _payouts;

  Future<void> load() async {
    final barberId = _authProvider.currentUser?.uid;
    if (barberId == null) {
      _setError('Please log in again.');
      return;
    }

    _setLoading(true);
    _setError(null);
    try {
      final ledgerSnap = await FirestoreCache.getQuery(_firestore
          .collection('barber_tip_ledger')
          .where('barberId', isEqualTo: barberId));
      final payoutSnap = await FirestoreCache.getQuery(_firestore
          .collection('barber_payouts')
          .where('barberId', isEqualTo: barberId));

      _ledger = ledgerSnap.docs
          .map((doc) => BarberTipLedgerItem.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      _payouts = payoutSnap.docs
          .map((doc) => BarberPayoutItem.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => b.paidAt.compareTo(a.paidAt));

      final totalTips =
          _ledger.fold<int>(0, (acc, item) => acc + item.tipAmount);
      final paidTips = _payouts
          .where((item) => item.isConfirmed)
          .fold<int>(0, (acc, item) => acc + item.amount);
      final dueTips = totalTips - paidTips;

      _summary = BarberTipSummary(
        totalTips: totalTips,
        paidTips: paidTips,
        dueTips: dueTips < 0 ? 0 : dueTips,
      );
    } catch (_) {
      _setError('Failed to load tips.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> confirmPayout(String payoutId) async {
    if (_isSubmitting) return false;
    final barberId = _authProvider.currentUser?.uid;
    if (barberId == null) {
      _setError('Please log in again.');
      return false;
    }

    _setSubmitting(true);
    _setError(null);
    try {
      final payoutRef = _firestore.collection('barber_payouts').doc(payoutId);
      final payoutSnap = await payoutRef.get();
      if (!payoutSnap.exists) {
        _setError('Payout not found.');
        return false;
      }
      final payoutData = payoutSnap.data() ?? {};
      if ((payoutData['barberId'] as String?) != barberId) {
        _setError('Not allowed to confirm this payout.');
        return false;
      }
      final status = (payoutData['status'] as String?) ?? 'pending';
      if (status == 'confirmed' || status == 'paid') {
        await load();
        return true;
      }

      final ledgerSnap = await _firestore
          .collection('barber_tip_ledger')
          .where('payoutId', isEqualTo: payoutId)
          .get();

      final batch = _firestore.batch();
      batch.update(payoutRef, {
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      for (final doc in ledgerSnap.docs) {
        final data = doc.data();
        final tipAmount = (data['tipAmount'] as num?)?.toInt() ?? 0;
        final paidAmount = (data['paidAmount'] as num?)?.toInt() ?? 0;
        final statusLabel = paidAmount >= tipAmount
            ? 'paid'
            : paidAmount > 0
                ? 'partial'
                : 'unpaid';
        batch.update(doc.reference, {
          'status': statusLabel,
          'confirmedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await load();
      return true;
    } catch (_) {
      _setError('Failed to confirm payout.');
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setSubmitting(bool value) {
    _isSubmitting = value;
    notifyListeners();
  }

  void _setError(String? message) {
    _error = message;
    notifyListeners();
  }
}

class BarberTipSummary {
  final int totalTips;
  final int paidTips;
  final int dueTips;

  const BarberTipSummary({
    required this.totalTips,
    required this.paidTips,
    required this.dueTips,
  });

  const BarberTipSummary.empty()
      : totalTips = 0,
        paidTips = 0,
        dueTips = 0;
}
