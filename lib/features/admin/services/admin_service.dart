import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:cutline/features/admin/models/admin_models.dart';

class AdminService {
  AdminService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<AdminDashboardStats> loadDashboardStats() async {
    final salons = await _firestore.collection('salons').get();
    final feeLedger = await _firestore.collection('platform_fee_ledger').get();

    int pendingSalonCount = 0;
    int restrictedSalonCount = 0;
    for (final doc in salons.docs) {
      final salon = AdminSalonSummary.fromDoc(doc.id, doc.data());
      if (salon.verificationStatus == 'pending') {
        pendingSalonCount++;
      }
      if (salon.isRestricted) {
        restrictedSalonCount++;
      }
    }

    int totalOutstandingFee = 0;
    for (final doc in feeLedger.docs) {
      totalOutstandingFee +=
          _platformFeeLedgerItemFromDoc(doc.id, doc.data()).remainingAmount;
    }

    return AdminDashboardStats(
      pendingSalonCount: pendingSalonCount,
      totalSalons: salons.size,
      restrictedSalonCount: restrictedSalonCount,
      totalOutstandingFee: totalOutstandingFee,
    );
  }

  Future<List<AdminSalonSummary>> loadRecentPendingSalons(
      {int limit = 5}) async {
    final snapshot = await _firestore
        .collection('salons')
        .where('verificationStatus', isEqualTo: 'pending')
        .get();
    final salons = snapshot.docs
        .map((doc) => AdminSalonSummary.fromDoc(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => _compareDatesDescending(a.submittedAt, b.submittedAt));
    return salons.take(limit).toList();
  }

  Future<List<AdminSalonSummary>> loadRecentRestrictedSalons({
    int limit = 5,
  }) async {
    final snapshot = await _firestore
        .collection('salons')
        .orderBy('updatedAt', descending: true)
        .limit(100)
        .get();
    final salons = snapshot.docs
        .map((doc) => AdminSalonSummary.fromDoc(doc.id, doc.data()))
        .where((salon) => salon.isRestricted)
        .take(limit)
        .toList();
    return salons;
  }

  Stream<List<AdminSalonSummary>> watchPendingSalons() {
    return _firestore
        .collection('salons')
        .where('verificationStatus', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) {
      final salons = snapshot.docs
          .map((doc) => AdminSalonSummary.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => _compareDatesDescending(a.submittedAt, b.submittedAt));
      return salons;
    });
  }

  Future<AdminSalonDetail> loadSalonDetail(String salonId) async {
    final salonRef = _firestore.collection('salons').doc(salonId);
    final salonSnap = await salonRef.get();
    if (!salonSnap.exists) {
      throw StateError('Salon not found.');
    }

    final salon = AdminSalonSummary.fromDoc(salonSnap.id, salonSnap.data()!);
    final ownerSnap =
        await _firestore.collection('users').doc(salon.ownerId).get();
    final owner = ownerSnap.exists
        ? AdminDirectoryUser.fromDoc(ownerSnap.id, ownerSnap.data()!)
        : null;

    final servicesSnap =
        await salonRef.collection('all_services').orderBy('order').get();
    final photosSnap =
        await salonRef.collection('photos').orderBy('order').get();
    final data = salonSnap.data() ?? <String, dynamic>{};
    final gallery = <String>[
      for (final doc in photosSnap.docs)
        ((doc.data()['url'] as String?) ?? '').trim(),
    ].where((item) => item.isNotEmpty).toList();
    final platformFeeLedgerSnap = await _firestore
        .collection('platform_fee_ledger')
        .where('salonId', isEqualTo: salon.id)
        .get();
    final platformFeePaymentsSnap = await _firestore
        .collection('platform_fee_payments')
        .where('salonId', isEqualTo: salon.id)
        .get();

    final platformFeeLedger = platformFeeLedgerSnap.docs
        .map((doc) => _platformFeeLedgerItemFromDoc(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => _compareDatesDescending(a.date, b.date));
    final platformFeePayments = platformFeePaymentsSnap.docs
        .map((doc) => _platformFeePaymentFromDoc(doc.id, doc.data()))
        .toList()
      ..sort((a, b) => _compareDatesDescending(a.date, b.date));

    final totalFee = platformFeeLedger.fold<int>(
      0,
      (total, item) => total + item.amount,
    );
    final totalPaid = platformFeeLedger.fold<int>(
      0,
      (total, item) => total + item.paidAmount,
    );
    final totalOutstanding = platformFeeLedger.fold<int>(
      0,
      (total, item) => total + item.remainingAmount,
    );

    return AdminSalonDetail(
      salon: salon,
      owner: owner,
      services: servicesSnap.docs
          .map((doc) => AdminSalonServiceItem.fromDoc(doc.id, doc.data()))
          .toList(),
      galleryUrls: gallery,
      reviewedBy: (data['reviewedBy'] as String?)?.trim() ?? '',
      reviewedAt: parseAdminDate(data['reviewedAt']),
      financeSummary: AdminSalonFinanceSummary(
        totalFee: totalFee,
        totalPaid: totalPaid,
        totalOutstanding: totalOutstanding,
        paymentCount: platformFeePayments.length,
      ),
      platformFeeLedger: platformFeeLedger.take(20).toList(),
      platformFeePayments: platformFeePayments.take(20).toList(),
    );
  }

  Future<List<AdminSupportRequest>> loadRecentSupportRequests({
    int limit = 5,
  }) async {
    final snapshot = await _firestore
        .collection('supportRequests')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .get();
    return snapshot.docs
        .map((doc) => AdminSupportRequest.fromDoc(doc.id, doc.data()))
        .toList();
  }

  Stream<List<AdminSupportRequest>> watchSupportRequests({
    String status = 'all',
  }) {
    Query<Map<String, dynamic>> query = _firestore
        .collection('supportRequests')
        .orderBy('createdAt', descending: true);
    if (status != 'all') {
      query = _firestore
          .collection('supportRequests')
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true);
    }
    return query.snapshots().map((snapshot) => snapshot.docs
        .map((doc) => AdminSupportRequest.fromDoc(doc.id, doc.data()))
        .toList());
  }

  Future<List<AdminDirectoryUser>> loadUsers({
    String role = 'all',
  }) async {
    Query<Map<String, dynamic>> query =
        _firestore.collection('users').orderBy('createdAt', descending: true);
    if (role != 'all') {
      query = _firestore
          .collection('users')
          .where('role', isEqualTo: role)
          .orderBy('createdAt', descending: true);
    }
    final snapshot = await query.limit(200).get();
    return snapshot.docs
        .map((doc) => AdminDirectoryUser.fromDoc(doc.id, doc.data()))
        .toList();
  }

  Future<List<AdminDirectorySalon>> loadSalons({
    String verificationStatus = 'all',
    String restrictionStatus = 'all',
  }) async {
    final snapshot = await _firestore
        .collection('salons')
        .orderBy('updatedAt', descending: true)
        .limit(300)
        .get();
    return snapshot.docs
        .map((doc) => AdminDirectorySalon.fromDoc(doc.id, doc.data()))
        .where((salon) {
      final verificationMatches = verificationStatus == 'all' ||
          salon.verificationStatus == verificationStatus;
      final restrictionMatches = switch (restrictionStatus) {
        'restricted' => salon.isRestricted,
        'active' => !salon.isRestricted,
        _ => true,
      };
      return verificationMatches && restrictionMatches;
    }).toList();
  }

  Stream<List<AdminDirectorySalon>> watchSalons() {
    return _firestore.collection('salons').snapshots().map((snapshot) {
      final salons = snapshot.docs
          .map((doc) => AdminDirectorySalon.fromDoc(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => _compareDatesDescending(a.updatedAt, b.updatedAt));
      return salons;
    });
  }

  Future<AdminFinanceSnapshot> loadFinanceSnapshot() async {
    final platformFeeLedgerSnap = await _firestore
        .collection('platform_fee_ledger')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    final platformFeePaymentsSnap = await _firestore
        .collection('platform_fee_payments')
        .orderBy('paidAt', descending: true)
        .limit(200)
        .get();
    final barberTipLedgerSnap = await _firestore
        .collection('barber_tip_ledger')
        .orderBy('createdAt', descending: true)
        .limit(200)
        .get();
    final barberPayoutsSnap = await _firestore
        .collection('barber_payouts')
        .orderBy('paidAt', descending: true)
        .limit(200)
        .get();

    return AdminFinanceSnapshot(
      platformFeeLedger: platformFeeLedgerSnap.docs
          .map(
            (doc) => _platformFeeLedgerItemFromDoc(doc.id, doc.data()),
          )
          .toList(),
      platformFeePayments: platformFeePaymentsSnap.docs
          .map(
            (doc) => _platformFeePaymentFromDoc(doc.id, doc.data()),
          )
          .toList(),
      barberTipLedger: barberTipLedgerSnap.docs
          .map(
            (doc) => AdminFinanceLedgerItem(
              id: doc.id,
              collection: 'barber_tip_ledger',
              salonId: (doc.data()['salonId'] as String?)?.trim() ?? '',
              salonName: '',
              relatedId:
                  (doc.data()['barberName'] as String?)?.trim().isNotEmpty ==
                          true
                      ? (doc.data()['barberName'] as String).trim()
                      : (doc.data()['bookingId'] as String?)?.trim() ?? doc.id,
              amount: (doc.data()['tipAmount'] as num?)?.toInt() ?? 0,
              paidAmount: (doc.data()['paidAmount'] as num?)?.toInt() ?? 0,
              status: (doc.data()['status'] as String?)?.trim() ?? 'unpaid',
              date: parseAdminDate(doc.data()['completedAt']) ??
                  parseAdminDate(doc.data()['createdAt']),
            ),
          )
          .toList(),
      barberPayouts: barberPayoutsSnap.docs
          .map(
            (doc) => AdminPaymentItem(
              id: doc.id,
              collection: 'barber_payouts',
              salonId: (doc.data()['salonId'] as String?)?.trim() ?? '',
              salonName: (doc.data()['salonName'] as String?)?.trim() ?? '',
              amount: (doc.data()['amount'] as num?)?.toInt() ?? 0,
              status: (doc.data()['status'] as String?)?.trim() ?? 'pending',
              paymentMethod:
                  (doc.data()['paymentMethod'] as String?)?.trim() ?? 'Cash',
              note: (doc.data()['note'] as String?)?.trim() ?? '',
              date: parseAdminDate(doc.data()['paidAt']),
            ),
          )
          .toList(),
    );
  }

  AdminFinanceLedgerItem _platformFeeLedgerItemFromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    return AdminFinanceLedgerItem(
      id: id,
      collection: 'platform_fee_ledger',
      salonId: (data['salonId'] as String?)?.trim() ?? '',
      salonName: '',
      relatedId: (data['bookingId'] as String?)?.trim() ?? id,
      amount: (data['feeAmount'] as num?)?.toInt() ?? 0,
      paidAmount: (data['paidAmount'] as num?)?.toInt() ?? 0,
      status: (data['status'] as String?)?.trim() ?? 'unpaid',
      date: parseAdminDate(data['completedAt']) ??
          parseAdminDate(data['createdAt']),
    );
  }

  AdminPaymentItem _platformFeePaymentFromDoc(
    String id,
    Map<String, dynamic> data,
  ) {
    return AdminPaymentItem(
      id: id,
      collection: 'platform_fee_payments',
      salonId: (data['salonId'] as String?)?.trim() ?? '',
      salonName: (data['salonName'] as String?)?.trim() ?? '',
      amount: (data['amount'] as num?)?.toInt() ?? 0,
      status: (data['status'] as String?)?.trim() ?? 'pending',
      paymentMethod: (data['paymentMethod'] as String?)?.trim() ?? 'Cash',
      note: (data['note'] as String?)?.trim() ?? '',
      date: parseAdminDate(data['paidAt']),
    );
  }

  int _compareDatesDescending(DateTime? left, DateTime? right) {
    if (left == null && right == null) return 0;
    if (left == null) return 1;
    if (right == null) return -1;
    return right.compareTo(left);
  }
}
