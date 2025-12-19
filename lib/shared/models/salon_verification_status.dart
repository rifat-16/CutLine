enum SalonVerificationStatus {
  pending,
  verified,
  rejected,
}

extension SalonVerificationStatusFirestore on SalonVerificationStatus {
  String get firestoreValue {
    switch (this) {
      case SalonVerificationStatus.pending:
        return 'pending';
      case SalonVerificationStatus.verified:
        return 'verified';
      case SalonVerificationStatus.rejected:
        return 'rejected';
    }
  }
}

SalonVerificationStatus salonVerificationStatusFromFirestore(Object? raw) {
  final value = raw is String ? raw.trim().toLowerCase() : '';
  switch (value) {
    case 'pending':
      return SalonVerificationStatus.pending;
    case 'rejected':
      return SalonVerificationStatus.rejected;
    case 'verified':
      return SalonVerificationStatus.verified;
    default:
      // Backwards-compat: older salon docs might not have this field yet.
      return SalonVerificationStatus.verified;
  }
}
