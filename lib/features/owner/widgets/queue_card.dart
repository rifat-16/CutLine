import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/utils/cutline_theme.dart';
import 'package:cutline/features/owner/utils/queue_actions.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OwnerQueueCard extends StatelessWidget {
  final OwnerQueueItem item;
  final bool showActions;
  final Future<void> Function(OwnerQueueStatus status)? onStatusChange;
  final VoidCallback? onTap;

  const OwnerQueueCard({
    super.key,
    required this.item,
    this.showActions = true,
    this.onStatusChange,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color statusColor = _statusColor(item.status);
    final String durationLabel =
        '${item.waitMinutes} min${item.waitMinutes == 1 ? '' : 's'}';
    final String scheduleLabel = _scheduleLabel(item);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(OwnerDecorations.radius),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            decoration: OwnerDecorations.card(
              border: Border.all(color: statusColor.withValues(alpha: 0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _StatusStripe(color: statusColor),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          CircleAvatar(
                            radius: 28,
                            backgroundColor:
                                OwnerTheme.primary.withValues(alpha: 0.1),
                            backgroundImage: item.customerAvatar.isNotEmpty
                                ? NetworkImage(item.customerAvatar)
                                : null,
                            child: item.customerAvatar.isEmpty
                                ? Text(
                                    _initials(item.customerName),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: OwnerTheme.primary),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(item.customerName,
                                              style: OwnerTextStyles.label
                                                  .copyWith(fontSize: 17)),
                                          const SizedBox(height: 4),
                                          if (item.customerPhone.isNotEmpty)
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.call,
                                                    size: 16,
                                                    color: Colors.black54),
                                                const SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    item.customerPhone,
                                                    style: OwnerTextStyles
                                                        .subtitle
                                                        .copyWith(fontSize: 13),
                                                  ),
                                                ),
                                              ],
                                            ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        _StatusChip(
                                          label: _statusLabel(item.status),
                                          color: statusColor,
                                        ),
                                        if (item.serialNo != null)
                                          Padding(
                                            padding:
                                                const EdgeInsets.only(top: 6),
                                            child: Text(
                                              'Serial #${item.serialNo}',
                                              style: OwnerTextStyles.subtitle
                                                  .copyWith(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w700,
                                                color: Colors.black54,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _InfoRow(
                          icon: Icons.design_services_outlined,
                          label: 'Service',
                          value: item.service),
                      const SizedBox(height: 8),
                      _InfoRow(
                          icon: Icons.cut,
                          label: 'Preferred barber',
                          value: item.barberName),
                      const SizedBox(height: 8),
                      _InfoRow(
                          icon: Icons.calendar_today_outlined,
                          label: 'Date & time',
                          value: scheduleLabel),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _InfoBadge(
                              icon: Icons.access_time,
                              label: 'Duration',
                              value: durationLabel,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _InfoBadge(
                              icon: Icons.volunteer_activism_outlined,
                              label: 'Tip for barber',
                              value: '৳${item.tipAmount}',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoBadge(
                        icon: Icons.payments_outlined,
                        label: 'Total price',
                        value: '৳${item.price}',
                      ),
                    ],
                  ),
                ),
                if (showActions)
                  _ActionRow(item: item, onStatusChange: onStatusChange),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _statusColor(OwnerQueueStatus status) {
    switch (status) {
      case OwnerQueueStatus.waiting:
        return Colors.amber;
      case OwnerQueueStatus.arrived:
        return Colors.blue;
      case OwnerQueueStatus.serving:
        return OwnerTheme.primary;
      case OwnerQueueStatus.done:
        return Colors.green;
      case OwnerQueueStatus.noShow:
        return Colors.red;
    }
  }

  String _statusLabel(OwnerQueueStatus status) {
    switch (status) {
      case OwnerQueueStatus.waiting:
        return 'Waiting';
      case OwnerQueueStatus.arrived:
        return 'Arrived';
      case OwnerQueueStatus.serving:
        return 'Serving';
      case OwnerQueueStatus.done:
        return 'Completed';
      case OwnerQueueStatus.noShow:
        return 'No Show';
    }
  }

  String _initials(String input) {
    final parts =
        input.trim().split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    if (parts.isEmpty) return 'C';
    return parts.map((e) => e[0]).take(2).join().toUpperCase();
  }

  String _scheduleLabel(OwnerQueueItem item) {
    final scheduledAt = item.scheduledAt;
    if (scheduledAt != null) {
      return DateFormat('d MMM, h:mm a').format(scheduledAt);
    }
    return item.slotLabel.isNotEmpty ? item.slotLabel : 'Not scheduled';
  }
}

class _StatusStripe extends StatelessWidget {
  final Color color;

  const _StatusStripe({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(
            top: Radius.circular(OwnerDecorations.radius)),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.blueGrey.shade600),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: OwnerTextStyles.subtitle
                      .copyWith(fontWeight: FontWeight.w600, fontSize: 13)),
              const SizedBox(height: 2),
              Text(value,
                  style: OwnerTextStyles.subtitle.copyWith(fontSize: 14)),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoBadge(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blueGrey.shade600),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: OwnerTextStyles.subtitle
                        .copyWith(fontWeight: FontWeight.w600, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    style: OwnerTextStyles.label.copyWith(fontSize: 14)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final OwnerQueueItem item;
  final Future<void> Function(OwnerQueueStatus status)? onStatusChange;

  const _ActionRow({required this.item, this.onStatusChange});

  @override
  Widget build(BuildContext context) {
    final actions = queueActionsForStatus(item.status);
    if (actions.isEmpty) {
      return const SizedBox(height: 16);
    }
    return _ActionRowBody(actions: actions, onStatusChange: onStatusChange);
  }
}

class _ActionRowBody extends StatefulWidget {
  final List<QueueActionConfig> actions;
  final Future<void> Function(OwnerQueueStatus status)? onStatusChange;

  const _ActionRowBody({
    required this.actions,
    required this.onStatusChange,
  });

  @override
  State<_ActionRowBody> createState() => _ActionRowBodyState();
}

class _ActionRowBodyState extends State<_ActionRowBody> {
  OwnerQueueStatus? _pendingStatus;

  Future<void> _handleAction(OwnerQueueStatus nextStatus) async {
    if (widget.onStatusChange == null) return;
    if (_pendingStatus != null) return;
    final startedAt = DateTime.now();
    const minLoaderDuration = Duration(milliseconds: 650);
    setState(() => _pendingStatus = nextStatus);
    try {
      await widget.onStatusChange!(nextStatus);
      if (!mounted) return;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update status: $e')),
      );
    } finally {
      final elapsed = DateTime.now().difference(startedAt);
      if (elapsed < minLoaderDuration) {
        await Future.delayed(minLoaderDuration - elapsed);
      }
      if (mounted) {
        setState(() => _pendingStatus = null);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        children: widget.actions.map((action) {
          final isLoading = _pendingStatus == action.nextStatus;
          final VoidCallback? handler =
              widget.onStatusChange == null || _pendingStatus != null
                  ? null
                  : () => _handleAction(action.nextStatus);
          if (action.isOutline) {
            return OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: action.color,
                side: BorderSide(color: action.color),
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
                minimumSize: const Size(200, 48),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: handler,
              child: _ActionButtonChild(
                label: action.label,
                loadingLabel: action.label,
                isLoading: isLoading,
                progressColor: action.color,
              ),
            );
          }
          return ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: action.color,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 13),
              minimumSize: const Size(200, 48),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: handler,
            child: _ActionButtonChild(
              label: action.label,
              loadingLabel: action.label,
              isLoading: isLoading,
              progressColor: Colors.white,
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ActionButtonChild extends StatelessWidget {
  final String label;
  final String loadingLabel;
  final bool isLoading;
  final Color progressColor;

  const _ActionButtonChild({
    required this.label,
    required this.loadingLabel,
    required this.isLoading,
    required this.progressColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
            child: child,
          ),
        );
      },
      child: isLoading
          ? Row(
              key: const ValueKey('loading'),
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                  ),
                ),
                const SizedBox(width: 10),
                Text(loadingLabel),
              ],
            )
          : Text(
              label,
              key: const ValueKey('idle'),
            ),
    );
  }
}
