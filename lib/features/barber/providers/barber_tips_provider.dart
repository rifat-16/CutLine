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
      final receivedTips = _payouts
          .where((item) => item.isConfirmed)
          .fold<int>(0, (acc, item) => acc + item.amount);
      final outstandingTips =
          (totalTips - receivedTips).clamp(0, totalTips).toInt();
      final pendingConfirmationRaw = _payouts
          .where((item) => !item.isConfirmed)
          .fold<int>(0, (acc, item) => acc + item.amount);
      final pendingConfirmationTips = pendingConfirmationRaw > outstandingTips
          ? outstandingTips
          : pendingConfirmationRaw;
      final notYetSentTips = outstandingTips - pendingConfirmationTips;

      _summary = BarberTipSummary(
        totalTips: totalTips,
        receivedTips: receivedTips,
        pendingConfirmationTips: pendingConfirmationTips,
        notYetSentTips: notYetSentTips < 0 ? 0 : notYetSentTips,
        outstandingTips: outstandingTips,
      );
    } on FirebaseException catch (error) {
      _setError(_mapLoadError(error));
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

      final linkedLedgerItems =
          _ledger.where((item) => item.payoutId == payoutId).toList();

      final batch = _firestore.batch();
      batch.update(payoutRef, {
        'status': 'confirmed',
        'confirmedAt': FieldValue.serverTimestamp(),
      });

      for (final item in linkedLedgerItems) {
        final tipAmount = item.tipAmount;
        final paidAmount = item.paidAmount;
        final statusLabel = paidAmount >= tipAmount
            ? 'paid'
            : paidAmount > 0
                ? 'partial'
                : 'unpaid';
        batch.update(_firestore.collection('barber_tip_ledger').doc(item.id), {
          'status': statusLabel,
          'confirmedAt': FieldValue.serverTimestamp(),
        });
      }

      await batch.commit();
      await load();
      return true;
    } on FirebaseException catch (error) {
      _setError(_mapConfirmError(error));
      return false;
    } catch (_) {
      _setError('Failed to confirm payout.');
      return false;
    } finally {
      _setSubmitting(false);
    }
  }

  String _mapLoadError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'You do not have access to these tip records.';
      case 'unavailable':
        return 'Connection issue. Check your internet and try again.';
      default:
        return 'Failed to load tips.';
    }
  }

  String _mapConfirmError(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'This payout could not be confirmed from your account.';
      case 'not-found':
        return 'This payout is no longer available.';
      case 'unavailable':
        return 'Connection issue. Check your internet and try again.';
      default:
        return 'Failed to confirm payout.';
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
  final int receivedTips;
  final int pendingConfirmationTips;
  final int notYetSentTips;
  final int outstandingTips;

  const BarberTipSummary({
    required this.totalTips,
    required this.receivedTips,
    required this.pendingConfirmationTips,
    required this.notYetSentTips,
    required this.outstandingTips,
  });

  const BarberTipSummary.empty()
      : totalTips = 0,
        receivedTips = 0,
        pendingConfirmationTips = 0,
        notYetSentTips = 0,
        outstandingTips = 0;
}
