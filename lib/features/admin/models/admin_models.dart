import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? parseAdminDate(dynamic value) {
  if (value is Timestamp) return value.toDate();
  return null;
}

String _stringValue(Map<String, dynamic> data, String key) {
  return (data[key] as String?)?.trim() ?? '';
}

int _intValue(Map<String, dynamic> data, String key) {
  return (data[key] as num?)?.toInt() ?? 0;
}

class AdminDashboardStats {
  const AdminDashboardStats({
    required this.pendingSalonCount,
    required this.totalSalons,
    required this.restrictedSalonCount,
    required this.totalOutstandingFee,
  });

  final int pendingSalonCount;
  final int totalSalons;
  final int restrictedSalonCount;
  final int totalOutstandingFee;
}

class AdminSalonSummary {
  const AdminSalonSummary({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.address,
    required this.contact,
    required this.verificationStatus,
    required this.submittedAt,
    required this.reviewNote,
    required this.coverImageUrl,
    required this.isOpen,
    required this.isRestricted,
    required this.restrictionReason,
    required this.restrictedAt,
  });

  final String id;
  final String name;
  final String ownerId;
  final String address;
  final String contact;
  final String verificationStatus;
  final DateTime? submittedAt;
  final String reviewNote;
  final String coverImageUrl;
  final bool isOpen;
  final bool isRestricted;
  final String restrictionReason;
  final DateTime? restrictedAt;

  factory AdminSalonSummary.fromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    return AdminSalonSummary(
      id: id,
      name: _stringValue(data, 'name'),
      ownerId: _stringValue(data, 'ownerId'),
      address: _stringValue(data, 'address'),
      contact: _stringValue(data, 'contact').isNotEmpty
          ? _stringValue(data, 'contact')
          : _stringValue(data, 'phone'),
      verificationStatus: _stringValue(data, 'verificationStatus').isEmpty
          ? 'verified'
          : _stringValue(data, 'verificationStatus'),
      submittedAt: parseAdminDate(data['submittedAt']),
      reviewNote: _stringValue(data, 'reviewNote'),
      coverImageUrl: _stringValue(data, 'coverImageUrl').isNotEmpty
          ? _stringValue(data, 'coverImageUrl')
          : _stringValue(data, 'coverPhotoUrl'),
      isOpen: data['isOpen'] == true,
      isRestricted: data['isRestricted'] == true,
      restrictionReason: _stringValue(data, 'restrictionReason'),
      restrictedAt: parseAdminDate(data['restrictedAt']),
    );
  }
}

class AdminSalonDetail {
  const AdminSalonDetail({
    required this.salon,
    required this.owner,
    required this.services,
    required this.galleryUrls,
    required this.reviewedBy,
    required this.reviewedAt,
    required this.financeSummary,
    required this.platformFeeLedger,
    required this.platformFeePayments,
  });

  final AdminSalonSummary salon;
  final AdminDirectoryUser? owner;
  final List<AdminSalonServiceItem> services;
  final List<String> galleryUrls;
  final String reviewedBy;
  final DateTime? reviewedAt;
  final AdminSalonFinanceSummary financeSummary;
  final List<AdminFinanceLedgerItem> platformFeeLedger;
  final List<AdminPaymentItem> platformFeePayments;
}

class AdminSalonFinanceSummary {
  const AdminSalonFinanceSummary({
    required this.totalFee,
    required this.totalPaid,
    required this.totalOutstanding,
    required this.paymentCount,
  });

  const AdminSalonFinanceSummary.empty()
      : totalFee = 0,
        totalPaid = 0,
        totalOutstanding = 0,
        paymentCount = 0;

  final int totalFee;
  final int totalPaid;
  final int totalOutstanding;
  final int paymentCount;
}

class AdminSalonServiceItem {
  const AdminSalonServiceItem({
    required this.id,
    required this.name,
    required this.price,
    required this.durationMinutes,
  });

  final String id;
  final String name;
  final int price;
  final int durationMinutes;

  factory AdminSalonServiceItem.fromDoc(String id, Map<String, dynamic> data) {
    return AdminSalonServiceItem(
      id: id,
      name: _stringValue(data, 'name'),
      price: _intValue(data, 'price'),
      durationMinutes: _intValue(data, 'durationMinutes') > 0
          ? _intValue(data, 'durationMinutes')
          : _intValue(data, 'duration'),
    );
  }
}

class AdminSupportRequest {
  const AdminSupportRequest({
    required this.id,
    required this.ownerId,
    required this.ownerEmail,
    required this.ownerName,
    required this.contact,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    required this.adminNote,
    required this.assignedAdminUid,
    required this.resolvedBy,
    required this.createdAt,
    required this.updatedAt,
    required this.resolvedAt,
  });

  final String id;
  final String ownerId;
  final String ownerEmail;
  final String ownerName;
  final String contact;
  final String category;
  final String subject;
  final String message;
  final String status;
  final String adminNote;
  final String assignedAdminUid;
  final String resolvedBy;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? resolvedAt;

  factory AdminSupportRequest.fromDoc(String id, Map<String, dynamic> data) {
    return AdminSupportRequest(
      id: id,
      ownerId: _stringValue(data, 'ownerId'),
      ownerEmail: _stringValue(data, 'ownerEmail'),
      ownerName: _stringValue(data, 'ownerName'),
      contact: _stringValue(data, 'contact'),
      category: _stringValue(data, 'category'),
      subject: _stringValue(data, 'subject'),
      message: _stringValue(data, 'message'),
      status: _stringValue(data, 'status').isEmpty
          ? 'open'
          : _stringValue(data, 'status'),
      adminNote: _stringValue(data, 'adminNote'),
      assignedAdminUid: _stringValue(data, 'assignedAdminUid'),
      resolvedBy: _stringValue(data, 'resolvedBy'),
      createdAt: parseAdminDate(data['createdAt']),
      updatedAt: parseAdminDate(data['updatedAt']),
      resolvedAt: parseAdminDate(data['resolvedAt']),
    );
  }
}

class AdminDirectoryUser {
  const AdminDirectoryUser({
    required this.uid,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.profileComplete,
    required this.createdAt,
  });

  final String uid;
  final String name;
  final String email;
  final String phone;
  final String role;
  final bool profileComplete;
  final DateTime? createdAt;

  factory AdminDirectoryUser.fromDoc(String id, Map<String, dynamic> data) {
    return AdminDirectoryUser(
      uid: id,
      name: _stringValue(data, 'name'),
      email: _stringValue(data, 'email'),
      phone: _stringValue(data, 'phone'),
      role: _stringValue(data, 'role'),
      profileComplete: data['profileComplete'] == true,
      createdAt: parseAdminDate(data['createdAt']),
    );
  }
}

class AdminDirectorySalon {
  const AdminDirectorySalon({
    required this.id,
    required this.name,
    required this.ownerId,
    required this.address,
    required this.contact,
    required this.verificationStatus,
    required this.createdAt,
    required this.updatedAt,
    required this.isOpen,
    required this.isRestricted,
    required this.restrictionReason,
  });

  final String id;
  final String name;
  final String ownerId;
  final String address;
  final String contact;
  final String verificationStatus;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final bool isOpen;
  final bool isRestricted;
  final String restrictionReason;

  factory AdminDirectorySalon.fromDoc(String id, Map<String, dynamic> data) {
    return AdminDirectorySalon(
      id: id,
      name: _stringValue(data, 'name'),
      ownerId: _stringValue(data, 'ownerId'),
      address: _stringValue(data, 'address'),
      contact: _stringValue(data, 'contact').isNotEmpty
          ? _stringValue(data, 'contact')
          : _stringValue(data, 'phone'),
      verificationStatus: _stringValue(data, 'verificationStatus').isEmpty
          ? 'verified'
          : _stringValue(data, 'verificationStatus'),
      createdAt: parseAdminDate(data['createdAt']),
      updatedAt: parseAdminDate(data['updatedAt']),
      isOpen: data['isOpen'] == true,
      isRestricted: data['isRestricted'] == true,
      restrictionReason: _stringValue(data, 'restrictionReason'),
    );
  }
}

class AdminFinanceLedgerItem {
  const AdminFinanceLedgerItem({
    required this.id,
    required this.collection,
    required this.salonId,
    required this.salonName,
    required this.relatedId,
    required this.amount,
    required this.paidAmount,
    required this.status,
    required this.date,
  });

  final String id;
  final String collection;
  final String salonId;
  final String salonName;
  final String relatedId;
  final int amount;
  final int paidAmount;
  final String status;
  final DateTime? date;

  int get remainingAmount {
    final remaining = amount - paidAmount;
    return remaining < 0 ? 0 : remaining;
  }
}

class AdminPaymentItem {
  const AdminPaymentItem({
    required this.id,
    required this.collection,
    required this.salonId,
    required this.salonName,
    required this.amount,
    required this.status,
    required this.paymentMethod,
    required this.note,
    required this.date,
  });

  final String id;
  final String collection;
  final String salonId;
  final String salonName;
  final int amount;
  final String status;
  final String paymentMethod;
  final String note;
  final DateTime? date;
}

class AdminFinanceSnapshot {
  const AdminFinanceSnapshot({
    required this.platformFeeLedger,
    required this.platformFeePayments,
    required this.barberTipLedger,
    required this.barberPayouts,
  });

  final List<AdminFinanceLedgerItem> platformFeeLedger;
  final List<AdminPaymentItem> platformFeePayments;
  final List<AdminFinanceLedgerItem> barberTipLedger;
  final List<AdminPaymentItem> barberPayouts;
}
