import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/dashboard_provider.dart';
import 'package:cutline/features/owner/providers/dashboard_period.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class OwnerDashboardScreen extends StatelessWidget {
  const OwnerDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final auth = context.read<AuthProvider>();
        final provider = DashboardProvider(authProvider: auth);
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<DashboardProvider>();
        final metrics = provider.metrics;
        final bookingCounts = provider.bookingStatusCounts;
        final queueCounts = provider.queueStatusCounts;
        final services = provider.services;
        final barbers = provider.barbers;
        final bookings = provider.bookings.take(5).toList();
        final nowLabel = DateFormat('EEE, d MMM • h:mm a').format(DateTime.now());

        return Scaffold(
          backgroundColor: CutlineColors.secondaryBackground,
          appBar: AppBar(
            title: const Text('Dashboard'),
            backgroundColor: Colors.white,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          body: provider.isLoading && provider.bookings.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => provider.load(),
                  child: ListView(
                    padding: CutlineSpacing.section.copyWith(bottom: 24),
                    children: [
                      _PeriodFilter(
                        selected: provider.period,
                        onSelected: (period) => provider.setPeriod(period),
                        timestamp: nowLabel,
                      ),
                      const SizedBox(height: CutlineSpacing.sm),
                      _KpiGrid(metrics: metrics),
                      const SizedBox(height: CutlineSpacing.md),
                      _StatusRow(
                        bookingCounts: bookingCounts,
                        queueCounts: queueCounts,
                      ),
                      const SizedBox(height: CutlineSpacing.md),
                      _PeakAndOps(
                        peakHour: metrics.peakHour,
                        activeBarbers: barbers.length,
                        waiting: queueCounts[OwnerQueueStatus.waiting] ?? 0,
                      ),
                      const SizedBox(height: CutlineSpacing.md),
                      _PerformanceCard(
                        title: 'Top services',
                        child: services.isEmpty
                            ? const _EmptyText('No service data yet')
                            : Column(
                                children: services
                                    .map((s) => _ServiceTile(service: s))
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: CutlineSpacing.md),
                      _PerformanceCard(
                        title: 'Barber performance',
                        child: barbers.isEmpty
                            ? const _EmptyText('No barber data yet')
                            : Column(
                                children: barbers
                                    .map((b) => _BarberTile(barber: b))
                                    .toList(),
                              ),
                      ),
                      const SizedBox(height: CutlineSpacing.md),
                      _PerformanceCard(
                        title: 'Recent bookings',
                        child: bookings.isEmpty
                            ? const _EmptyText('No bookings yet')
                            : Column(
                                children: bookings
                                    .map((b) => _BookingTile(booking: b))
                                    .toList(),
                              ),
                      ),
                      if (provider.error != null) ...[
                        const SizedBox(height: CutlineSpacing.sm),
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
}

class _PeriodFilter extends StatelessWidget {
  final DashboardPeriod selected;
  final ValueChanged<DashboardPeriod> onSelected;
  final String timestamp;

  const _PeriodFilter({
    required this.selected,
    required this.onSelected,
    required this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final options = DashboardPeriod.values;
    return Container(
      padding: CutlineSpacing.card,
      decoration: CutlineDecorations.card(solidColor: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Select range', style: CutlineTextStyles.subtitleBold),
          const SizedBox(height: 6),
          Text('Live overview • $timestamp', style: CutlineTextStyles.caption),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: options.map((period) {
              final isSelected = period == selected;
              return ChoiceChip(
                label: Text(period.label),
                selected: isSelected,
                onSelected: (_) => onSelected(period),
                selectedColor: CutlineColors.primary.withValues(alpha: 0.12),
                labelStyle: CutlineTextStyles.body.copyWith(
                  color: isSelected ? CutlineColors.primary : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final DashboardMetrics metrics;

  const _KpiGrid({required this.metrics});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.compactCurrency(
      locale: 'en',
      symbol: '৳',
      decimalDigits: 0,
    );
    final number = NumberFormat.decimalPattern();
    final stats = [
      _KpiData(
        label: 'Revenue',
        value: currency.format(metrics.totalRevenue),
        icon: Icons.payments_outlined,
        color: const Color(0xFF2563EB),
      ),
      _KpiData(
        label: 'Bookings',
        value: number.format(metrics.totalBookings),
        icon: Icons.event_available_outlined,
        color: const Color(0xFF5B21B6),
      ),
      _KpiData(
        label: 'Customers',
        value: number.format(metrics.totalCustomers),
        icon: Icons.people_outline,
        color: const Color(0xFF10B981),
      ),
      _KpiData(
        label: 'Walk-ins',
        value: number.format(metrics.manualWalkIns),
        icon: Icons.door_sliding_outlined,
        color: const Color(0xFFF59E0B),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemCount: stats.length,
      itemBuilder: (_, index) => _KpiCard(data: stats[index]),
    );
  }
}

class _KpiData {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });
}

class _KpiCard extends StatelessWidget {
  final _KpiData data;

  const _KpiCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: CutlineSpacing.card,
      decoration: CutlineDecorations.card(solidColor: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: data.color),
          ),
          Text(data.label, style: CutlineTextStyles.caption),
          Text(
            data.value,
            style: CutlineTextStyles.title.copyWith(fontSize: 22),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final Map<OwnerBookingStatus, int> bookingCounts;
  final Map<OwnerQueueStatus, int> queueCounts;

  const _StatusRow({
    required this.bookingCounts,
    required this.queueCounts,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: CutlineSpacing.card,
      decoration: CutlineDecorations.card(solidColor: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Status summary', style: CutlineTextStyles.subtitleBold),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatusPill(
                label: 'Upcoming',
                count: bookingCounts[OwnerBookingStatus.upcoming] ?? 0,
                color: const Color(0xFF2563EB),
              ),
              _StatusPill(
                label: 'Completed',
                count: bookingCounts[OwnerBookingStatus.completed] ?? 0,
                color: const Color(0xFF10B981),
              ),
              _StatusPill(
                label: 'Cancelled',
                count: bookingCounts[OwnerBookingStatus.cancelled] ?? 0,
                color: const Color(0xFFEF4444),
              ),
              _StatusPill(
                label: 'Waiting',
                count: queueCounts[OwnerQueueStatus.waiting] ?? 0,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _StatusPill({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.16),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.circle, size: 10, color: color),
          ),
          const SizedBox(width: 8),
          Text(label, style: CutlineTextStyles.body),
          const SizedBox(width: 8),
          Text('$count', style: CutlineTextStyles.subtitleBold),
        ],
      ),
    );
  }
}

class _PeakAndOps extends StatelessWidget {
  final String peakHour;
  final int activeBarbers;
  final int waiting;

  const _PeakAndOps({
    required this.peakHour,
    required this.activeBarbers,
    required this.waiting,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MiniCard(
            title: 'Peak hour',
            value: peakHour,
            icon: Icons.access_time,
            color: const Color(0xFF5B21B6),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _MiniCard(
            title: 'Active barbers',
            value: '$activeBarbers on floor',
            icon: Icons.people_alt_outlined,
            color: const Color(0xFF0EA5E9),
            footer: '$waiting waiting',
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final String? footer;

  const _MiniCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.footer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: CutlineSpacing.card,
      decoration: CutlineDecorations.card(solidColor: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 10),
          Text(title, style: CutlineTextStyles.caption),
          Text(value,
              style: CutlineTextStyles.title.copyWith(fontSize: 18)),
          if (footer != null) ...[
            const SizedBox(height: 6),
            Text(footer!, style: CutlineTextStyles.caption),
          ],
        ],
      ),
    );
  }
}

class _PerformanceCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _PerformanceCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: CutlineSpacing.card,
      decoration: CutlineDecorations.card(solidColor: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: CutlineTextStyles.subtitleBold),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final ServicePerformance service;

  const _ServiceTile({required this.service});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: service.accent.withValues(alpha: 0.12),
        child: Icon(service.icon, color: service.accent),
      ),
      title: Text(service.name, style: CutlineTextStyles.subtitleBold),
      trailing: Text('${service.count}',
          style: CutlineTextStyles.title.copyWith(fontSize: 18)),
    );
  }
}

class _BarberTile extends StatelessWidget {
  final BarberPerformance barber;

  const _BarberTile({required this.barber});

  @override
  Widget build(BuildContext context) {
    final initials = barber.name
        .split(' ')
        .where((p) => p.isNotEmpty)
        .map((p) => p[0])
        .take(2)
        .join()
        .toUpperCase();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: CutlineColors.primary.withValues(alpha: 0.12),
        child: Text(initials,
            style: CutlineTextStyles.subtitleBold
                .copyWith(color: CutlineColors.primary)),
      ),
      title: Text(barber.name, style: CutlineTextStyles.subtitleBold),
      subtitle: Text('${barber.served} customers',
          style: CutlineTextStyles.caption),
      trailing: Text(barber.satisfaction, style: CutlineTextStyles.body),
    );
  }
}

class _BookingTile extends StatelessWidget {
  final OwnerBooking booking;

  const _BookingTile({required this.booking});

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('MMM d, h:mm a').format(booking.dateTime);
    final statusColor = _statusColor(booking.status);
    final statusLabel = _statusLabel(booking.status);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: statusColor.withValues(alpha: 0.14),
        child: Icon(Icons.event_note, color: statusColor),
      ),
      title: Text(booking.customerName,
          style: CutlineTextStyles.subtitleBold),
      subtitle: Text('${booking.service} • $dateLabel',
          style: CutlineTextStyles.caption),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: statusColor.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(statusLabel,
            style: CutlineTextStyles.caption
                .copyWith(color: statusColor, fontWeight: FontWeight.w600)),
      ),
    );
  }

  String _statusLabel(OwnerBookingStatus status) {
    switch (status) {
      case OwnerBookingStatus.upcoming:
        return 'Upcoming';
      case OwnerBookingStatus.completed:
        return 'Completed';
      case OwnerBookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color _statusColor(OwnerBookingStatus status) {
    switch (status) {
      case OwnerBookingStatus.upcoming:
        return const Color(0xFF2563EB);
      case OwnerBookingStatus.completed:
        return const Color(0xFF10B981);
      case OwnerBookingStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }
}

class _EmptyText extends StatelessWidget {
  final String text;

  const _EmptyText(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child:
          Text(text, style: CutlineTextStyles.caption, textAlign: TextAlign.left),
    );
  }
}
