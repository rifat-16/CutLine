import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/shared/models/barber_tip_models.dart';
import 'package:flutter/material.dart';

class BarberPayoutDetailProvider extends ChangeNotifier {
  BarberPayoutDetailProvider({
    required AuthProvider authProvider,
    required this.barberId,
    required this.barberName,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  final String barberId;
  final String barberName;

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
  int get unpaidCount =>
      _ledger.where((item) => item.remainingAmount > 0).length;

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }

    _setLoading(true);
    _setError(null);
    try {
      final ledgerSnap = await _firestore
          .collection('barber_tip_ledger')
          .where('salonId', isEqualTo: ownerId)
          .get();
      final payoutSnap = await _firestore
          .collection('barber_payouts')
          .where('salonId', isEqualTo: ownerId)
          .get();

      _ledger = ledgerSnap.docs
          .map((doc) => BarberTipLedgerItem.fromDoc(doc.id, doc.data()))
          .where((item) => item.barberId == barberId)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      _payouts = payoutSnap.docs
          .map((doc) => BarberPayoutItem.fromDoc(doc.id, doc.data()))
          .where((item) => item.barberId == barberId)
          .toList()
        ..sort((a, b) => b.paidAt.compareTo(a.paidAt));

      final totalTips = _ledger.fold<int>(0, (acc, item) => acc + item.tipAmount);
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
      _setError('Failed to load barber tips.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> recordPayout({
    required int amount,
    required String paymentMethod,
    String note = '',
  }) async {
    if (_isSubmitting) return false;
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return false;
    }

    final dueAmount = _summary.dueTips;
    if (amount <= 0) {
      _setError('Enter a valid amount.');
      return false;
    }
    if (amount > dueAmount) {
      _setError('Amount exceeds due.');
      return false;
    }

    final unpaidItems = _ledger
        .where((item) => item.remainingAmount > 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (unpaidItems.isEmpty) {
      _setError('No unpaid tips to pay.');
      return false;
    }

    final normalizedMethod =
        paymentMethod.trim().isEmpty ? 'Cash' : paymentMethod.trim();
    final normalizedNote = note.trim();

    _setSubmitting(true);
    _setError(null);
    try {
      DateTime? rangeStart;
      DateTime? rangeEnd;
      int remaining = amount;

      final payoutRef = _firestore.collection('barber_payouts').doc();
      final batch = _firestore.batch();

      String salonName = '';
      String salonPhone = '';
      try {
        final salonSnap = await _firestore.collection('salons').doc(ownerId).get();
        final salonData = salonSnap.data() ?? <String, dynamic>{};
        salonName = (salonData['name'] as String?) ?? '';
        salonPhone = (salonData['contact'] as String?) ??
            (salonData['phone'] as String?) ??
            '';
      } catch (_) {
        // ignore salon lookup failures
      }

      for (final item in unpaidItems) {
        if (remaining <= 0) break;
        final outstanding = item.remainingAmount;
        if (outstanding <= 0) continue;
        final payAmount = remaining >= outstanding ? outstanding : remaining;
        remaining -= payAmount;
        rangeStart =
            rangeStart == null ? item.date : _minDate(rangeStart, item.date);
        rangeEnd =
            rangeEnd == null ? item.date : _maxDate(rangeEnd, item.date);
        final newPaidAmount = item.paidAmount + payAmount;
        final ref = _firestore.collection('barber_tip_ledger').doc(item.id);
        batch.update(ref, {
          'paidAmount': newPaidAmount,
          'status': 'pending',
          'paidAt': FieldValue.serverTimestamp(),
          'payoutId': payoutRef.id,
        });
      }

      batch.set(payoutRef, {
        'barberId': barberId,
        'barberName': barberName,
        'salonId': ownerId,
        if (salonName.isNotEmpty) 'salonName': salonName,
        if (salonPhone.isNotEmpty) 'salonPhone': salonPhone,
        'amount': amount,
        'paymentMethod': normalizedMethod,
        'note': normalizedNote,
        'paidAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        if (rangeStart != null) 'rangeStart': Timestamp.fromDate(rangeStart),
        if (rangeEnd != null) 'rangeEnd': Timestamp.fromDate(rangeEnd),
      });

      await batch.commit();
      await load();
      return true;
    } catch (_) {
      _setError('Failed to record payout.');
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

  DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
  DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
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
