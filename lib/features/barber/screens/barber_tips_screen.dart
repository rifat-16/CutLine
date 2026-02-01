import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/barber/providers/barber_tips_provider.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
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
        return Scaffold(
          backgroundColor: CutlineColors.secondaryBackground,
          appBar: AppBar(
            title: const Text('My tips'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => provider.load(),
                  child: ListView(
                    padding: CutlineSpacing.section.copyWith(bottom: 32),
                    children: [
                      const SizedBox(height: 16),
                      _SummaryCard(
                        total: currency.format(provider.summary.totalTips),
                        paid: currency.format(provider.summary.paidTips),
                        due: currency.format(provider.summary.dueTips),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'Payout history',
                        subtitle: provider.payouts.isEmpty
                            ? 'No payouts yet'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      ...provider.payouts.map((item) {
                        final date =
                            DateFormat('dd MMM yyyy').format(item.paidAt);
                        final range = (item.rangeStart != null &&
                                item.rangeEnd != null)
                            ? '${DateFormat('dd MMM').format(item.rangeStart!)}'
                                ' - ${DateFormat('dd MMM').format(item.rangeEnd!)}'
                            : '—';
                        final method =
                            item.method.isNotEmpty ? item.method : '—';
                        final statusLabel =
                            item.isConfirmed ? 'Confirmed' : 'Pending';
                        final statusColor = item.isConfirmed
                            ? const Color(0xFF10B981)
                            : const Color(0xFFF59E0B);
                        if (!item.isConfirmed) {
                          return _PendingPayoutTile(
                            title: currency.format(item.amount),
                            subtitle: date,
                            statusLabel: statusLabel,
                            statusColor: statusColor,
                            detail: 'Range: $range • $method',
                            isSubmitting: provider.isSubmitting,
                            onConfirm: () async {
                              final ok = await _confirmPayout(
                                  context, provider, item.id);
                              if (!context.mounted) return;
                              if (ok) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text('Payout confirmed.')),
                                );
                              }
                            },
                          );
                        }
                        return _HistoryTile(
                          title: currency.format(item.amount),
                          subtitle: date,
                          statusLabel: statusLabel,
                          statusColor: statusColor,
                          detail: 'Range: $range • $method',
                        );
                      }),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'Tip ledger',
                        subtitle: provider.ledger.isEmpty
                            ? 'No ledger entries yet'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      ...provider.ledger.map((item) {
                        final date =
                            DateFormat('dd MMM yyyy').format(item.date);
                        final payoutStatus = payoutStatusById[item.payoutId];
                        final effectiveStatus = item.status == 'pending'
                            ? (payoutStatus == 'confirmed' || payoutStatus == 'paid')
                                ? (item.paidAmount >= item.tipAmount
                                    ? 'paid'
                                    : item.paidAmount > 0
                                        ? 'partial'
                                        : 'unpaid')
                                : 'pending'
                            : item.status;
                        final statusLabel = effectiveStatus == 'paid'
                            ? 'Paid'
                            : effectiveStatus == 'partial'
                                ? 'Partial'
                                : effectiveStatus == 'pending'
                                    ? 'Pending'
                                    : 'Unpaid';
                        final statusColor = effectiveStatus == 'paid'
                            ? const Color(0xFF10B981)
                            : effectiveStatus == 'partial'
                                ? const Color(0xFFF97316)
                                : effectiveStatus == 'pending'
                                    ? const Color(0xFFF59E0B)
                                    : Colors.grey;
                        final detailText = (effectiveStatus == 'partial' ||
                                    effectiveStatus == 'pending') &&
                                item.paidAmount > 0
                            ? 'Booking: ${item.bookingId} • Paid: ৳${item.paidAmount}'
                            : 'Booking: ${item.bookingId}';
                        return _HistoryTile(
                          title: currency.format(item.tipAmount),
                          subtitle: date,
                          statusLabel: statusLabel,
                          statusColor: statusColor,
                          detail: detailText,
                        );
                      }),
                      if (provider.error != null) ...[
                        const SizedBox(height: 12),
                        Text(provider.error!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<bool> _confirmPayout(BuildContext context,
      BarberTipsProvider provider, String payoutId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirm payout'),
        content: const Text(
            'Confirm that you have received this payout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
    if (confirmed != true) return false;
    return provider.confirmPayout(payoutId);
  }
}

class _SummaryCard extends StatelessWidget {
  final String total;
  final String paid;
  final String due;

  const _SummaryCard({
    required this.total,
    required this.paid,
    required this.due,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: CutlineSpacing.card,
      decoration: CutlineDecorations.card(solidColor: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SummaryItem(label: 'Total', value: total),
          _SummaryItem(label: 'Received', value: paid),
          _SummaryItem(label: 'Pending', value: due),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CutlineTextStyles.caption),
        const SizedBox(height: 6),
        Text(value,
            style: CutlineTextStyles.subtitleBold.copyWith(fontSize: 16)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: CutlineTextStyles.subtitleBold),
        if (subtitle != null) Text(subtitle!, style: CutlineTextStyles.caption),
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String detail;
  final String? statusLabel;
  final Color? statusColor;

  const _HistoryTile({
    required this.title,
    required this.subtitle,
    required this.detail,
    this.statusLabel,
    this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.receipt_long_outlined, color: Colors.blueGrey),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    if (statusLabel != null && statusColor != null)
                      _StatusChip(
                        label: statusLabel!,
                        color: statusColor!,
                      ),
                    if (statusLabel != null && statusColor != null)
                      const SizedBox(width: 8),
                    Text(subtitle, style: CutlineTextStyles.caption),
                  ],
                ),
                const SizedBox(height: 4),
                Text(detail, style: CutlineTextStyles.body),
              ],
            ),
          ),
          Text(title, style: CutlineTextStyles.subtitleBold),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;

  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: CutlineTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PendingPayoutTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String detail;
  final bool isSubmitting;
  final VoidCallback onConfirm;
  final String statusLabel;
  final Color statusColor;

  const _PendingPayoutTile({
    required this.title,
    required this.subtitle,
    required this.detail,
    required this.isSubmitting,
    required this.onConfirm,
    required this.statusLabel,
    required this.statusColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusChip(label: statusLabel, color: statusColor),
              const SizedBox(width: 8),
              Text(subtitle, style: CutlineTextStyles.caption),
            ],
          ),
          const SizedBox(height: 4),
          Text(detail, style: CutlineTextStyles.body),
          const SizedBox(height: 10),
              Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(title, style: CutlineTextStyles.subtitleBold),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                onPressed: isSubmitting ? null : onConfirm,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isSubmitting ? Icons.hourglass_top : Icons.check_circle,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(isSubmitting
                        ? 'Confirming...'
                        : 'Confirm received'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
