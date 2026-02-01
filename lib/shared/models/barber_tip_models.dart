import 'package:cloud_firestore/cloud_firestore.dart';

class BarberTipLedgerItem {
  final String id;
  final String bookingId;
  final String barberId;
  final String barberName;
  final int tipAmount;
  final int paidAmount;
  final String payoutId;
  final String status;
  final DateTime date;

  const BarberTipLedgerItem({
    required this.id,
    required this.bookingId,
    required this.barberId,
    required this.barberName,
    required this.tipAmount,
    required this.paidAmount,
    required this.payoutId,
    required this.status,
    required this.date,
  });

  factory BarberTipLedgerItem.fromDoc(String id, Map<String, dynamic> data) {
    final createdAt = data['createdAt'];
    final completedAt = data['completedAt'];
    final paidAt = data['paidAt'];
    final date = _parseDate(completedAt) ??
        _parseDate(createdAt) ??
        _parseDate(paidAt) ??
        DateTime.now();
    final tipAmount = (data['tipAmount'] as num?)?.toInt() ?? 0;
    final status = (data['status'] as String?) ?? 'unpaid';
    final paidAmountRaw = (data['paidAmount'] as num?)?.toInt();
    final paidAmount =
        paidAmountRaw ?? (status == 'paid' ? tipAmount : 0);
    return BarberTipLedgerItem(
      id: id,
      bookingId: (data['bookingId'] as String?) ?? id,
      barberId: (data['barberId'] as String?) ?? '',
      barberName: (data['barberName'] as String?) ?? 'Barber',
      tipAmount: tipAmount,
      paidAmount: paidAmount < 0 ? 0 : paidAmount,
      payoutId: (data['payoutId'] as String?) ?? '',
      status: status,
      date: date,
    );
  }

  int get remainingAmount {
    final remaining = tipAmount - paidAmount;
    return remaining < 0 ? 0 : remaining;
  }

  bool get isPaid => remainingAmount == 0;
}

class BarberPayoutItem {
  final String id;
  final String barberId;
  final int amount;
  final DateTime paidAt;
  final String method;
  final String note;
  final DateTime? rangeStart;
  final DateTime? rangeEnd;
  final String status;

  const BarberPayoutItem({
    required this.id,
    required this.barberId,
    required this.amount,
    required this.paidAt,
    required this.method,
    required this.note,
    required this.rangeStart,
    required this.rangeEnd,
    required this.status,
  });

  factory BarberPayoutItem.fromDoc(String id, Map<String, dynamic> data) {
    return BarberPayoutItem(
      id: id,
      barberId: (data['barberId'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      paidAt: _parseDate(data['paidAt']) ?? DateTime.now(),
      method: (data['paymentMethod'] as String?) ?? '—',
      note: (data['note'] as String?) ?? '',
      rangeStart: _parseDate(data['rangeStart']),
      rangeEnd: _parseDate(data['rangeEnd']),
      status: (data['status'] as String?) ?? 'confirmed',
    );
  }

  bool get isConfirmed => status == 'confirmed' || status == 'paid';
}

DateTime? _parseDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  return null;
}
