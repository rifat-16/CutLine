import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:flutter/material.dart';

class PlatformFeeReportProvider extends ChangeNotifier {
  PlatformFeeReportProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  PlatformFeeSummary _summary = const PlatformFeeSummary.empty();
  List<PlatformFeeLedgerItem> _ledger = [];
  List<PlatformFeePaymentItem> _payments = [];

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  PlatformFeeSummary get summary => _summary;
  List<PlatformFeeLedgerItem> get ledger => _ledger;
  List<PlatformFeePaymentItem> get payments => _payments;

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
          .collection('platform_fee_ledger')
          .where('salonId', isEqualTo: ownerId)
          .get();
      final paymentSnap = await _firestore
          .collection('platform_fee_payments')
          .where('salonId', isEqualTo: ownerId)
          .get();

      _ledger = ledgerSnap.docs
          .map((doc) => PlatformFeeLedgerItem.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      _payments = paymentSnap.docs
          .map((doc) => PlatformFeePaymentItem.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => b.paidAt.compareTo(a.paidAt));

      final totalFee = _ledger.fold<int>(0, (acc, item) => acc + item.amount);
      final paidFee = _payments
          .where((item) => item.isConfirmed)
          .fold<int>(0, (acc, item) => acc + item.amount);
      final dueFee = totalFee - paidFee;

      _summary = PlatformFeeSummary(
        totalFee: totalFee,
        paidFee: paidFee,
        dueFee: dueFee < 0 ? 0 : dueFee,
      );
    } catch (_) {
      _setError('Failed to load platform fee report.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> recordPayment({
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

    final dueAmount = _summary.dueFee;
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
      _setError('No unpaid fees to pay.');
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

      final paymentRef = _firestore.collection('platform_fee_payments').doc();
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
        rangeEnd = rangeEnd == null ? item.date : _maxDate(rangeEnd, item.date);
        final newPaidAmount = item.paidAmount + payAmount;
        final ref = _firestore.collection('platform_fee_ledger').doc(item.id);
        batch.update(ref, {
          'paidAmount': newPaidAmount,
          'status': 'pending',
          'paidAt': FieldValue.serverTimestamp(),
          'paymentId': paymentRef.id,
        });
      }

      batch.set(paymentRef, {
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
      _setError('Failed to record payment.');
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

class PlatformFeeSummary {
  final int totalFee;
  final int paidFee;
  final int dueFee;

  const PlatformFeeSummary({
    required this.totalFee,
    required this.paidFee,
    required this.dueFee,
  });

  const PlatformFeeSummary.empty()
      : totalFee = 0,
        paidFee = 0,
        dueFee = 0;
}

class PlatformFeeLedgerItem {
  final String id;
  final String bookingId;
  final int amount;
  final int paidAmount;
  final String paymentId;
  final String status;
  final DateTime date;

  const PlatformFeeLedgerItem({
    required this.id,
    required this.bookingId,
    required this.amount,
    required this.paidAmount,
    required this.paymentId,
    required this.status,
    required this.date,
  });

  factory PlatformFeeLedgerItem.fromDoc(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final completedAt = data['completedAt'];
    final date =
        _parseDate(completedAt) ?? _parseDate(createdAt) ?? DateTime.now();
    final amount = (data['feeAmount'] as num?)?.toInt() ?? 0;
    final status = (data['status'] as String?) ?? 'unpaid';
    final paidAmountRaw = (data['paidAmount'] as num?)?.toInt();
    final paidAmount =
        paidAmountRaw ?? (status == 'paid' ? amount : 0);
    return PlatformFeeLedgerItem(
      id: id,
      bookingId: (data['bookingId'] as String?) ?? id,
      amount: amount,
      paidAmount: paidAmount < 0 ? 0 : paidAmount,
      paymentId: (data['paymentId'] as String?) ?? '',
      status: status,
      date: date,
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  int get remainingAmount {
    final remaining = amount - paidAmount;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isPaid => remainingAmount == 0;
}

class PlatformFeePaymentItem {
  final String id;
  final int amount;
  final DateTime paidAt;
  final String method;
  final String note;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final String status;

  const PlatformFeePaymentItem({
    required this.id,
    required this.amount,
    required this.paidAt,
    required this.method,
    required this.note,
    required this.rangeStart,
    required this.rangeEnd,
    required this.status,
  });

  factory PlatformFeePaymentItem.fromDoc(String id, Map<String, dynamic> data) {
    return PlatformFeePaymentItem(
      id: id,
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      paidAt: _parseDate(data['paidAt']) ?? DateTime.now(),
      method: (data['paymentMethod'] as String?) ?? '—',
      note: (data['note'] as String?) ?? '',
      rangeStart: _parseDate(data['rangeStart']),
      rangeEnd: _parseDate(data['rangeEnd']),
      status: (data['status'] as String?) ?? 'confirmed',
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  bool get isConfirmed => status == 'confirmed' || status == 'paid';
}
