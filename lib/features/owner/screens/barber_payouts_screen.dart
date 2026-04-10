import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/barber_payouts_provider.dart';
import 'package:cutline/features/owner/screens/barber_payout_detail_screen.dart';

class OwnerBarberPayoutsScreen extends StatelessWidget {
  const OwnerBarberPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider = OwnerBarberPayoutsProvider(
          authProvider: context.read<AuthProvider>(),
        );
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<OwnerBarberPayoutsProvider>();
        final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
        final paidTips =
            provider.barbers.fold<int>(0, (acc, item) => acc + item.paidTips);
        final pendingTips = provider.barbers.fold<int>(
          0,
          (acc, item) => acc + item.pendingTips,
        );
        final readyTips = provider.barbers.fold<int>(
          0,
          (acc, item) => acc + item.readyToPayTips,
        );
        final dueTips =
            provider.barbers.fold<int>(0, (acc, item) => acc + item.dueTips);
        final readyBarbers = provider.barbers
            .where((item) => item.readyToPayTips > 0)
            .toList(growable: false);

        return Scaffold(
          backgroundColor: Colors.white,
          appBar: AppBar(
            title: const Text(
              'Barber Payouts',
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
                      _OverviewCard(
                        due: currency.format(dueTips),
                        paid: currency.format(paidTips),
                        pending: currency.format(pendingTips),
                        ready: currency.format(readyTips),
                        barberCount: provider.barbers.length,
                        readyCount: readyBarbers.length,
                      ),
                      if (provider.error != null) ...[
                        const SizedBox(height: 12),
                        _InlineMessageCard(message: provider.error!),
                      ],
                      const SizedBox(height: 24),
                      _ExpandableSection(
                        key: const ValueKey('ready-barbers-section'),
                        title: 'Ready to pay',
                        subtitle:
                            'Barbers with tip balances that are ready to record now.',
                        trailing: '${readyBarbers.length}',
                        initiallyExpanded: true,
                        child: readyBarbers.isEmpty
                            ? const _EmptyCard(
                                title: 'No barber is ready to pay right now',
                                message:
                                    'If any payout is pending, wait for that to clear. New tip balances will appear here automatically.',
                              )
                            : Column(
                                children: readyBarbers
                                    .map(
                                      (barber) => _BarberOverviewCard(
                                        barber: barber,
                                        onTap: () => _openBarberDetail(
                                          context,
                                          barber,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 14),
                      _ExpandableSection(
                        key: const ValueKey('all-barbers-section'),
                        title: 'All barbers',
                        subtitle:
                            'Open a barber to review payout history and tip ledger.',
                        trailing: '${provider.barbers.length}',
                        child: provider.barbers.isEmpty
                            ? const _EmptyCard(
                                title: 'No barber payout data is available yet',
                                message:
                                    'Tip entries will appear here after completed bookings with barber tips.',
                              )
                            : Column(
                                children: provider.barbers
                                    .map(
                                      (barber) => _BarberOverviewCard(
                                        barber: barber,
                                        onTap: () => _openBarberDetail(
                                          context,
                                          barber,
                                        ),
                                      ),
                                    )
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: 14),
                      _InfoPanel(
                        title: 'How this works',
                        message:
                            'Open a barber to review each tip entry, check pending payouts, and record the next payout after the amount is handed over.',
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  void _openBarberDetail(
    BuildContext context,
    BarberPayoutOverview barber,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => OwnerBarberPayoutDetailScreen(
          barberId: barber.barberId,
          barberName: barber.barberName,
        ),
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({
    required this.due,
    required this.paid,
    required this.pending,
    required this.ready,
    required this.barberCount,
    required this.readyCount,
  });

  final String due;
  final String paid;
  final String pending;
  final String ready;
  final int barberCount;
  final int readyCount;

  @override
  Widget build(BuildContext context) {
    final helperText = readyCount > 0
        ? '$readyCount barbers currently have payout balances ready to record.'
        : 'No barber payout is ready to record right now.';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: _panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Barber payout overview',
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
          const SizedBox(height: 10),
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
          const SizedBox(height: 14),
          Text(
            '$barberCount barbers are included in this payout report.',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF4B5563),
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
    this.initiallyExpanded = false,
  });

  final String title;
  final String subtitle;
  final String trailing;
  final Widget child;
  final bool initiallyExpanded;

  @override
  State<_ExpandableSection> createState() => _ExpandableSectionState();
}

class _ExpandableSectionState extends State<_ExpandableSection> {
  late bool _expanded;

  @override
  void initState() {
    super.initState();
    _expanded = widget.initiallyExpanded;
  }

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

class _BarberOverviewCard extends StatelessWidget {
  const _BarberOverviewCard({
    required this.barber,
    required this.onTap,
  });

  final BarberPayoutOverview barber;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final status = _barberStatus(barber);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                            barber.barberName,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            barber.readyToPayTips > 0
                                ? 'Open this barber to record the next payout.'
                                : barber.pendingTips > 0
                                    ? 'This barber has a payout waiting to clear.'
                                    : 'All recorded barber tip payouts are up to date.',
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Color(0xFF6B7280),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StatusChip(label: status),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _MiniAmount(
                        label: 'Total',
                        value: '৳${barber.totalTips}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniAmount(
                        label: 'Paid',
                        value: '৳${barber.paidTips}',
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _MiniAmount(
                        label: 'Due',
                        value: '৳${barber.dueTips}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  _barberHint(barber),
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF4B5563),
                  ),
                ),
              ],
            ),
          ),
        ),
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

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({
    required this.title,
    required this.message,
  });

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: _panelDecoration(radius: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
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

String _barberStatus(BarberPayoutOverview barber) {
  if (barber.readyToPayTips > 0) return 'Ready to pay';
  if (barber.pendingTips > 0) return 'Pending';
  return 'Clear';
}

String _barberHint(BarberPayoutOverview barber) {
  if (barber.readyToPayTips > 0 && barber.pendingTips > 0) {
    return 'Ready now: ৳${barber.readyToPayTips} • Pending: ৳${barber.pendingTips}';
  }
  if (barber.readyToPayTips > 0) {
    return 'Ready to pay now: ৳${barber.readyToPayTips}';
  }
  if (barber.pendingTips > 0) {
    return 'Pending confirmation: ৳${barber.pendingTips}';
  }
  return 'No due payout remains for this barber.';
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
