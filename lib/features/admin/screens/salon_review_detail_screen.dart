import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:cutline/features/admin/models/admin_models.dart';
import 'package:cutline/features/admin/services/admin_action_service.dart';
import 'package:cutline/features/admin/services/admin_service.dart';
import 'package:cutline/shared/widgets/web_safe_image.dart';

class SalonReviewDetailScreen extends StatefulWidget {
  const SalonReviewDetailScreen({
    super.key,
    required this.salonId,
  });

  final String salonId;

  @override
  State<SalonReviewDetailScreen> createState() =>
      _SalonReviewDetailScreenState();
}

class _SalonReviewDetailScreenState extends State<SalonReviewDetailScreen> {
  final AdminService _service = AdminService();
  final AdminActionService _actionService = AdminActionService();
  late Future<AdminSalonDetail> _future;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _future = _service.loadSalonDetail(widget.salonId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Salon Details')),
      body: FutureBuilder<AdminSalonDetail>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Could not load salon details.'));
          }
          final detail = snapshot.data!;
          final salon = detail.salon;
          final canReview = salon.verificationStatus != 'verified';
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (salon.coverImageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: WebSafeImage(
                    imageUrl: salon.coverImageUrl,
                    height: 220,
                    fit: BoxFit.cover,
                  ),
                ),
              if (salon.coverImageUrl.isNotEmpty) const SizedBox(height: 16),
              _SectionCard(
                title: 'Salon Info',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salon.name.isEmpty ? salon.id : salon.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _StatusChip(label: salon.verificationStatus),
                        _StatusChip(
                          label: salon.isOpen ? 'open' : 'off',
                          foreground: salon.isOpen
                              ? const Color(0xFF166534)
                              : const Color(0xFF475569),
                          background: salon.isOpen
                              ? const Color(0xFFE8F7ED)
                              : const Color(0xFFF1F5F9),
                        ),
                        if (salon.isRestricted)
                          const _StatusChip(
                            label: 'restricted',
                            foreground: Color(0xFF991B1B),
                            background: Color(0xFFFEE2E2),
                          ),
                        _DetailPill(
                          title: 'Submitted',
                          value: _formatDate(salon.submittedAt),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _DetailRow(label: 'Salon ID', value: salon.id),
                    _DetailRow(label: 'Owner ID', value: salon.ownerId),
                    _DetailRow(label: 'Address', value: salon.address),
                    _DetailRow(label: 'Contact', value: salon.contact),
                    _DetailRow(
                      label: 'Owner email',
                      value: detail.owner?.email ?? 'Unavailable',
                    ),
                    _DetailRow(
                      label: 'Owner phone',
                      value: detail.owner?.phone ?? 'Unavailable',
                    ),
                    _DetailRow(
                      label: 'Reviewed by',
                      value: detail.reviewedBy.isEmpty
                          ? 'Not reviewed yet'
                          : detail.reviewedBy,
                    ),
                    _DetailRow(
                      label: 'Review note',
                      value: salon.reviewNote.isEmpty
                          ? 'No review note'
                          : salon.reviewNote,
                    ),
                    _DetailRow(
                      label: 'Restriction note',
                      value: salon.restrictionReason.isEmpty
                          ? 'No restriction'
                          : salon.restrictionReason,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Platform Fee Summary',
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryTile(
                            label: 'Total fee',
                            value: '৳${detail.financeSummary.totalFee}',
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryTile(
                            label: 'Paid',
                            value: '৳${detail.financeSummary.totalPaid}',
                            color: const Color(0xFF15803D),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _SummaryTile(
                            label: 'Outstanding',
                            value: '৳${detail.financeSummary.totalOutstanding}',
                            color: const Color(0xFFB45309),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _SummaryTile(
                            label: 'Payments',
                            value:
                                detail.financeSummary.paymentCount.toString(),
                            color: const Color(0xFF475569),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Salon Control',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salon.isRestricted
                          ? 'This salon is currently restricted.'
                          : 'This salon is currently active.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      salon.isRestricted
                          ? (salon.restrictionReason.isEmpty
                              ? 'No reason provided.'
                              : salon.restrictionReason)
                          : 'Restrict this salon if outstanding platform fee stays unpaid.',
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _submitting
                            ? null
                            : () => _toggleRestriction(detail),
                        icon: _submitting
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(
                                salon.isRestricted
                                    ? Icons.lock_open
                                    : Icons.lock_outline,
                              ),
                        label: Text(
                          _submitting
                              ? 'Submitting...'
                              : salon.isRestricted
                                  ? 'Allow Salon Again'
                                  : 'Restrict Salon',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (canReview) ...[
                const SizedBox(height: 16),
                _SectionCard(
                  title: 'Verification Action',
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _submitting ? null : _reject,
                          icon: const Icon(Icons.close),
                          label: const Text('Reject'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _submitting ? null : _approve,
                          icon: const Icon(Icons.check),
                          label: const Text('Verify Salon'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Recent Platform Fee Ledger',
                child: detail.platformFeeLedger.isEmpty
                    ? const Text('No platform fee ledger yet.')
                    : Column(
                        children: detail.platformFeeLedger
                            .map(
                              (item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                  'Booking ${item.relatedId}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                subtitle: Text(
                                  'Fee: ৳${item.amount} • Paid: ৳${item.paidAmount} • Due: ৳${item.remainingAmount}',
                                ),
                                trailing: Text(_formatDate(item.date)),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Recent Payment History',
                child: detail.platformFeePayments.isEmpty
                    ? const Text('No payment submission yet.')
                    : Column(
                        children: detail.platformFeePayments
                            .map(
                              (item) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _AdminPaymentCard(
                                  item: item,
                                  submitting: _submitting,
                                  onOpenProof: item.proofImageUrl.isEmpty
                                      ? null
                                      : () => _showPlatformFeeProof(
                                          item.proofImageUrl),
                                  onConfirm: item.isPending
                                      ? () => _confirmPlatformFeePayment(item)
                                      : null,
                                  onReject: item.isPending
                                      ? () => _rejectPlatformFeePayment(item)
                                      : null,
                                ),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Services',
                child: detail.services.isEmpty
                    ? const Text('No services submitted.')
                    : Column(
                        children: detail.services
                            .map(
                              (item) => ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(
                                    item.name.isEmpty ? item.id : item.name),
                                subtitle: Text(
                                  item.durationMinutes > 0
                                      ? '${item.durationMinutes} mins'
                                      : 'Duration n/a',
                                ),
                                trailing: Text('৳${item.price}'),
                              ),
                            )
                            .toList(),
                      ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: 'Gallery',
                child: detail.galleryUrls.isEmpty
                    ? const Text('No gallery photos submitted.')
                    : SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: detail.galleryUrls.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            return ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: WebSafeImage(
                                imageUrl: detail.galleryUrls[index],
                                width: 120,
                                fit: BoxFit.cover,
                              ),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _approve() async {
    final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Verify salon'),
            content: const Text(
              'This will verify the salon and allow it to operate.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Verify'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirm) return;
    await _submitReview(decision: 'verified');
  }

  Future<void> _reject() async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject salon'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Required review note',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (!mounted || note == null) return;
    if (note.trim().isEmpty) {
      _showMessage('A rejection note is required.');
      return;
    }
    await _submitReview(decision: 'rejected', reviewNote: note);
  }

  Future<void> _toggleRestriction(AdminSalonDetail detail) async {
    if (detail.salon.isRestricted) {
      final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Allow salon again'),
              content: const Text(
                'This will remove the restriction and allow the salon to operate again.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Allow'),
                ),
              ],
            ),
          ) ??
          false;
      if (!confirm) return;
      await _submitRestriction(restricted: false);
      return;
    }

    final controller = TextEditingController(
      text: detail.financeSummary.totalOutstanding > 0
          ? 'Outstanding platform fee: ৳${detail.financeSummary.totalOutstanding}'
          : '',
    );
    final reason = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restrict salon'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Why is this salon being restricted?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Restrict'),
          ),
        ],
      ),
    );
    if (!mounted || reason == null) return;
    if (reason.trim().isEmpty) {
      _showMessage('A restriction reason is required.');
      return;
    }
    await _submitRestriction(restricted: true, reason: reason);
  }

  Future<void> _confirmPlatformFeePayment(AdminPaymentItem item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm payment'),
            content: Text(
              'Confirm ৳${item.amount} from ${item.salonName.isEmpty ? item.salonId : item.salonName}?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await _submitPlatformFeeReview(item: item, decision: 'confirmed');
  }

  Future<void> _rejectPlatformFeePayment(AdminPaymentItem item) async {
    final controller = TextEditingController();
    final note = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reject payment'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(
            hintText: 'Why is this payment being rejected?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (!mounted || note == null) return;
    if (note.trim().isEmpty) {
      _showMessage('A rejection note is required.');
      return;
    }
    await _submitPlatformFeeReview(
      item: item,
      decision: 'rejected',
      reviewNote: note,
    );
  }

  Future<void> _submitPlatformFeeReview({
    required AdminPaymentItem item,
    required String decision,
    String reviewNote = '',
  }) async {
    setState(() => _submitting = true);
    try {
      await _actionService.reviewPlatformFeePayment(
        paymentId: item.id,
        decision: decision,
        reviewNote: reviewNote,
      );
      if (!mounted) return;
      _showMessage(
        decision == 'confirmed'
            ? 'Platform fee payment confirmed.'
            : 'Platform fee payment rejected.',
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      if (e is FirebaseFunctionsException) {
        _showMessage(_mapPlatformFeeReviewError(e));
      } else {
        _showMessage('Could not review the platform fee payment.');
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _showPlatformFeeProof(String imageUrl) async {
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        insetPadding: const EdgeInsets.all(16),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: InteractiveViewer(
            minScale: 0.7,
            maxScale: 4,
            child: WebSafeImage(imageUrl: imageUrl, fit: BoxFit.contain),
          ),
        ),
      ),
    );
  }

  Future<void> _submitReview({
    required String decision,
    String reviewNote = '',
  }) async {
    setState(() => _submitting = true);
    try {
      await _actionService.reviewSalon(
        salonId: widget.salonId,
        decision: decision,
        reviewNote: reviewNote,
      );
      if (!mounted) return;
      _showMessage(
        decision == 'verified'
            ? 'Salon verified successfully.'
            : 'Salon rejected successfully.',
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Action failed: $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _submitRestriction({
    required bool restricted,
    String reason = '',
  }) async {
    setState(() => _submitting = true);
    try {
      await _actionService.setSalonRestriction(
        salonId: widget.salonId,
        restricted: restricted,
        reason: reason,
      );
      if (!mounted) return;
      _showMessage(
        restricted
            ? 'Salon restricted successfully.'
            : 'Salon allowed successfully.',
      );
      _reload();
    } catch (e) {
      if (!mounted) return;
      _showMessage('Action failed: $e');
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _reload() {
    setState(() {
      _future = _service.loadSalonDetail(widget.salonId);
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  String _mapPlatformFeeReviewError(FirebaseFunctionsException error) {
    return switch (error.code) {
      'not-found' =>
        'This admin app is connected to a Firebase project where the payment review function is not deployed yet. Deploy Cloud Functions and try again.',
      'unauthenticated' => 'Please sign in again and retry.',
      'permission-denied' => 'Your account does not have superadmin access.',
      'invalid-argument' =>
        error.message ?? 'The payment review request is invalid.',
      'internal' =>
        'The server hit an internal error while reviewing this payment. Please try again.',
      _ => error.message ?? 'Could not review the platform fee payment.',
    };
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
  });

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF475569),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminPaymentCard extends StatelessWidget {
  const _AdminPaymentCard({
    required this.item,
    required this.submitting,
    this.onOpenProof,
    this.onConfirm,
    this.onReject,
  });

  final AdminPaymentItem item;
  final bool submitting;
  final VoidCallback? onOpenProof;
  final VoidCallback? onConfirm;
  final VoidCallback? onReject;

  @override
  Widget build(BuildContext context) {
    final status = _paymentStatusStyle(item.status);
    final rangeLabel = (item.rangeStart != null && item.rangeEnd != null)
        ? '${_formatDate(item.rangeStart)} to ${_formatDate(item.rangeEnd)}'
        : 'Range unavailable';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onOpenProof,
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: item.proofImageUrl.isEmpty
                      ? const Icon(
                          Icons.image_not_supported_outlined,
                          color: Color(0xFF64748B),
                        )
                      : WebSafeImage(
                          imageUrl: item.proofImageUrl,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            '৳${item.amount} • ${item.paymentMethod}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        _StatusChip(
                          label: status.label,
                          foreground: status.foreground,
                          background: status.background,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Submitted: ${_formatDate(item.date)}',
                      style: const TextStyle(
                        color: Color(0xFF475569),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Txn ID: ${item.transactionId.isEmpty ? 'Unavailable' : item.transactionId}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      rangeLabel,
                      style: const TextStyle(color: Color(0xFF64748B)),
                    ),
                    if (item.note.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        item.note,
                        style: const TextStyle(color: Color(0xFF475569)),
                      ),
                    ],
                    if (item.reviewNote.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Review note: ${item.reviewNote}',
                        style: const TextStyle(
                          color: Color(0xFF9A3412),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (item.reviewedAt != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        'Reviewed: ${_formatDate(item.reviewedAt)}',
                        style: const TextStyle(color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (onOpenProof != null) ...[
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: onOpenProof,
              icon: const Icon(Icons.open_in_full_rounded),
              label: const Text('Open proof screenshot'),
            ),
          ],
          if (item.isPending) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: submitting ? null : onReject,
                    icon: const Icon(Icons.close_rounded),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: submitting ? null : onConfirm,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(submitting ? 'Submitting...' : 'Confirm'),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                color: Color(0xFF475569),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'Unavailable' : value,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailPill extends StatelessWidget {
  const _DetailPill({
    required this.title,
    required this.value,
  });

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EEEB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$title: $value',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    this.foreground,
    this.background,
  });

  final String label;
  final Color? foreground;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final color = foreground ??
        switch (label) {
          'verified' => const Color(0xFF166534),
          'rejected' => const Color(0xFF991B1B),
          _ => const Color(0xFF854D0E),
        };
    final fill = background ??
        switch (label) {
          'verified' => const Color(0xFFDCFCE7),
          'rejected' => const Color(0xFFFEE2E2),
          _ => const Color(0xFFFEF3C7),
        };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

_PaymentStatusStyle _paymentStatusStyle(String status) {
  switch (status) {
    case 'confirmed':
    case 'paid':
      return const _PaymentStatusStyle(
        label: 'confirmed',
        foreground: Color(0xFF166534),
        background: Color(0xFFDCFCE7),
      );
    case 'rejected':
      return const _PaymentStatusStyle(
        label: 'rejected',
        foreground: Color(0xFF991B1B),
        background: Color(0xFFFEE2E2),
      );
    default:
      return const _PaymentStatusStyle(
        label: 'pending',
        foreground: Color(0xFF854D0E),
        background: Color(0xFFFEF3C7),
      );
  }
}

class _PaymentStatusStyle {
  const _PaymentStatusStyle({
    required this.label,
    required this.foreground,
    required this.background,
  });

  final String label;
  final Color foreground;
  final Color background;
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Unknown';
  final mm = value.month.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  return '${value.year}-$mm-$dd';
}
