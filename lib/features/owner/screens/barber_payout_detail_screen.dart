import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/barber_payout_detail_provider.dart';
import 'package:cutline/features/owner/screens/barber_payout_payment_screen.dart';
import 'package:cutline/shared/models/barber_tip_models.dart';

class OwnerBarberPayoutDetailScreen extends StatelessWidget {
  const OwnerBarberPayoutDetailScreen({
    super.key,
    required this.barberId,
    required this.barberName,
  });

  final String barberId;
  final String barberName;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider = BarberPayoutDetailProvider(
          authProvider: context.read<AuthProvider>(),
          barberId: barberId,
          barberName: barberName,
        );
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<BarberPayoutDetailProvider>();
        final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
        final payoutStatusById = {
          for (final item in provider.payouts) item.id: item.status,
        };

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: Text(
              barberName,
              style: const TextStyle(
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
                  onRefresh: provider.load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _PayoutSummaryCard(
                        due: currency.format(provider.summary.dueTips),
                        paid: currency.format(provider.summary.paidTips),
                        pending: currency.format(provider.summary.pendingTips),
                        ready: currency.format(
                          provider.summary.readyToPayTips,
                        ),
                        isSubmitting: provider.isSubmitting,
                        hasReadyToPay: provider.summary.readyToPayTips > 0,
                        onPayTap: provider.summary.readyToPayTips > 0
                            ? () => _openPaymentScreen(
                                  context,
                                  provider,
                                  readyAmount: provider.summary.readyToPayTips,
                                  totalDueAmount: provider.summary.dueTips,
                                  pendingAmount: provider.summary.pendingTips,
                                  unpaidCount: provider.unpaidCount,
                                )
                            : null,
                      ),
                      if (provider.error != null) ...[
                        const SizedBox(height: 12),
                        _InlineMessageCard(message: provider.error!),
                      ],
                      const SizedBox(height: 24),
                      _ExpandableSection(
                        key: const ValueKey('barber-payout-history'),
                        title: 'Payout history',
                        subtitle:
                            'Recorded payouts and their current status appear here.',
                        trailing: '${provider.payouts.length}',
                        child: provider.payouts.isEmpty
                            ? const _EmptyCard(
                                title: 'No payout has been recorded yet',
                                message:
                                    'Once you record a payout for this barber, it will appear here.',
                              )
                            : Column(
                                children: provider.payouts
                                    .map(
                                      (item) => _PayoutHistoryCard(item: item),
                                    )
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 14),
                      _ExpandableSection(
                        key: const ValueKey('barber-tip-ledger'),
                        title: 'Tip ledger',
                        subtitle:
                            'Each tip entry for this barber is tracked here.',
                        trailing: '${provider.ledger.length}',
                        child: provider.ledger.isEmpty
                            ? const _EmptyCard(
                                title: 'No tip ledger is available yet',
                                message:
                                    'Completed bookings with tips will appear here automatically.',
                              )
                            : Column(
                                children: provider.ledger
                                    .map(
                                      (item) => _TipLedgerCard(
                                        item: item,
                                        statusByPayoutId: payoutStatusById,
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
    BarberPayoutDetailProvider provider, {
    required int readyAmount,
    required int totalDueAmount,
    required int pendingAmount,
    required int unpaidCount,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BarberPayoutPaymentScreen(
          provider: provider,
          barberName: barberName,
          readyToPayAmount: readyAmount,
          totalDueAmount: totalDueAmount,
          pendingAmount: pendingAmount,
          unpaidCount: unpaidCount,
        ),
      ),
    );

    if (!context.mounted) return;
    if (result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Payout recorded.')),
      );
    }
  }
}

class _PayoutSummaryCard extends StatelessWidget {
  const _PayoutSummaryCard({
    required this.due,
    required this.paid,
    required this.pending,
    required this.ready,
    required this.isSubmitting,
    required this.hasReadyToPay,
    this.onPayTap,
  });

  final String due;
  final String paid;
  final String pending;
  final String ready;
  final bool isSubmitting;
  final bool hasReadyToPay;
  final VoidCallback? onPayTap;

  @override
  Widget build(BuildContext context) {
    final buttonLabel =
        hasReadyToPay ? 'Pay due tips' : 'No new payout is needed right now';
    final helperText = hasReadyToPay
        ? 'Record the payout after the amount is handed over to the barber.'
        : 'No new amount is ready to pay. If anything is pending, wait for that payout to clear first.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Outstanding barber payout',
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
                  label: 'Pending',
                  value: pending,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatCard(
                  label: 'Ready',
                  value: ready,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hasReadyToPay && !isSubmitting ? onPayTap : null,
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

class _PayoutHistoryCard extends StatelessWidget {
  const _PayoutHistoryCard({
    required this.item,
  });

  final BarberPayoutItem item;

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
              _StatusChip(
                label: item.isConfirmed ? 'Confirmed' : 'Pending',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _InfoLine(label: 'Covered period', value: period),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoLine(label: 'Note', value: item.note),
          ],
        ],
      ),
    );
  }
}

class _TipLedgerCard extends StatelessWidget {
  const _TipLedgerCard({
    required this.item,
    required this.statusByPayoutId,
  });

  final BarberTipLedgerItem item;
  final Map<String, String> statusByPayoutId;

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('dd MMM yyyy').format(item.date);
    final status = _resolveLedgerStatus(item, statusByPayoutId);

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
              _StatusChip(label: status.label),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _MiniAmount(
                  label: 'Tip',
                  value: '৳${item.tipAmount}',
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
          if (status.pendingAllocated > 0) ...[
            const SizedBox(height: 10),
            Text(
              '৳${status.pendingAllocated} from this entry is still pending.',
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

class _LedgerStatusPresentation {
  const _LedgerStatusPresentation({
    required this.label,
    required this.pendingAllocated,
  });

  final String label;
  final int pendingAllocated;
}

_LedgerStatusPresentation _resolveLedgerStatus(
  BarberTipLedgerItem item,
  Map<String, String> payoutStatusById,
) {
  var effectiveStatus = item.status;
  if (item.status == 'pending') {
    final payoutStatus = payoutStatusById[item.payoutId];
    if (payoutStatus == 'confirmed' || payoutStatus == 'paid') {
      effectiveStatus = item.paidAmount >= item.tipAmount
          ? 'paid'
          : item.paidAmount > 0
              ? 'partial'
              : 'unpaid';
    } else {
      effectiveStatus = 'pending';
    }
  }

  final label = switch (effectiveStatus) {
    'paid' => 'Paid',
    'partial' => 'Partial',
    'pending' => 'Pending',
    _ => 'Unpaid',
  };

  return _LedgerStatusPresentation(
    label: label,
    pendingAllocated: effectiveStatus == 'pending' ? item.paidAmount : 0,
  );
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

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFD1D5DB)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: Colors.black,
        ),
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

BoxDecoration _panelDecoration({double radius = 24}) {
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
