import 'package:flutter/material.dart';

import 'package:cutline/features/admin/models/admin_models.dart';
import 'package:cutline/features/admin/services/admin_service.dart';
import 'package:cutline/features/admin/widgets/admin_ui.dart';
import 'package:cutline/features/admin/widgets/platform_fee_control_panel.dart';
import 'package:cutline/routes/admin_router.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({
    super.key,
    required this.onNavigate,
  });

  final ValueChanged<int> onNavigate;

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  final AdminService _service = AdminService();
  late Future<_DashboardData> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<_DashboardData> _load() async {
    final results = await Future.wait<dynamic>([
      _service.loadDashboardStats(),
      _service.loadRecentPendingSalons(),
      _service.loadRecentRestrictedSalons(),
      _service.loadRecentPendingPlatformFeePayments(),
    ]);
    return _DashboardData(
      stats: results[0] as AdminDashboardStats,
      pendingSalons: results[1] as List<AdminSalonSummary>,
      restrictedSalons: results[2] as List<AdminSalonSummary>,
      pendingPlatformFeePayments: results[3] as List<AdminPaymentItem>,
    );
  }

  Future<void> _reload() async {
    setState(() => _future = _load());
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await _reload();
      },
      child: FutureBuilder<_DashboardData>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
              children: const [
                AdminEmptyState(
                  icon: Icons.error_outline_rounded,
                  title: 'Dashboard could not load',
                  message: 'Pull to refresh or check your internet connection.',
                ),
              ],
            );
          }

          final data = snapshot.data!;
          return LayoutBuilder(
            builder: (context, constraints) {
              const spacing = 12.0;
              final columns = constraints.maxWidth >= 920 ? 4 : 2;
              final metricCardHeight = columns == 2 ? 232.0 : 208.0;

              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
                children: [
                  _OverviewHero(
                    stats: data.stats,
                    onPaymentsTap: () => widget.onNavigate(1),
                    onPendingTap: () => widget.onNavigate(2),
                    onSalonTap: () => widget.onNavigate(3),
                  ),
                  const SizedBox(height: 24),
                  const AdminSectionHeading(
                    eyebrow: 'Live Snapshot',
                    title: 'Platform health',
                    subtitle:
                        'Keep an eye on verification, restrictions, and unpaid platform fees.',
                  ),
                  const SizedBox(height: 14),
                  GridView(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      crossAxisSpacing: spacing,
                      mainAxisSpacing: spacing,
                      mainAxisExtent: metricCardHeight,
                    ),
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      _MetricCard(
                        title: 'Pending payments',
                        value: data.stats.pendingPlatformFeePaymentCount
                            .toString(),
                        subtitle:
                            '${formatAdminCurrency(data.stats.pendingPlatformFeePaymentAmount)} waiting for review',
                        icon: Icons.payments_outlined,
                        accent: const Color(0xFF1D4ED8),
                        onTap: () => widget.onNavigate(1),
                      ),
                      _MetricCard(
                        title: 'Pending salons',
                        value: data.stats.pendingSalonCount.toString(),
                        subtitle: 'Waiting for your verification',
                        icon: Icons.fact_check_outlined,
                        accent: const Color(0xFF0F766E),
                        onTap: () => widget.onNavigate(2),
                      ),
                      _MetricCard(
                        title: 'Restricted salons',
                        value: data.stats.restrictedSalonCount.toString(),
                        subtitle: 'Blocked until dues are cleared',
                        icon: Icons.lock_outline_rounded,
                        accent: const Color(0xFFB45309),
                        onTap: () => widget.onNavigate(3),
                      ),
                      _MetricCard(
                        title: 'Outstanding due',
                        value: formatAdminCurrency(
                          data.stats.totalOutstandingFee,
                        ),
                        subtitle: 'Remaining platform fee amount',
                        icon: Icons.account_balance_wallet_outlined,
                        accent: const Color(0xFF7C3AED),
                        onTap: () => widget.onNavigate(1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const AdminSectionHeading(
                    eyebrow: 'Controls',
                    title: 'Platform fee',
                    subtitle:
                        'Switch between free mode and a custom amount for all new bookings.',
                  ),
                  const SizedBox(height: 14),
                  const PlatformFeeControlPanel(),
                  const SizedBox(height: 24),
                  _OverviewListPanel(
                    eyebrow: 'Payment Queue',
                    title: 'Pending fee payments',
                    subtitle:
                        'Dashboard keeps a short preview here. Open the Payments tab for full review actions.',
                    actionLabel: 'Open payments',
                    onActionTap: () => widget.onNavigate(1),
                    child: _PaymentQueuePreview(
                      stats: data.stats,
                      payments: data.pendingPlatformFeePayments,
                      onOpenPayments: () => widget.onNavigate(1),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _OverviewListPanel(
                    eyebrow: 'Action Queue',
                    title: 'Pending verification',
                    subtitle:
                        'New salons stay here until you approve or reject them.',
                    actionLabel: 'View all',
                    onActionTap: () => widget.onNavigate(2),
                    child: data.pendingSalons.isEmpty
                        ? const AdminEmptyState(
                            icon: Icons.verified_outlined,
                            title: 'No salon is waiting',
                            message:
                                'Fresh salon registrations will appear here automatically.',
                          )
                        : Column(
                            children: data.pendingSalons
                                .map(
                                  (salon) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _SalonActionTile(
                                      salon: salon,
                                      statusLabel: 'Pending',
                                      statusBackground: const Color(0xFFE6F2EE),
                                      statusForeground: const Color(0xFF0C5C51),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 16),
                  _OverviewListPanel(
                    eyebrow: 'Compliance',
                    title: 'Restricted salons',
                    subtitle:
                        'Use restrictions when platform fees remain unpaid for too long.',
                    actionLabel: 'Open salons',
                    onActionTap: () => widget.onNavigate(3),
                    child: data.restrictedSalons.isEmpty
                        ? const AdminEmptyState(
                            icon: Icons.lock_open_rounded,
                            title: 'No restricted salon',
                            message:
                                'Once you block a salon for unpaid dues, it will show up here.',
                          )
                        : Column(
                            children: data.restrictedSalons
                                .map(
                                  (salon) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _SalonActionTile(
                                      salon: salon,
                                      statusLabel: 'Restricted',
                                      statusBackground: const Color(0xFFFFEDD5),
                                      statusForeground: const Color(0xFF9A3412),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _DashboardData {
  const _DashboardData({
    required this.stats,
    required this.pendingSalons,
    required this.restrictedSalons,
    required this.pendingPlatformFeePayments,
  });

  final AdminDashboardStats stats;
  final List<AdminSalonSummary> pendingSalons;
  final List<AdminSalonSummary> restrictedSalons;
  final List<AdminPaymentItem> pendingPlatformFeePayments;
}

class _OverviewHero extends StatelessWidget {
  const _OverviewHero({
    required this.stats,
    required this.onPaymentsTap,
    required this.onPendingTap,
    required this.onSalonTap,
  });

  final AdminDashboardStats stats;
  final VoidCallback onPaymentsTap;
  final VoidCallback onPendingTap;
  final VoidCallback onSalonTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF0F766E),
            Color(0xFF114E4A),
            Color(0xFF12352E),
          ],
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x220F4B44),
            blurRadius: 32,
            offset: Offset(0, 18),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
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
                        'CUTLINE CONTROL ROOM',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.78),
                          letterSpacing: 1.3,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Keep every salon compliant',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          height: 1.05,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Approve registrations, monitor overdue fees, and restrict non-paying salons from one place.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: Colors.white.withValues(alpha: 0.86),
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: const Icon(
                    Icons.admin_panel_settings_outlined,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _HeroInfoPill(
                  label: '${stats.totalSalons} salons live',
                  icon: Icons.storefront_outlined,
                ),
                _HeroInfoPill(
                  label:
                      '${stats.pendingPlatformFeePaymentCount} payments waiting',
                  icon: Icons.payments_outlined,
                ),
                _HeroInfoPill(
                  label: '${stats.pendingSalonCount} waiting review',
                  icon: Icons.fact_check_outlined,
                ),
                _HeroInfoPill(
                  label:
                      '${formatAdminCurrency(stats.totalOutstandingFee)} due',
                  icon: Icons.account_balance_wallet_outlined,
                ),
              ],
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F4F49),
                  ),
                  onPressed: onPaymentsTap,
                  icon: const Icon(Icons.payments_rounded),
                  label: const Text('Review payments'),
                ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white.withValues(alpha: 0.14),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: onPendingTap,
                  icon: const Icon(Icons.fact_check_rounded),
                  label: const Text('Review pending'),
                ),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.28),
                    ),
                  ),
                  onPressed: onSalonTap,
                  icon: const Icon(Icons.storefront_rounded),
                  label: const Text('Open salons'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroInfoPill extends StatelessWidget {
  const _HeroInfoPill({
    required this.label,
    required this.icon,
  });

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFDDE6E0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x120B1F19),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon, color: accent),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_outward_rounded,
                    color: accent,
                    size: 18,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5D6F68),
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                value,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: const Color(0xFF10261D),
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF73817B),
                      height: 1.35,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverviewListPanel extends StatelessWidget {
  const _OverviewListPanel({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.child,
    this.actionLabel,
    this.onActionTap,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onActionTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AdminPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AdminSectionHeading(
            eyebrow: eyebrow,
            title: title,
            subtitle: subtitle,
            actionLabel: actionLabel,
            onActionTap: onActionTap,
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _PaymentQueuePreview extends StatelessWidget {
  const _PaymentQueuePreview({
    required this.stats,
    required this.payments,
    required this.onOpenPayments,
  });

  final AdminDashboardStats stats;
  final List<AdminPaymentItem> payments;
  final VoidCallback onOpenPayments;

  @override
  Widget build(BuildContext context) {
    if (payments.isEmpty) {
      return const AdminEmptyState(
        icon: Icons.receipt_long_outlined,
        title: 'No pending fee payment',
        message: 'New owner fee submissions will appear here automatically.',
      );
    }

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
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QueueKpiChip(
                  icon: Icons.schedule_rounded,
                  label:
                      '${stats.pendingPlatformFeePaymentCount} waiting review',
                ),
                _QueueKpiChip(
                  icon: Icons.account_balance_wallet_outlined,
                  label: formatAdminCurrency(
                    stats.pendingPlatformFeePaymentAmount,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ...payments.take(3).map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _PaymentPreviewRow(item: item),
                  ),
                ),
            if (payments.length > 3)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  '${payments.length - 3} more payment submissions are waiting in the Payments tab.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF73817B),
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
            const SizedBox(height: 6),
            FilledButton.icon(
              onPressed: onOpenPayments,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: const Text('Open Payments tab'),
            ),
          ],
        ),
      ),
    );
  }
}

class _QueueKpiChip extends StatelessWidget {
  const _QueueKpiChip({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFDDE6E0)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF425A53)),
          const SizedBox(width: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF213630),
                  fontWeight: FontWeight.w700,
                ),
          ),
        ],
      ),
    );
  }
}

class _PaymentPreviewRow extends StatelessWidget {
  const _PaymentPreviewRow({
    required this.item,
  });

  final AdminPaymentItem item;

  @override
  Widget build(BuildContext context) {
    final salonLabel = item.salonName.isEmpty ? item.salonId : item.salonName;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E9E4)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFFE8EEF9),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.payments_outlined,
              color: Color(0xFF1D4ED8),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  salonLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF10261D),
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${formatAdminCurrency(item.amount)} • ${item.paymentMethod}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF425A53),
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.transactionId.isEmpty
                      ? formatAdminDateTime(item.date)
                      : 'TrxID: ${item.transactionId} • ${formatAdminDateTime(item.date)}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: const Color(0xFF73817B),
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const AdminStatusBadge(
            label: 'Pending',
            backgroundColor: Color(0xFFE6F2EE),
            foregroundColor: Color(0xFF0C5C51),
          ),
        ],
      ),
    );
  }
}

class _SalonActionTile extends StatelessWidget {
  const _SalonActionTile({
    required this.salon,
    required this.statusLabel,
    required this.statusBackground,
    required this.statusForeground,
  });

  final AdminSalonSummary salon;
  final String statusLabel;
  final Color statusBackground;
  final Color statusForeground;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF6FAF8),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => Navigator.of(context).pushNamed(
          AdminRoutes.salonReview,
          arguments: salon.id,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: const Color(0xFFDFF0E8),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Icon(
                  Icons.storefront_outlined,
                  color: Color(0xFF0F766E),
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
                          salon.name.isEmpty ? salon.id : salon.name,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        AdminStatusBadge(
                          label: statusLabel,
                          backgroundColor: statusBackground,
                          foregroundColor: statusForeground,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      salon.address.isEmpty
                          ? 'No address submitted'
                          : salon.address,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: const Color(0xFF5D6F68),
                          ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        AdminStatusBadge(
                          label: formatAdminDateTime(
                            salon.isRestricted
                                ? salon.restrictedAt
                                : salon.submittedAt,
                          ),
                          icon: Icons.schedule_rounded,
                          backgroundColor: const Color(0xFFEAF1EE),
                          foregroundColor: const Color(0xFF425A53),
                        ),
                        if (salon.restrictionReason.isNotEmpty &&
                            salon.isRestricted)
                          AdminStatusBadge(
                            label: salon.restrictionReason,
                            icon: Icons.info_outline_rounded,
                            backgroundColor: const Color(0xFFFFF4E5),
                            foregroundColor: const Color(0xFF9A3412),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFF6B7D76),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
