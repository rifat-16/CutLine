import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/barber/providers/barber_tips_provider.dart';
import 'package:cutline/shared/models/barber_tip_models.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class BarberTipsScreen extends StatelessWidget {
  const BarberTipsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider =
            BarberTipsProvider(authProvider: context.read<AuthProvider>());
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<BarberTipsProvider>();
        final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
        final payoutStatusById = {
          for (final item in provider.payouts) item.id: item.status,
        };
        final pendingPayouts =
            provider.payouts.where((item) => !item.isConfirmed).toList();

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              'My Tips',
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
                  onRefresh: provider.load,
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                    children: [
                      _TipsSummaryCard(
                        total: currency.format(provider.summary.totalTips),
                        outstanding:
                            currency.format(provider.summary.outstandingTips),
                        received:
                            currency.format(provider.summary.receivedTips),
                        awaitingConfirmation: currency.format(
                          provider.summary.pendingConfirmationTips,
                        ),
                        notYetSent:
                            currency.format(provider.summary.notYetSentTips),
                        summary: provider.summary,
                      ),
                      if (provider.error != null) ...[
                        const SizedBox(height: 12),
                        _InlineMessageCard(message: provider.error!),
                      ],
                      const SizedBox(height: 24),
                      if (pendingPayouts.isEmpty)
                        const _InfoBanner(
                          title: 'No payout is waiting for confirmation',
                          message:
                              'When the salon records a payout for you, it will appear here for confirmation.',
                        )
                      else
                        _PendingPayoutSection(
                          payouts: pendingPayouts,
                          isSubmitting: provider.isSubmitting,
                          onConfirm: (payoutId) async {
                            final ok = await _confirmPayout(
                              context,
                              provider,
                              payoutId,
                            );
                            if (!context.mounted || !ok) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Payout confirmed.'),
                              ),
                            );
                          },
                        ),
                      const SizedBox(height: 14),
                      _ExpandableSection(
                        key: const ValueKey('barber-payout-history-section'),
                        title: 'Payout history',
                        subtitle:
                            'All payout records from the salon appear here.',
                        trailing: '${provider.payouts.length}',
                        child: provider.payouts.isEmpty
                            ? const _EmptyCard(
                                title: 'No payout history yet',
                                message:
                                    'Your confirmed and pending payouts will appear here.',
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
                        key: const ValueKey('barber-tip-ledger-section'),
                        title: 'Tip ledger',
                        subtitle: 'Each completed booking tip is tracked here.',
                        trailing: '${provider.ledger.length}',
                        child: provider.ledger.isEmpty
                            ? const _EmptyCard(
                                title: 'No tip ledger yet',
                                message:
                                    'Tips from completed bookings will appear here automatically.',
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

  Future<bool> _confirmPayout(
    BuildContext context,
    BarberTipsProvider provider,
    String payoutId,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm payout'),
        content: const Text(
          'Confirm only after you have received this payout from the salon.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
            ),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    return provider.confirmPayout(payoutId);
  }
}

class _TipsSummaryCard extends StatelessWidget {
  const _TipsSummaryCard({
    required this.total,
    required this.outstanding,
    required this.received,
    required this.awaitingConfirmation,
    required this.notYetSent,
    required this.summary,
  });

  final String total;
  final String outstanding;
  final String received;
  final String awaitingConfirmation;
  final String notYetSent;
  final BarberTipSummary summary;

  @override
  Widget build(BuildContext context) {
    final helperText = summary.outstandingTips == 0
        ? 'All recorded tips have already been received.'
        : summary.pendingConfirmationTips > 0
            ? 'Some of this amount has already been recorded by the salon and is waiting for your confirmation.'
            : 'This is the remaining amount the salon still needs to pay you.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tips to receive',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            outstanding,
            style: const TextStyle(
              fontSize: 38,
              height: 1,
              fontWeight: FontWeight.w800,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            helperText,
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: Color(0xFF4B5563),
            ),
          ),
          const SizedBox(height: 16),
          _SummaryStrip(
            label: 'Total tips earned',
            value: total,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 10.0;
              final halfWidth = (constraints.maxWidth - gap) / 2;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  SizedBox(
                    width: halfWidth,
                    child: _StatCard(
                      label: 'Received',
                      value: received,
                    ),
                  ),
                  SizedBox(
                    width: halfWidth,
                    child: _StatCard(
                      label: 'Pending confirm',
                      value: awaitingConfirmation,
                    ),
                  ),
                  SizedBox(
                    width: constraints.maxWidth,
                    child: _StatCard(
                      label: 'Not sent yet',
                      value: notYetSent,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
            ),
          ),
          const Spacer(),
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

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 84),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PendingPayoutSection extends StatelessWidget {
  const _PendingPayoutSection({
    required this.payouts,
    required this.isSubmitting,
    required this.onConfirm,
  });

  final List<BarberPayoutItem> payouts;
  final bool isSubmitting;
  final Future<void> Function(String payoutId) onConfirm;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(radius: 22),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Confirm received payout',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Confirm only after the salon has handed over the amount to you.',
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 16),
          ...payouts.map(
            (item) => _PendingPayoutCard(
              item: item,
              isSubmitting: isSubmitting,
              onConfirm: () => onConfirm(item.id),
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPayoutCard extends StatelessWidget {
  const _PendingPayoutCard({
    required this.item,
    required this.isSubmitting,
    required this.onConfirm,
  });

  final BarberPayoutItem item;
  final bool isSubmitting;
  final VoidCallback onConfirm;

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
                        fontSize: 24,
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
              const _StatusChip(label: 'Pending'),
            ],
          ),
          const SizedBox(height: 14),
          _InfoLine(label: 'Covered period', value: period),
          if (item.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            _InfoLine(label: 'Note', value: item.note),
          ],
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSubmitting ? null : onConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFE5E7EB),
                disabledForegroundColor: const Color(0xFF9CA3AF),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(
                isSubmitting ? 'Please wait...' : 'Confirm received',
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
              _StatusChip(label: item.isConfirmed ? 'Confirmed' : 'Pending'),
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
                  label: 'Recorded',
                  value: '৳${item.paidAmount}',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _MiniAmount(
                  label: 'Remaining',
                  value: '৳${item.remainingAmount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            status.message,
            style: const TextStyle(
              fontSize: 13,
              height: 1.45,
              color: Color(0xFF4B5563),
            ),
          ),
        ],
      ),
    );
  }
}

class _LedgerStatusPresentation {
  const _LedgerStatusPresentation({
    required this.label,
    required this.message,
  });

  final String label;
  final String message;
}

_LedgerStatusPresentation _resolveLedgerStatus(
  BarberTipLedgerItem item,
  Map<String, String> payoutStatusById,
) {
  var effectiveStatus = item.status;
  if (item.status == 'pending') {
    final payoutStatus = payoutStatusById[item.payoutId];
    if (payoutStatus == 'confirmed' || payoutStatus == 'paid') {
      if (item.paidAmount >= item.tipAmount) {
        effectiveStatus = 'paid';
      } else if (item.paidAmount > 0) {
        effectiveStatus = 'partial';
      } else {
        effectiveStatus = 'unpaid';
      }
    } else {
      effectiveStatus = 'pending';
    }
  }

  if (effectiveStatus == 'paid') {
    return const _LedgerStatusPresentation(
      label: 'Paid',
      message: 'This tip has been fully received.',
    );
  }
  if (effectiveStatus == 'partial') {
    return const _LedgerStatusPresentation(
      label: 'Partial',
      message: 'A part of this tip has already been received.',
    );
  }
  if (effectiveStatus == 'pending') {
    return const _LedgerStatusPresentation(
      label: 'Pending',
      message:
          'The latest recorded payout for this tip is waiting for your confirmation.',
    );
  }
  return const _LedgerStatusPresentation(
    label: 'Unpaid',
    message: 'The salon has not recorded a payout for this tip yet.',
  );
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: _panelDecoration(radius: 22),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
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
      padding: const EdgeInsets.all(18),
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

class _MiniAmount extends StatelessWidget {
  const _MiniAmount({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 76),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFDA29B)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 1),
            child: Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: Color(0xFFB42318),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: Color(0xFFB42318),
                fontWeight: FontWeight.w600,
              ),
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
        color: Color(0x08000000),
        blurRadius: 24,
        offset: Offset(0, 10),
      ),
    ],
  );
}
