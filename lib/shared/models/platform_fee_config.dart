import 'package:cloud_firestore/cloud_firestore.dart';

class PlatformFeeConfig {
  const PlatformFeeConfig({
    required this.amount,
    required this.isFree,
    this.updatedAt,
    this.updatedBy = '',
  });

  const PlatformFeeConfig.free()
      : amount = 0,
        isFree = true,
        updatedAt = null,
        updatedBy = '';

  final int amount;
  final bool isFree;
  final DateTime? updatedAt;
  final String updatedBy;

  int get effectiveAmount => isFree ? 0 : amount;
  String get mode => isFree ? 'free' : 'custom';

  factory PlatformFeeConfig.fromMap(Map<String, dynamic> data) {
    final parsedAmount = _parseAmount(data['fee']);
    final rawMode = (data['mode'] as String?)?.trim().toLowerCase() ?? '';
    final rawIsFree = data['isFree'] == true;
    final isFree = rawIsFree ||
        rawMode == 'free' ||
        (parsedAmount <= 0 && rawMode != 'custom');

    return PlatformFeeConfig(
      amount: isFree ? 0 : parsedAmount,
      isFree: isFree,
      updatedAt: _parseDate(data['updatedAt']),
      updatedBy: (data['updatedBy'] as String?)?.trim() ?? '',
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'fee': effectiveAmount,
      'isFree': isFree,
      'mode': mode,
      'updatedAt': FieldValue.serverTimestamp(),
      if (updatedBy.isNotEmpty) 'updatedBy': updatedBy,
    };
  }

  static int _parseAmount(dynamic raw) {
    if (raw is num) return _normalizeAmount(raw.toInt());
    if (raw is String) {
      final normalized = raw.trim().toLowerCase();
      if (normalized.isEmpty || normalized == 'free') return 0;
      final parsed = int.tryParse(normalized);
      if (parsed != null) return _normalizeAmount(parsed);
      final digits = RegExp(r'\d+').stringMatch(normalized);
      return _normalizeAmount(digits == null ? 0 : int.tryParse(digits) ?? 0);
    }
    return 0;
  }

  static int _normalizeAmount(int value) {
    if (value <= 0) return 0;
    return value > 1000000000 ? 1000000000 : value;
  }

  static DateTime? _parseDate(dynamic value) {
    if (value is Timestamp) return value.toDate();
    return null;
  }
}
