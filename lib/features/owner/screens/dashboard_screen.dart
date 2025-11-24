import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OwnerDashboardScreen extends StatefulWidget {
  const OwnerDashboardScreen({super.key});

  @override
  State<OwnerDashboardScreen> createState() => _OwnerDashboardScreenState();
}

class _OwnerDashboardScreenState extends State<OwnerDashboardScreen> {
  static const _DashboardMetrics _metrics = _DashboardMetrics(
    totalCustomers: 52,
    totalRevenue: 18200,
    totalBookings: 26,
    manualWalkIns: 14,
    cancelledBookings: 3,
    newCustomers: 9,
    returningCustomers: 21,
    peakHour: '5:00 PM - 6:00 PM',
  );

  static const List<_ServicePerformanceData> _services = [
    _ServicePerformanceData(
      name: 'Classic Haircut',
      count: 18,
      detail: '+4 vs yesterday',
      icon: Icons.content_cut,
      accent: Color(0xFF2563EB),
    ),
    _ServicePerformanceData(
      name: 'Signature Beard Trim',
      count: 14,
      detail: '+2 repeat clients',
      icon: Icons.face_retouching_natural_outlined,
      accent: Color(0xFF0EA5E9),
    ),
    _ServicePerformanceData(
      name: 'Premium Grooming',
      count: 9,
      detail: 'Avg ticket Tk 620',
      icon: Icons.workspace_premium_outlined,
      accent: Color(0xFF22C55E),
    ),
    _ServicePerformanceData(
      name: 'Hair Spa',
      count: 6,
      detail: 'Room for 2 more slots',
      icon: Icons.water_drop_outlined,
      accent: Color(0xFF8B5CF6),
    ),
  ];

  static const List<_InsightCardData> _insights = [
    _InsightCardData(
      title: 'Best Barber',
      value: 'Alex Rahman',
      description: '7 customers • 4.9★ satisfaction',
      icon: Icons.workspace_premium_outlined,
      color: Color(0xFF2563EB),
    ),
    _InsightCardData(
      title: 'Low Performance Hour',
      value: '2:00 PM - 3:00 PM',
      description: 'Only 1 booking • consider promo',
      icon: Icons.av_timer_outlined,
      color: Color(0xFFF97316),
    ),
    _InsightCardData(
      title: 'Growth vs Yesterday',
      value: '+11%',
      description: 'Revenue trend still above target',
      icon: Icons.trending_up_outlined,
      color: Color(0xFF22C55E),
    ),
  ];

  static final NumberFormat _currencyFormat = NumberFormat.compactCurrency(
    locale: 'en',
    symbol: 'Tk ',
    decimalDigits: 0,
  );

  static final NumberFormat _numberFormat = NumberFormat.decimalPattern();

  DashboardPeriod _selectedPeriod = DashboardPeriod.today;

  @override
  Widget build(BuildContext context) {
    final stats = _buildStatData();
    final barbers = _buildBarberPerformanceData();
    final todayLabel = DateFormat('EEEE, MMM d').format(DateTime.now());
    final subtitle =
        '${_selectedPeriod.subtitleLabel} • $todayLabel';

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
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          physics: const BouncingScrollPhysics(),
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
              _DashboardStatsGrid(stats: stats),
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
              const DashboardSectionCard(
                child: _ServicePerformanceList(services: _services),
              ),
              const SizedBox(height: 28),
              const SectionHeader(
                title: 'Smart Insights',
                subtitle: 'Realtime nudges powered by CutLine',
              ),
              const SizedBox(height: 12),
              const _SmartInsightsGrid(insights: _insights),
            ],
          ),
        ),
      ),
    );
  }

  static List<_DashboardStatData> _buildStatData() {
    return [
      _DashboardStatData(
        icon: Icons.people_alt_outlined,
        title: 'Total Customers',
        value: _numberFormat.format(_metrics.totalCustomers),
        subtitle: '+12% vs yesterday',
        color: const Color(0xFF2563EB),
      ),
      _DashboardStatData(
        icon: Icons.payments_outlined,
        title: 'Total Revenue',
        value: _currencyFormat.format(_metrics.totalRevenue),
        subtitle: 'Avg ticket ${_currencyFormat.format(_metrics.avgTicket)}',
        color: const Color(0xFF22C55E),
      ),
      _DashboardStatData(
        icon: Icons.event_note_outlined,
        title: 'Total Bookings',
        value: _numberFormat.format(_metrics.totalBookings),
        subtitle: 'Includes all confirmed slots',
        color: const Color(0xFF6366F1),
      ),
      _DashboardStatData(
        icon: Icons.meeting_room_outlined,
        title: 'Manual Walk-in Customers',
        value: _numberFormat.format(_metrics.manualWalkIns),
        subtitle: '6 waiting in lobby now',
        color: const Color(0xFF0EA5E9),
      ),
      _DashboardStatData(
        icon: Icons.cancel_outlined,
        title: 'Cancelled Bookings',
        value: _numberFormat.format(_metrics.cancelledBookings),
        subtitle: 'Most cancel <2 hrs before',
        color: const Color(0xFFF43F5E),
      ),
      _DashboardStatData(
        icon: Icons.person_add_alt_1_outlined,
        title: 'New Customers',
        value: _numberFormat.format(_metrics.newCustomers),
        subtitle: '38% sourced online',
        color: const Color(0xFF22C55E),
      ),
      _DashboardStatData(
        icon: Icons.refresh_outlined,
        title: 'Returning Customers',
        value: _numberFormat.format(_metrics.returningCustomers),
        subtitle: 'Loyalty retention 64%',
        color: const Color(0xFF4338CA),
      ),
      _DashboardStatData(
        icon: Icons.bolt_outlined,
        title: 'Peak Hour',
        value: _metrics.peakHour,
        subtitle: 'Avg wait 14 mins',
        color: const Color(0xFFF97316),
      ),
    ];
  }

  static List<_BarberPerformanceData> _buildBarberPerformanceData() {
    const avatarUrls = [
      'https://images.unsplash.com/photo-1521572163474-6864f9cf17ab?auto=format&fit=facearea&w=400&h=400&q=80',
      'https://images.unsplash.com/photo-1544723795-3fb6469f5b39?auto=format&fit=facearea&w=400&h=400&q=80',
      'https://images.unsplash.com/photo-1524504388940-b1c1722653e1?auto=format&fit=facearea&w=400&h=400&q=80',
      'https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?auto=format&fit=facearea&w=400&h=400&q=80',
    ];
    const avgTimes = ['23m avg', '27m avg', '29m avg', '25m avg'];

    return List<_BarberPerformanceData>.generate(
      kOwnerBarbers.length,
      (index) {
        final barber = kOwnerBarbers[index];
        return _BarberPerformanceData(
          imageUrl: avatarUrls[index % avatarUrls.length],
          name: barber.name,
          servedCount: barber.servedToday,
          avgTime: avgTimes[index % avgTimes.length],
        );
      },
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;

  const SectionHeader({required this.title, this.subtitle, super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: const Color(0xFF64748B),
            ),
          ),
        ],
      ],
    );
  }
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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: DashboardPeriod.values
            .map(
              (period) => Padding(
                padding: EdgeInsets.only(
                  right: period == DashboardPeriod.values.last ? 0 : 12,
                ),
                child: _PeriodFilterChip(
                  label: period.chipLabel,
                  isSelected: period == selectedPeriod,
                  onTap: () => onChanged(period),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PeriodFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _PeriodFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFDBEAFE)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF1D4ED8)
                : const Color(0xFFE2E8F0),
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(
                    color: Color(0x19000000),
                    blurRadius: 12,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: isSelected
                ? const Color(0xFF1D4ED8)
                : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}

class _DashboardStatsGrid extends StatelessWidget {
  final List<_DashboardStatData> stats;

  const _DashboardStatsGrid({required this.stats});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 12.0;
        const minTileWidth = 150.0;
        var width = constraints.maxWidth;
        if (width == double.infinity) {
          width = MediaQuery.of(context).size.width;
        }

        var columns = (width / (minTileWidth)).floor();
        columns = columns.clamp(1, 4);
        if (columns == 1 && width >= 320) {
          columns = 2;
        }

        final itemWidth = columns == 1
            ? width
            : (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: stats
              .map(
                (stat) => SizedBox(
                  width: itemWidth,
                  child: DashboardStatCard(
                    icon: stat.icon,
                    title: stat.title,
                    value: stat.value,
                    subtitle: stat.subtitle,
                    color: stat.color,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class DashboardStatCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color color;

  const DashboardStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.subtitle,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 14,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class DashboardSectionCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const DashboardSectionCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 20,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BarberPerformanceList extends StatelessWidget {
  final List<_BarberPerformanceData> barbers;

  const _BarberPerformanceList({required this.barbers});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        var width = constraints.maxWidth;
        if (width == double.infinity) {
          width = MediaQuery.of(context).size.width;
        }

        final columns = width >= 640 ? 2 : 1;
        final itemWidth = columns == 1
            ? width
            : (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: barbers
              .map(
                (barber) => SizedBox(
                  width: itemWidth,
                  child: BarberPerformanceCard(
                    image: barber.imageUrl,
                    name: barber.name,
                    servedCount: barber.servedCount,
                    avgTime: barber.avgTime,
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class BarberPerformanceCard extends StatelessWidget {
  final String image;
  final String name;
  final int servedCount;
  final String avgTime;

  const BarberPerformanceCard({
    required this.image,
    required this.name,
    required this.servedCount,
    required this.avgTime,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F0F172A),
            blurRadius: 18,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Image.network(
              image,
              width: 64,
              height: 64,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                width: 64,
                height: 64,
                color: const Color(0xFFE2E8F0),
                child: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF475569),
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(
                      Icons.people_outline,
                      size: 16,
                      color: Color(0xFF475569),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$servedCount customers',
                      style: textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF475569),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(
                      Icons.timer_outlined,
                      size: 16,
                      color: Color(0xFF2563EB),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      avgTime,
                      style: textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ServicePerformanceList extends StatelessWidget {
  final List<_ServicePerformanceData> services;

  const _ServicePerformanceList({required this.services});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (int i = 0; i < services.length; i++) ...[
          _ServicePerformanceTile(data: services[i]),
          if (i != services.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Divider(
                height: 1,
                color: Color(0xFFE2E8F0),
              ),
            ),
        ],
      ],
    );
  }
}

class _ServicePerformanceTile extends StatelessWidget {
  final _ServicePerformanceData data;

  const _ServicePerformanceTile({required this.data});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: data.accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(data.icon, color: data.accent),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.name,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                data.detail,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: const Color(0xFF94A3B8)),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            '${data.count}',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
        ),
      ],
    );
  }
}

class _SmartInsightsGrid extends StatelessWidget {
  final List<_InsightCardData> insights;

  const _SmartInsightsGrid({required this.insights});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 16.0;
        var width = constraints.maxWidth;
        if (width == double.infinity) {
          width = MediaQuery.of(context).size.width;
        }

        int columns;
        if (width >= 900) {
          columns = 3;
        } else if (width >= 560) {
          columns = 2;
        } else {
          columns = 1;
        }

        final itemWidth = columns == 1
            ? width
            : (width - spacing * (columns - 1)) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: insights
              .map(
                (insight) => SizedBox(
                  width: itemWidth,
                  child: _SmartInsightCard(data: insight),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class _SmartInsightCard extends StatelessWidget {
  final _InsightCardData data;

  const _SmartInsightCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color),
          ),
          const SizedBox(height: 16),
          Text(
            data.title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            data.description,
            style: const TextStyle(
              color: Color(0xFF64748B),
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardMetrics {
  final int totalCustomers;
  final int totalRevenue;
  final int totalBookings;
  final int manualWalkIns;
  final int cancelledBookings;
  final int newCustomers;
  final int returningCustomers;
  final String peakHour;

  const _DashboardMetrics({
    required this.totalCustomers,
    required this.totalRevenue,
    required this.totalBookings,
    required this.manualWalkIns,
    required this.cancelledBookings,
    required this.newCustomers,
    required this.returningCustomers,
    required this.peakHour,
  });

  double get avgTicket =>
      totalCustomers == 0 ? 0 : totalRevenue / totalCustomers;
}

class _DashboardStatData {
  final IconData icon;
  final String title;
  final String value;
  final String? subtitle;
  final Color color;

  const _DashboardStatData({
    required this.icon,
    required this.title,
    required this.value,
    required this.color,
    this.subtitle,
  });
}

class _BarberPerformanceData {
  final String imageUrl;
  final String name;
  final int servedCount;
  final String avgTime;

  const _BarberPerformanceData({
    required this.imageUrl,
    required this.name,
    required this.servedCount,
    required this.avgTime,
  });
}

class _ServicePerformanceData {
  final String name;
  final int count;
  final String detail;
  final IconData icon;
  final Color accent;

  const _ServicePerformanceData({
    required this.name,
    required this.count,
    required this.detail,
    required this.icon,
    required this.accent,
  });
}

class _InsightCardData {
  final String title;
  final String value;
  final String description;
  final IconData icon;
  final Color color;

  const _InsightCardData({
    required this.title,
    required this.value,
    required this.description,
    required this.icon,
    required this.color,
  });
}

enum DashboardPeriod { today, week, month, year }

extension DashboardPeriodText on DashboardPeriod {
  String get subtitleLabel {
    switch (this) {
      case DashboardPeriod.today:
        return 'Today';
      case DashboardPeriod.week:
        return 'This Week';
      case DashboardPeriod.month:
        return 'This Month';
      case DashboardPeriod.year:
        return 'This Year';
    }
  }

  String get chipLabel {
    if (this == DashboardPeriod.today) {
      return 'Live';
    }
    return subtitleLabel;
  }
}
