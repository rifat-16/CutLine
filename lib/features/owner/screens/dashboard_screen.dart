import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/dashboard_provider.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  DashboardPeriod _selectedPeriod = DashboardPeriod.today;

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
        final services = provider.services;
        final barbers = provider.barbers;
        final todayLabel = DateFormat('EEEE, MMM d').format(DateTime.now());
        final subtitle = '${_selectedPeriod.subtitleLabel} • $todayLabel';

        return Scaffold(
          backgroundColor: const Color(0xFFF5F7FB),
          appBar: AppBar(
            title: const Text(
              'Dashboard',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 20,
              ),
            ),
            centerTitle: false,
            elevation: 0,
            scrolledUnderElevation: 0,
            backgroundColor: Colors.white,
            surfaceTintColor: Colors.white,
            shadowColor: const Color(0x14000000),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : SafeArea(
                  child: RefreshIndicator(
                    onRefresh: () => provider.load(),
                    child: SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SectionHeader(
                            title: 'Owner Reporting Dashboard',
                            subtitle: subtitle,
                          ),
                          const SizedBox(height: 16),
                          _DashboardPeriodSelector(
                            selectedPeriod: _selectedPeriod,
                            onChanged: (period) {
                              if (period == _selectedPeriod) return;
                              setState(() => _selectedPeriod = period);
                            },
                          ),
                          const SizedBox(height: 16),
                          _DashboardStatsGrid(
                            stats: _buildStatData(metrics),
                          ),
                          const SizedBox(height: 28),
                          const SectionHeader(
                            title: 'Barber Performance',
                            subtitle: 'Customers served and efficiency',
                          ),
                          const SizedBox(height: 12),
                          DashboardSectionCard(
                            child: _BarberPerformanceList(barbers: barbers),
                          ),
                          const SizedBox(height: 28),
                          const SectionHeader(
                            title: 'Service Performance',
                            subtitle: 'Top booked services',
                          ),
                          const SizedBox(height: 12),
                          DashboardSectionCard(
                            child: _ServicePerformanceList(services: services),
                          ),
                          if (provider.error != null) ...[
                            const SizedBox(height: 16),
                            Text(
                              provider.error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  List<_DashboardStatData> _buildStatData(DashboardMetrics metrics) {
    final currencyFormat = NumberFormat.compactCurrency(
      locale: 'en',
      symbol: 'Tk ',
      decimalDigits: 0,
    );
    final numberFormat = NumberFormat.decimalPattern();
    return [
      _DashboardStatData(
        icon: Icons.people_alt_outlined,
        title: 'Total Customers',
        value: numberFormat.format(metrics.totalCustomers),
        subtitle: 'Unique customers',
        color: const Color(0xFF2563EB),
      ),
      _DashboardStatData(
        icon: Icons.payments_outlined,
        title: 'Total Revenue',
        value: currencyFormat.format(metrics.totalRevenue),
        subtitle: 'All bookings',
        color: const Color(0xFF22C55E),
      ),
      _DashboardStatData(
        icon: Icons.event_note_outlined,
        title: 'Total Bookings',
        value: numberFormat.format(metrics.totalBookings),
        subtitle: 'Confirmed slots',
        color: const Color(0xFF6366F1),
      ),
      _DashboardStatData(
        icon: Icons.meeting_room_outlined,
        title: 'Manual Walk-in Customers',
        value: numberFormat.format(metrics.manualWalkIns),
        subtitle: 'Waiting in queue',
        color: const Color(0xFF0EA5E9),
      ),
      _DashboardStatData(
        icon: Icons.cancel_outlined,
        title: 'Cancelled Bookings',
        value: numberFormat.format(metrics.cancelledBookings),
        subtitle: 'Latest period',
        color: const Color(0xFFEB3B5A),
      ),
      _DashboardStatData(
        icon: Icons.schedule_outlined,
        title: 'Peak Hour',
        value: metrics.peakHour,
        subtitle: 'Highest bookings',
        color: const Color(0xFFF59E0B),
      ),
    ];
  }
}

class _DashboardStatsGrid extends StatelessWidget {
  final List<_DashboardStatData> stats;

  const _DashboardStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        // Slightly taller cards to avoid text overflow on small screens.
        childAspectRatio: 0.95,
      ),
      itemCount: stats.length,
      itemBuilder: (context, index) => _StatCard(data: stats[index]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final _DashboardStatData data;

  const _StatCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(height: 12),
          Text(data.title,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 6),
          Text(data.value,
              style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                  color: Colors.black87)),
          const SizedBox(height: 4),
          Text(data.subtitle, style: const TextStyle(color: Colors.black54)),
        ],
      ),
    );
  }
}

class _DashboardStatData {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _DashboardStatData({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });
}

class _DashboardPeriodSelector extends StatelessWidget {
  final DashboardPeriod selectedPeriod;
  final ValueChanged<DashboardPeriod> onChanged;

  const _DashboardPeriodSelector({
    required this.selectedPeriod,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: DashboardPeriod.values.map((period) {
        final bool isSelected = period == selectedPeriod;
        return ChoiceChip(
          label: Text(period.label),
          selected: isSelected,
          onSelected: (_) => onChanged(period),
        );
      }).toList(),
    );
  }
}

class _BarberPerformanceList extends StatelessWidget {
  final List<BarberPerformance> barbers;

  const _BarberPerformanceList({required this.barbers});

  @override
  Widget build(BuildContext context) {
    if (barbers.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No barber performance data.'),
      );
    }
    return Column(
      children: barbers
          .map(
            (barber) => ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: CircleAvatar(
                backgroundColor: Colors.blueAccent.withValues(alpha: 0.12),
                child: Text(
                  barber.name
                      .split(' ')
                      .where((p) => p.isNotEmpty)
                      .map((p) => p[0])
                      .take(2)
                      .join()
                      .toUpperCase(),
                  style: const TextStyle(
                      color: Colors.blueAccent, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(barber.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(
                '${barber.served} customers • ${barber.satisfaction}',
                style: const TextStyle(color: Colors.black54),
              ),
            ),
          )
          .toList(),
    );
  }
}

class _ServicePerformanceList extends StatelessWidget {
  final List<ServicePerformance> services;

  const _ServicePerformanceList({required this.services});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No service performance data.'),
      );
    }
    return Column(
      children: services
          .map(
            (service) => ListTile(
              contentPadding: const EdgeInsets.symmetric(vertical: 4),
              leading: CircleAvatar(
                backgroundColor: service.accent.withValues(alpha: 0.12),
                child: Icon(service.icon, color: service.accent),
              ),
              title: Text(service.name,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
              trailing: Text(
                '${service.count}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          )
          .toList(),
    );
  }
}

class DashboardSectionCard extends StatelessWidget {
  final Widget child;

  const DashboardSectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 10))
        ],
      ),
      child: child,
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const SectionHeader({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

enum DashboardPeriod { today, week, month }

extension on DashboardPeriod {
  String get label {
    switch (this) {
      case DashboardPeriod.today:
        return 'Today';
      case DashboardPeriod.week:
        return 'This week';
      case DashboardPeriod.month:
        return 'This month';
    }
  }

  String get subtitleLabel {
    switch (this) {
      case DashboardPeriod.today:
        return 'Today';
      case DashboardPeriod.week:
        return 'This week';
      case DashboardPeriod.month:
        return 'This month';
    }
  }
}
