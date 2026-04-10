import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/user/providers/waiting_list_provider.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:cutline/shared/widgets/cached_profile_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WaitingListScreen extends StatefulWidget {
  final String? salonId;

  const WaitingListScreen({super.key, this.salonId});

  @override
  State<WaitingListScreen> createState() => _WaitingListScreenState();
}

class _WaitingListScreenState extends State<WaitingListScreen> {
  @override
  Widget build(BuildContext context) {
    final currentUserId = context
        .select<AuthProvider, String>((auth) => auth.currentUser?.uid ?? '');
    return ChangeNotifierProvider(
      create: (_) => WaitingListProvider(salonId: widget.salonId)..load(),
      builder: (context, _) {
        final provider = context.watch<WaitingListProvider>();
        final waiting = [...provider.customers];
        final displaySerials = _buildDisplaySerials(waiting);

        return Scaffold(
          backgroundColor: CutlineColors.secondaryBackground,
          appBar: CutlineAppBar(
            title: 'Waiting for Service',
            centerTitle: true,
          ),
          body: provider.isLoading && waiting.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => provider.load(),
                  child: waiting.isEmpty
                      ? ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: CutlineSpacing.section,
                          children: [
                            const SizedBox(height: 40),
                            Center(
                              child: Text(
                                provider.error ??
                                    'No customers are waiting right now.',
                                style: CutlineTextStyles.caption,
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: CutlineSpacing.section
                              .copyWith(top: 16, bottom: 16),
                          itemCount: waiting.length,
                          itemBuilder: (context, index) {
                            final item = waiting[index];
                            final isOwnSpot = currentUserId.isNotEmpty &&
                                item.customerUid == currentUserId;
                            return CutlineAnimations.staggeredList(
                              index: index,
                              child: Container(
                                margin: const EdgeInsets.only(
                                    bottom: CutlineSpacing.sm),
                                padding: CutlineSpacing.card,
                                decoration: _cardDecoration(isOwnSpot),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    CachedProfileImage(
                                      imageUrl: item.avatar.isNotEmpty
                                          ? item.avatar
                                          : null,
                                      radius: 28,
                                      backgroundColor: isOwnSpot
                                          ? CutlineColors.primary
                                              .withValues(alpha: 0.12)
                                          : null,
                                      errorWidget: const Icon(Icons.person),
                                    ),
                                    const SizedBox(width: CutlineSpacing.md),
                                    Expanded(
                                      child: _WaitingDetails(
                                        item: item,
                                        displaySerialNo:
                                            displaySerials[item.id],
                                        isOwnSpot: isOwnSpot,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
        );
      },
    );
  }
}

class _WaitingDetails extends StatelessWidget {
  final WaitingCustomer item;
  final int? displaySerialNo;
  final bool isOwnSpot;

  const _WaitingDetails({
    required this.item,
    this.displaySerialNo,
    this.isOwnSpot = false,
  });

  Color _statusColor(WaitingStatus status) {
    switch (status) {
      case WaitingStatus.servingSoon:
        return Colors.green;
      case WaitingStatus.done:
        return Colors.red;
      case WaitingStatus.waiting:
        return CutlineColors.accent;
    }
  }

  String _statusLabel(WaitingStatus status) {
    switch (status) {
      case WaitingStatus.servingSoon:
        return 'Serving';
      case WaitingStatus.done:
        return 'Completed';
      case WaitingStatus.waiting:
        return 'Waiting';
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name,
                      style: CutlineTextStyles.subtitleBold
                          .copyWith(fontSize: 16)),
                  if (isOwnSpot) ...[
                    const SizedBox(height: 6),
                    const _QueueOwnerChip(label: 'Your spot'),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (displaySerialNo != null) ...[
                  _QueueSerialBadge(number: displaySerialNo!),
                  const SizedBox(height: 8),
                ],
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12)),
                  child: Text(_statusLabel(item.status),
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                          fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Barber: ${item.barber}',
            style: CutlineTextStyles.caption.copyWith(fontSize: 13)),
        Text('Service: ${item.service}',
            style: CutlineTextStyles.caption.copyWith(fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: CutlineColors.primary),
            const SizedBox(width: 4),
            Text(item.dateLabel,
                style: CutlineTextStyles.subtitleBold
                    .copyWith(color: CutlineColors.primary)),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            const Icon(Icons.access_time,
                size: 16, color: CutlineColors.primary),
            const SizedBox(width: 4),
            Text(item.timeLabel,
                style: CutlineTextStyles.subtitleBold
                    .copyWith(color: CutlineColors.primary)),
          ],
        ),
      ],
    );
  }
}

Map<String, int> _buildDisplaySerials(List<WaitingCustomer> customers) {
  final serials = <String, int>{};
  final visibleSerials = <String, int>{};
  for (final item in customers) {
    final barberKey = _barberSortKey(item);
    final previousSerial = visibleSerials[barberKey] ?? 0;
    final displaySerialNo = item.serialNo ?? (previousSerial + 1);
    serials[item.id] = displaySerialNo;
    visibleSerials[barberKey] =
        displaySerialNo > previousSerial ? displaySerialNo : previousSerial;
  }
  return serials;
}

String _barberSortKey(WaitingCustomer item) {
  final serialKey = item.serialBarberKey.trim().toLowerCase();
  if (serialKey.isNotEmpty) return serialKey;
  return item.barber.trim().toLowerCase();
}

BoxDecoration _cardDecoration(bool isOwnSpot) {
  return BoxDecoration(
    color: isOwnSpot
        ? CutlineColors.primary.withValues(alpha: 0.06)
        : CutlineColors.background,
    borderRadius: BorderRadius.circular(CutlineDecorations.radius),
    border: Border.all(
      color: isOwnSpot
          ? CutlineColors.primary.withValues(alpha: 0.32)
          : Colors.transparent,
      width: isOwnSpot ? 1.4 : 1,
    ),
    boxShadow: CutlineDecorations.shadow
        .map((shadow) => shadow.copyWith(
              color: shadow.color.withValues(alpha: isOwnSpot ? 0.12 : 0.08),
            ))
        .toList(),
  );
}

class _QueueSerialBadge extends StatelessWidget {
  final int number;

  const _QueueSerialBadge({required this.number});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: CutlineColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            'Serial',
            style: CutlineTextStyles.caption.copyWith(
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            '#$number',
            style: const TextStyle(
              color: CutlineColors.primary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueOwnerChip extends StatelessWidget {
  final String label;

  const _QueueOwnerChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: CutlineColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: CutlineColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
