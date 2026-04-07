import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/shared/services/firestore_cache.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

class PlatformFeeReportProvider extends ChangeNotifier {
  PlatformFeeReportProvider({
    required AuthProvider authProvider,
    FirebaseFirestore? firestore,
  })  : _authProvider = authProvider,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final AuthProvider _authProvider;
  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _error;
  PlatformFeeSummary _summary = const PlatformFeeSummary.empty();
  List<PlatformFeeLedgerItem> _ledger = [];
  List<PlatformFeePaymentItem> _payments = [];
  Map<String, int> _pendingAllocatedByLedger = const {};

  bool get isLoading => _isLoading;
  bool get isSubmitting => _isSubmitting;
  String? get error => _error;
  PlatformFeeSummary get summary => _summary;
  List<PlatformFeeLedgerItem> get ledger => _ledger;
  List<PlatformFeePaymentItem> get payments => _payments;
  int pendingAmountForLedger(String ledgerId) =>
      _pendingAllocatedByLedger[ledgerId] ?? 0;

  Future<void> load() async {
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return;
    }

    _setLoading(true);
    _setError(null);
    try {
      final ledgerSnap = await FirestoreCache.getQuery(_firestore
          .collection('platform_fee_ledger')
          .where('salonId', isEqualTo: ownerId));
      final paymentSnap = await FirestoreCache.getQuery(_firestore
          .collection('platform_fee_payments')
          .where('salonId', isEqualTo: ownerId));

      _ledger = ledgerSnap.docs
          .map((doc) => PlatformFeeLedgerItem.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));

      _payments = paymentSnap.docs
          .map((doc) => PlatformFeePaymentItem.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => b.paidAt.compareTo(a.paidAt));

      _pendingAllocatedByLedger = _buildPendingAllocatedByLedger(_payments);

      final totalFee = _ledger.fold<int>(0, (acc, item) => acc + item.amount);
      final paidFee =
          _ledger.fold<int>(0, (acc, item) => acc + item.paidAmount);
      final dueFee = _ledger.fold<int>(
        0,
        (acc, item) => acc + item.remainingAmount,
      );
      final availableToSubmitFee = _ledger.fold<int>(
        0,
        (acc, item) =>
            acc +
            _remainingAvailableForSubmission(
              item: item,
              pendingAllocated: _pendingAllocatedByLedger[item.id] ?? 0,
            ),
      );
      final pendingReviewFee = dueFee - availableToSubmitFee;

      _summary = PlatformFeeSummary(
        totalFee: totalFee,
        paidFee: paidFee,
        dueFee: dueFee < 0 ? 0 : dueFee,
        pendingReviewFee: pendingReviewFee < 0 ? 0 : pendingReviewFee,
        availableToSubmitFee:
            availableToSubmitFee < 0 ? 0 : availableToSubmitFee,
      );
    } catch (_) {
      _setError('Failed to load platform fee report.');
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> recordPayment({
    required int amount,
    required String transactionId,
    required XFile proofFile,
    String note = '',
  }) async {
    if (_isSubmitting) return false;
    final ownerId = _authProvider.currentUser?.uid;
    if (ownerId == null) {
      _setError('Please log in again.');
      return false;
    }

    final dueAmount = _summary.availableToSubmitFee;
    final normalizedTransactionId = transactionId.trim();
    if (amount <= 0) {
      _setError('Enter a valid amount.');
      return false;
    }
    if (amount > dueAmount) {
      _setError('Amount exceeds the unpaid balance available for review.');
      return false;
    }
    if (normalizedTransactionId.isEmpty) {
      _setError('Transaction ID is required.');
      return false;
    }
    if (proofFile.path.trim().isEmpty) {
      _setError('Payment screenshot is required.');
      return false;
    }

    final unpaidItems = _ledger
        .where((item) =>
            _remainingAvailableForSubmission(
              item: item,
              pendingAllocated: _pendingAllocatedByLedger[item.id] ?? 0,
            ) >
            0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (unpaidItems.isEmpty) {
      _setError('No unpaid fees to pay.');
      return false;
    }

    const normalizedMethod = 'bKash';
    final normalizedNote = note.trim();

    _setSubmitting(true);
    _setError(null);
    try {
      DateTime? rangeStart;
      DateTime? rangeEnd;
      int remaining = amount;

      final paymentRef = _firestore.collection('platform_fee_payments').doc();
      final proofStoragePath =
          'salons/$ownerId/platform_fee_payments/${paymentRef.id}.${_ext(proofFile.name)}';

      String salonName = '';
      String salonPhone = '';
      try {
        final salonSnap =
            await _firestore.collection('salons').doc(ownerId).get();
        final salonData = salonSnap.data() ?? <String, dynamic>{};
        salonName = (salonData['name'] as String?) ?? '';
        salonPhone = (salonData['contact'] as String?) ??
            (salonData['phone'] as String?) ??
            '';
      } catch (_) {
        // ignore salon lookup failures
      }

      final allocations = <PlatformFeePaymentAllocation>[];
      for (final item in unpaidItems) {
        if (remaining <= 0) break;
        final outstanding = _remainingAvailableForSubmission(
          item: item,
          pendingAllocated: _pendingAllocatedByLedger[item.id] ?? 0,
        );
        if (outstanding <= 0) continue;
        final payAmount = remaining >= outstanding ? outstanding : remaining;
        remaining -= payAmount;
        rangeStart =
            rangeStart == null ? item.date : _minDate(rangeStart, item.date);
        rangeEnd = rangeEnd == null ? item.date : _maxDate(rangeEnd, item.date);
        allocations.add(
          PlatformFeePaymentAllocation(
            ledgerId: item.id,
            bookingId: item.bookingId,
            amount: payAmount,
          ),
        );
      }

      if (allocations.isEmpty || remaining > 0) {
        _setError('Could not allocate the requested amount.');
        return false;
      }

      final proofRef = _storage.ref().child(proofStoragePath);
      String? uploadedProofUrl;
      try {
        final uploadTask = proofRef.putFile(
          File(proofFile.path),
          SettableMetadata(contentType: _contentTypeFor(proofFile.name)),
        );
        final snap = await uploadTask.whenComplete(() {});
        uploadedProofUrl = await snap.ref.getDownloadURL();

        await paymentRef.set({
          'salonId': ownerId,
          if (salonName.isNotEmpty) 'salonName': salonName,
          if (salonPhone.isNotEmpty) 'salonPhone': salonPhone,
          'amount': amount,
          'transactionId': normalizedTransactionId,
          'paymentMethod': normalizedMethod,
          'note': normalizedNote,
          'proofImageUrl': uploadedProofUrl,
          'proofStoragePath': proofStoragePath,
          'allocations': allocations.map((item) => item.toMap()).toList(),
          'paidAt': FieldValue.serverTimestamp(),
          'status': 'pending',
          if (rangeStart != null) 'rangeStart': Timestamp.fromDate(rangeStart),
          if (rangeEnd != null) 'rangeEnd': Timestamp.fromDate(rangeEnd),
        });
      } catch (_) {
        if (uploadedProofUrl != null) {
          try {
            await proofRef.delete();
          } catch (_) {
            // ignore storage cleanup failures
          }
        }
        rethrow;
      }

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

  Map<String, int> _buildPendingAllocatedByLedger(
    List<PlatformFeePaymentItem> payments,
  ) {
    final allocations = <String, int>{};
    for (final payment in payments) {
      if (!payment.isPending) continue;
      for (final allocation in payment.allocations) {
        final current = allocations[allocation.ledgerId] ?? 0;
        allocations[allocation.ledgerId] = current + allocation.amount;
      }
    }
    return allocations;
  }

  int _remainingAvailableForSubmission({
    required PlatformFeeLedgerItem item,
    required int pendingAllocated,
  }) {
    final remaining = item.remainingAmount - pendingAllocated;
    return remaining < 0 ? 0 : remaining;
  }

  DateTime _minDate(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
  DateTime _maxDate(DateTime a, DateTime b) => a.isAfter(b) ? a : b;

  String _ext(String name) {
    final dot = name.lastIndexOf('.');
    if (dot == -1 || dot == name.length - 1) return 'jpg';
    return name.substring(dot + 1);
  }

  String _contentTypeFor(String name) {
    switch (_ext(name).toLowerCase()) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'heif':
        return 'image/heif';
      default:
        return 'image/jpeg';
    }
  }
}

class PlatformFeeSummary {
  final int totalFee;
  final int paidFee;
  final int dueFee;
  final int pendingReviewFee;
  final int availableToSubmitFee;

  const PlatformFeeSummary({
    required this.totalFee,
    required this.paidFee,
    required this.dueFee,
    required this.pendingReviewFee,
    required this.availableToSubmitFee,
  });

  const PlatformFeeSummary.empty()
      : totalFee = 0,
        paidFee = 0,
        dueFee = 0,
        pendingReviewFee = 0,
        availableToSubmitFee = 0;
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
    final paidAmount = paidAmountRaw ?? (status == 'paid' ? amount : 0);
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
  final String transactionId;
  final String proofImageUrl;
  final String proofStoragePath;
  final String note;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final String status;
  final String reviewNote;
  final String reviewedBy;
  final DateTime? reviewedAt;
  final List<PlatformFeePaymentAllocation> allocations;

  const PlatformFeePaymentItem({
    required this.id,
    required this.amount,
    required this.paidAt,
    required this.method,
    required this.transactionId,
    required this.proofImageUrl,
    required this.proofStoragePath,
    required this.note,
    required this.rangeStart,
    required this.rangeEnd,
    required this.status,
    required this.reviewNote,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.allocations,
  });

  factory PlatformFeePaymentItem.fromDoc(String id, Map<String, dynamic> data) {
    return PlatformFeePaymentItem(
      id: id,
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      paidAt: _parseDate(data['paidAt']) ?? DateTime.now(),
      method: (data['paymentMethod'] as String?)?.trim() ?? 'bKash',
      transactionId: (data['transactionId'] as String?) ?? '',
      proofImageUrl: (data['proofImageUrl'] as String?) ?? '',
      proofStoragePath: (data['proofStoragePath'] as String?) ?? '',
      note: (data['note'] as String?) ?? '',
      rangeStart: _parseDate(data['rangeStart']),
      rangeEnd: _parseDate(data['rangeEnd']),
      status: (data['status'] as String?) ?? 'confirmed',
      reviewNote: (data['reviewNote'] as String?) ?? '',
      reviewedBy: (data['reviewedBy'] as String?) ?? '',
      reviewedAt: _parseDate(data['reviewedAt']),
      allocations: ((data['allocations'] as List?) ?? const [])
          .whereType<Map>()
          .map(
            (item) => PlatformFeePaymentAllocation.fromMap(
              Map<String, dynamic>.from(item),
            ),
          )
          .toList(),
    );
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }

  bool get isConfirmed => status == 'confirmed' || status == 'paid';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';
}

class PlatformFeePaymentAllocation {
  const PlatformFeePaymentAllocation({
    required this.ledgerId,
    required this.bookingId,
    required this.amount,
  });

  final String ledgerId;
  final String bookingId;
  final int amount;

  factory PlatformFeePaymentAllocation.fromMap(Map<String, dynamic> data) {
    return PlatformFeePaymentAllocation(
      ledgerId: (data['ledgerId'] as String?) ?? '',
      bookingId: (data['bookingId'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'ledgerId': ledgerId,
      'bookingId': bookingId,
      'amount': amount,
    };
  }
}
