import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';

import 'package:cutline/features/admin/models/admin_models.dart';
import 'package:cutline/features/admin/services/admin_action_service.dart';
import 'package:cutline/features/admin/services/admin_service.dart';
import 'package:cutline/features/admin/widgets/admin_ui.dart';
import 'package:cutline/routes/admin_router.dart';

class PlatformFeePaymentsTab extends StatefulWidget {
  const PlatformFeePaymentsTab({super.key});

  @override
  State<PlatformFeePaymentsTab> createState() => _PlatformFeePaymentsTabState();
}

class _PlatformFeePaymentsTabState extends State<PlatformFeePaymentsTab> {
  final AdminService _service = AdminService();
  final AdminActionService _actionService = AdminActionService();
  late Future<List<AdminPaymentItem>> _future;
  String? _reviewingPaymentId;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<AdminPaymentItem>> _load() {
    return _service.loadPendingPlatformFeePayments(limit: 200);
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _reload,
      child: FutureBuilder<List<AdminPaymentItem>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 120),
              children: [
                const AdminEmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Payments could not load',
                  message: 'Pull to refresh or check your internet connection.',
                ),
              ],
            );
          }

          final payments = snapshot.data ?? const <AdminPaymentItem>[];
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            children: [
              AdminPanel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AdminSectionHeading(
                      eyebrow: 'Payment Queue',
                      title: 'Pending fee payments',
                      subtitle:
                          'Review all owner platform fee submissions from one place.',
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        AdminStatusBadge(
                          label: '${payments.length} waiting review',
                          icon: Icons.schedule_rounded,
                        ),
                        const AdminStatusBadge(
                          label: 'Approve or reject from here',
                          icon: Icons.fact_check_outlined,
                          backgroundColor: Color(0xFFEAF1EE),
                          foregroundColor: Color(0xFF425A53),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (payments.isEmpty)
                const AdminEmptyState(
                  icon: Icons.verified_outlined,
                  title: 'No payment is waiting',
                  message:
                      'New platform fee submissions will appear here automatically.',
                )
              else
                ...payments.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _PlatformFeePaymentActionTile(
                      item: item,
                      submitting: _reviewingPaymentId == item.id,
                      onOpenSalon: () => Navigator.of(context).pushNamed(
                        AdminRoutes.salonReview,
                        arguments: item.salonId,
                      ),
                      onOpenProof: item.proofImageUrl.isEmpty
                          ? null
                          : () => _showPlatformFeeProof(item.proofImageUrl),
                      onConfirm: () => _confirmPlatformFeePayment(item),
                      onReject: () => _rejectPlatformFeePayment(item),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmPlatformFeePayment(AdminPaymentItem item) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Confirm payment'),
            content: Text(
              'Confirm ${formatAdminCurrency(item.amount)} from ${item.salonName.isEmpty ? item.salonId : item.salonName}?',
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
    setState(() => _reviewingPaymentId = item.id);
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
      await _reload();
    } catch (e) {
      if (!mounted) return;
      if (e is FirebaseFunctionsException) {
        _showMessage(_mapPlatformFeeReviewError(e));
      } else {
        _showMessage('Could not review the platform fee payment.');
      }
    } finally {
      if (mounted) {
        setState(() => _reviewingPaymentId = null);
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
            child: CachedNetworkImage(
              imageUrl: imageUrl,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
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

class _PlatformFeePaymentActionTile extends StatelessWidget {
  const _PlatformFeePaymentActionTile({
    required this.item,
    required this.submitting,
    required this.onOpenSalon,
    required this.onConfirm,
    required this.onReject,
    this.onOpenProof,
  });

  final AdminPaymentItem item;
  final bool submitting;
  final VoidCallback onOpenSalon;
  final VoidCallback onConfirm;
  final VoidCallback onReject;
  final VoidCallback? onOpenProof;

  @override
  Widget build(BuildContext context) {
    final salonLabel = item.salonName.isEmpty ? item.salonId : item.salonName;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF6FAF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFDDE6E0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8EEF9),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.payments_outlined,
                    color: Color(0xFF1D4ED8),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            salonLabel,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const AdminStatusBadge(
                            label: 'Pending',
                            backgroundColor: Color(0xFFE6F2EE),
                            foregroundColor: Color(0xFF0C5C51),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${formatAdminCurrency(item.amount)} • ${item.paymentMethod}',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFF10261D),
                            ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.transactionId.isEmpty
                            ? 'TrxID missing'
                            : 'TrxID: ${item.transactionId}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFF5D6F68),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                AdminStatusBadge(
                  label: formatAdminDateTime(item.date),
                  icon: Icons.schedule_rounded,
                  backgroundColor: const Color(0xFFEAF1EE),
                  foregroundColor: const Color(0xFF425A53),
                ),
              ],
            ),
            if (item.note.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                item.note,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D6F68),
                      height: 1.4,
                    ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: submitting ? null : onOpenSalon,
                    icon: const Icon(Icons.storefront_outlined),
                    label: const Text('Open salon'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: submitting ? null : onOpenProof,
                    icon: const Icon(Icons.image_outlined),
                    label: Text(
                      onOpenProof == null ? 'No proof' : 'View proof',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: submitting ? null : onReject,
                    icon: const Icon(Icons.close),
                    label: const Text('Reject'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: submitting ? null : onConfirm,
                    icon: submitting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check),
                    label: Text(submitting ? 'Working...' : 'Approve'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
