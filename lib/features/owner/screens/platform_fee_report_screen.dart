import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/platform_fee_report_provider.dart';
import 'package:cutline/features/owner/screens/platform_fee_payment_screen.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PlatformFeeReportScreen extends StatelessWidget {
  const PlatformFeeReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider = PlatformFeeReportProvider(
          authProvider: context.read<AuthProvider>(),
        );
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<PlatformFeeReportProvider>();
        final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
        final readyAmount = provider.summary.availableToSubmitFee;
        final pendingAmount = provider.summary.pendingReviewFee;

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              'Platform Fee',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w700,
              ),
            ),
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            foregroundColor: Colors.black,
            elevation: 0,
          ),
          body: provider.isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.black),
                )
              : RefreshIndicator(
                  color: Colors.black,
                  backgroundColor: Colors.white,
                  onRefresh: () => provider.load(),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _DueSummaryCard(
                        due: currency.format(provider.summary.dueFee),
                        paid: currency.format(provider.summary.paidFee),
                        pendingReview:
                            currency.format(provider.summary.pendingReviewFee),
                        readyToSubmit: currency.format(readyAmount),
                        isSubmitting: provider.isSubmitting,
                        hasReadyToSubmit: readyAmount > 0,
                        onPayTap: readyAmount > 0
                            ? () => _openPaymentScreen(
                                  context,
                                  provider,
                                  dueAmount: readyAmount,
                                  totalDueAmount: provider.summary.dueFee,
                                  pendingReviewAmount: pendingAmount,
                                  unpaidCount: provider.ledger
                                      .where(
                                        (item) => item.remainingAmount > 0,
                                      )
                                      .length,
                                )
                            : null,
                      ),
                      if (provider.error != null) ...[
                        const SizedBox(height: 12),
                        _InlineMessageCard(message: provider.error!),
                      ],
                      const SizedBox(height: 24),
                      _ExpandableSection(
                        key: const ValueKey('payment-history-section'),
                        title: 'Payment history',
                        subtitle:
                            'Submitted payments and admin review updates appear here.',
                        trailing: provider.payments.isEmpty
                            ? '0'
                            : '${provider.payments.length}',
                        child: provider.payments.isEmpty
                            ? const _EmptyCard(
                                title: 'No payment has been submitted yet',
                                message:
                                    'After you submit a bKash payment, it will appear here.',
                              )
                            : Column(
                                children: provider.payments
                                    .map(
                                      (item) => _PaymentHistoryCard(item: item),
                                    )
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 14),
                      _ExpandableSection(
                        key: const ValueKey('fee-ledger-section'),
                        title: 'Fee ledger',
                        subtitle:
                            'Each completed booking creates one fee entry here.',
                        trailing: provider.ledger.isEmpty
                            ? '0'
                            : '${provider.ledger.length}',
                        child: provider.ledger.isEmpty
                            ? const _EmptyCard(
                                title: 'No fee ledger is available yet',
                                message:
                                    'Platform fee entries will appear here after completed bookings.',
                              )
                            : Column(
                                children: provider.ledger
                                    .map(
                                      (item) => _LedgerCard(
                                        item: item,
                                        pendingAllocated:
                                            provider.pendingAmountForLedger(
                                          item.id,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<void> _openPaymentScreen(
    BuildContext context,
    PlatformFeeReportProvider provider, {
    required int dueAmount,
    required int totalDueAmount,
    required int pendingReviewAmount,
    required int unpaidCount,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlatformFeePaymentScreen(
          provider: provider,
          readyToSubmitAmount: dueAmount,
          totalDueAmount: totalDueAmount,
          pendingReviewAmount: pendingReviewAmount,
          unpaidCount: unpaidCount,
        ),
      ),
    );

    if (!context.mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Payment submitted for verification.'),
        ),
      );
    }
  }
}

class _DueSummaryCard extends StatelessWidget {
  const _DueSummaryCard({
    required this.due,
    required this.paid,
    required this.pendingReview,
    required this.readyToSubmit,
    required this.isSubmitting,
    required this.hasReadyToSubmit,
    this.onPayTap,
  });

  final String due;
  final String paid;
  final String pendingReview;
  final String readyToSubmit;
  final bool isSubmitting;
  final bool hasReadyToSubmit;
  final VoidCallback? onPayTap;

  @override
  Widget build(BuildContext context) {
    final buttonLabel =
        hasReadyToSubmit ? 'Pay due fee' : 'No new payment is needed right now';
    final helperText = hasReadyToSubmit
        ? 'Send the payment with bKash Personal, then submit the TrxID and screenshot.'
        : 'There is no new amount ready to submit. If anything is pending review, wait for admin approval.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Outstanding Platform Fee',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            due,
            style: const TextStyle(
              fontSize: 38,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            helperText,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  label: 'Paid',
                  value: paid,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Pending review',
                  value: pendingReview,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Ready',
                  value: readyToSubmit,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasReadyToSubmit && !isSubmitting ? onPayTap : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
              ),
              child: Text(
                isSubmitting ? 'Please wait...' : buttonLabel,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMessageCard extends StatelessWidget {
  const _InlineMessageCard({
    required this.message,
  });

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: _panelDecoration(radius: 20),
      child: Text(
        message,
        style: const TextStyle(
          fontSize: 13,
          height: 1.45,
          color: Colors.black87,
        ),
      ),
    );
  }
}

class _ExpandableSection extends StatefulWidget {
  const _ExpandableSection({
    super.key,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.child,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final Widget child;

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: _panelDecoration(radius: 22),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(22),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.subtitle,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: const Color(0xFFD1D5DB)),
                    ),
                    child: Text(
                      widget.trailing,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    _expanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: Colors.black,
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 180),
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
              child: Column(
                children: [
                  const Divider(height: 1, color: Color(0xFFE5E7EB)),
                  const SizedBox(height: 16),
                  widget.child,
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaymentHistoryCard extends StatelessWidget {
  const _PaymentHistoryCard({
    required this.item,
  });

  final PlatformFeePaymentItem item;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy').format(item.paidAt);
    final period = (item.rangeStart != null && item.rangeEnd != null)
        ? '${DateFormat('dd MMM').format(item.rangeStart!)} - ${DateFormat('dd MMM').format(item.rangeEnd!)}'
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '৳${item.amount}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$date • ${item.method}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(label: _paymentStatusLabel(item.status)),
            ],
          ),
          const SizedBox(height: 14),
          _InfoLine(label: 'TrxID', value: item.transactionId),
          const SizedBox(height: 8),
          _InfoLine(label: 'Covered period', value: period),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoLine(label: 'Note', value: item.note),
          ],
          if (item.reviewNote.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoLine(label: 'Admin note', value: item.reviewNote),
          ],
        ],
      ),
    );
  }
}

class _LedgerCard extends StatelessWidget {
  const _LedgerCard({
    required this.item,
    required this.pendingAllocated,
  });

  final PlatformFeeLedgerItem item;
  final int pendingAllocated;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy').format(item.date);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking ${item.bookingId}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      date,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              _StatusChip(
                label: _ledgerStatusLabel(
                  paidAmount: item.paidAmount,
                  totalAmount: item.amount,
                  pendingAllocated: pendingAllocated,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniAmount(
                  label: 'Fee',
                  value: '৳${item.amount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniAmount(
                  label: 'Paid',
                  value: '৳${item.paidAmount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniAmount(
                  label: 'Due',
                  value: '৳${item.remainingAmount}',
                ),
              ),
            ],
          ),
          if (pendingAllocated > 0) ...[
            const SizedBox(height: 10),
            Text(
              '৳$pendingAllocated from this entry is still under review.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF4B5563),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniAmount extends StatelessWidget {
  const _MiniAmount({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final displayValue = value.isEmpty ? 'N/A' : value;

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          fontSize: 13,
          height: 1.45,
          color: Color(0xFF4B5563),
        ),
        children: [
          TextSpan(
            text: '$label: ',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          TextSpan(text: displayValue),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

String _paymentStatusLabel(String status) {
  switch (status) {
    case 'confirmed':
    case 'paid':
      return 'Confirmed';
    case 'rejected':
      return 'Rejected';
    default:
      return 'Pending';
  }
}

String _ledgerStatusLabel({
  required int paidAmount,
  required int totalAmount,
  required int pendingAllocated,
}) {
  if (pendingAllocated > 0) {
    return 'Pending';
  }
  if (paidAmount >= totalAmount && totalAmount > 0) {
    return 'Paid';
  }
  if (paidAmount > 0) {
    return 'Partial';
  }
  return 'Due';
}

BoxDecoration _panelDecoration({double radius = 28}) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: const Color(0xFFE5E7EB)),
    boxShadow: const [
      BoxShadow(
        color: Color(0x05000000),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
  );
}
