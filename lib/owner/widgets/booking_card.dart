import 'package:cutline/owner/utils/constants.dart';
import 'package:cutline/owner/utils/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OwnerBookingCard extends StatelessWidget {
  final OwnerBooking booking;
  final VoidCallback? onTap;

  const OwnerBookingCard({super.key, required this.booking, this.onTap});

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('EEE, d MMM • hh:mm a');
    final Color statusColor = _statusColor(booking.status);
    final hasAvatar = booking.customerAvatar.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(OwnerDecorations.radius),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: OwnerDecorations.card(
          border: Border.all(color: statusColor.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: hasAvatar
                      ? OwnerTheme.primary.withValues(alpha: 0.12)
                      : OwnerTheme.primary,
                  backgroundImage:
                      hasAvatar ? NetworkImage(booking.customerAvatar) : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          _initials(booking.customerName),
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(booking.customerName,
                          style: OwnerTextStyles.label.copyWith(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(booking.service,
                          style: OwnerTextStyles.subtitle
                              .copyWith(color: Colors.black54)),
                    ],
                  ),
                ),
                _StatusPill(
                    color: statusColor, label: _statusLabel(booking.status)),
              ],
            ),
            const SizedBox(height: 12),
            Text('৳${booking.price} • ${booking.paymentMethod}',
                style: OwnerTextStyles.label.copyWith(fontSize: 13)),
            const SizedBox(height: 8),
            Text(formatter.format(booking.dateTime),
                style: OwnerTextStyles.subtitle.copyWith(fontSize: 13)),
            if (onTap != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: onTap,
                  icon: const Icon(Icons.chevron_right),
                  label: const Text('View Details'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Color _statusColor(OwnerBookingStatus status) {
    switch (status) {
      case OwnerBookingStatus.upcoming:
        return OwnerTheme.primary;
      case OwnerBookingStatus.completed:
        return Colors.green;
      case OwnerBookingStatus.cancelled:
        return Colors.redAccent;
    }
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

  String _initials(String name) {
    final parts =
        name.trim().split(RegExp(r'\s+')).where((part) => part.isNotEmpty);
    final list = parts.toList();
    if (list.isEmpty) return '';
    final first = list[0].substring(0, 1).toUpperCase();
    final second =
        list.length > 1 ? list[1].substring(0, 1).toUpperCase() : '';
    return '$first$second';
  }
}

class _StatusPill extends StatelessWidget {
  final Color color;
  final String label;

  const _StatusPill({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(30)),
      child: Text(label,
          style: TextStyle(color: color, fontWeight: FontWeight.w600)),
    );
  }
}
