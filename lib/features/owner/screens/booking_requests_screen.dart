import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/booking_requests_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/customer_detail_sheet.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class BookingRequestsScreen extends StatelessWidget {
  const BookingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final auth = context.read<AuthProvider>();
        final provider = BookingRequestsProvider(authProvider: auth);
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<BookingRequestsProvider>();
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          appBar: AppBar(
            title: const Text('Booking requests'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: RefreshIndicator(
            onRefresh: () => provider.load(),
            child: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : provider.requests.isEmpty
                    ? const Center(
                        child: Text('No booking requests right now.'),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                        itemCount: provider.requests.length,
                        itemBuilder: (_, index) {
                          final request = provider.requests[index];
                          return _BookingRequestCard(
                            request: request,
                            formatter: DateFormat('EEE, d MMM • hh:mm a'),
                            isProcessing: provider.isProcessing(request.id),
                            processingDecision:
                                provider.processingDecisionFor(request.id),
                            onDecision: (status) async {
                              await provider.updateStatus(request.id, status);
                            },
                            onOpenDetail: () =>
                                _openCustomerDetails(context, request),
                          );
                        },
                      ),
          ),
        );
      },
    );
  }

  void _openCustomerDetails(BuildContext context, OwnerBookingRequest request) {
    showCustomerDetailSheet(
      context: context,
      item: OwnerQueueItem(
        id: request.id,
        customerName: request.customerName,
        service: request.services.join(', '),
        barberName: request.barberName,
        price: request.totalPrice,
        tipAmount: request.tipAmount,
        status: OwnerQueueStatus.waiting,
        waitMinutes: request.durationMinutes,
        slotLabel: request.id,
        scheduledAt: request.dateTime,
        customerPhone: request.customerPhone,
        customerAvatar: request.customerAvatar,
        customerUid: request.customerUid,
      ),
      onStatusChange: (_) {},
    );
  }
}

class _BookingRequestCard extends StatelessWidget {
  final OwnerBookingRequest request;
  final DateFormat formatter;
  final Future<void> Function(OwnerBookingRequestStatus status) onDecision;
  final VoidCallback onOpenDetail;
  final bool isProcessing;
  final OwnerBookingRequestStatus? processingDecision;

  const _BookingRequestCard({
    required this.request,
    required this.formatter,
    required this.onDecision,
    required this.onOpenDetail,
    required this.isProcessing,
    required this.processingDecision,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPending = request.status == OwnerBookingRequestStatus.pending;
    final bool isAcceptLoading = isProcessing &&
        processingDecision == OwnerBookingRequestStatus.accepted;
    final bool isRejectLoading = isProcessing &&
        processingDecision == OwnerBookingRequestStatus.rejected;
    final servicesLabel = request.services.join(', ');
    final hasAvatar = request.customerAvatar.isNotEmpty;
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              GestureDetector(
                onTap: onOpenDetail,
                child: CircleAvatar(
                  radius: 28,
                  backgroundColor: hasAvatar
                      ? const Color(0xFFE8ECF6)
                      : const Color(0xFF2563EB),
                  backgroundImage:
                      hasAvatar ? NetworkImage(request.customerAvatar) : null,
                  child: hasAvatar
                      ? null
                      : Text(
                          _initials(request.customerName),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      request.customerName,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.phone,
                            size: 16, color: Colors.blueGrey),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            request.customerPhone,
                            style: const TextStyle(color: Colors.black54),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              _StatusPill(status: request.status),
            ],
          ),
          const SizedBox(height: 18),
          _InfoTile(
            icon: Icons.design_services_outlined,
            label: 'Service',
            value: servicesLabel,
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.cut_outlined,
            label: 'Preferred barber',
            value: request.barberName,
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.event_outlined,
            label: 'Date & time',
            value: formatter.format(request.dateTime),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon: Icons.timelapse_outlined,
                  label: 'Duration',
                  value: '${request.durationMinutes} mins',
                  compact: true,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoTile(
                  icon: Icons.volunteer_activism_outlined,
                  label: 'Tip for barber',
                  value: '৳${request.tipAmount}',
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoTile(
            icon: Icons.payments_outlined,
            label: 'Total price',
            value: '৳${request.totalPrice}',
          ),
          const SizedBox(height: 16),
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: _DecisionButton(
                    label: 'Accept',
                    onTap: () => onDecision(OwnerBookingRequestStatus.accepted),
                    isPrimary: true,
                    isDisabled: isProcessing,
                    isLoading: isAcceptLoading,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DecisionButton(
                    label: 'Reject',
                    onTap: () => _showRejectConfirmation(context),
                    isPrimary: false,
                    isDisabled: isProcessing,
                    isLoading: isRejectLoading,
                  ),
                ),
              ],
            )
          else
            Text(
              request.status == OwnerBookingRequestStatus.accepted
                  ? 'Customer notified. Slot locked.'
                  : 'Customer will be notified about rejection.',
              style: const TextStyle(color: Colors.black54),
            ),
        ],
      ),
    );
  }

  String _initials(String name) {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    final first = parts[0].substring(0, 1).toUpperCase();
    final second =
        parts.length > 1 ? parts[1].substring(0, 1).toUpperCase() : '';
    return '$first$second';
  }

  Future<void> _showRejectConfirmation(BuildContext context) async {
    final shouldReject = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Confirm Rejection',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: const Text(
            'Are you sure you want to reject this booking request?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: Colors.grey,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(true);
              },
              child: const Text(
                'Reject',
                style: TextStyle(
                  color: Color(0xFFE53935),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldReject == true) {
      await onDecision(OwnerBookingRequestStatus.rejected);
    }
  }
}

class _StatusPill extends StatelessWidget {
  final OwnerBookingRequestStatus status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;
    switch (status) {
      case OwnerBookingRequestStatus.pending:
        color = Colors.orangeAccent;
        label = 'Pending';
        break;
      case OwnerBookingRequestStatus.accepted:
        color = Colors.green;
        label = 'Accepted';
        break;
      case OwnerBookingRequestStatus.rejected:
        color = Colors.redAccent;
        label = 'Rejected';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w600, fontSize: 13)),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool compact;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: compact ? 18 : 20, color: Colors.blueGrey),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: compact ? 12 : 13,
                  color: Colors.black54,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  fontSize: compact ? 14 : 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _DecisionButton extends StatelessWidget {
  final String label;
  final Future<void> Function()? onTap;
  final bool isPrimary;
  final bool isDisabled;
  final bool isLoading;

  const _DecisionButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
    required this.isDisabled,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);
    final gradient = const LinearGradient(
      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Opacity(
      opacity: isDisabled && !isLoading ? 0.7 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          gradient: isPrimary ? gradient : null,
          color: isPrimary ? null : Colors.white,
          border: isPrimary
              ? null
              : Border.all(color: const Color(0xFFE53935), width: 1.4),
          boxShadow: isPrimary
              ? [
                  BoxShadow(
                    color: const Color(0xFF2563EB).withValues(alpha: 0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            borderRadius: borderRadius,
            onTap: isDisabled || onTap == null
                ? null
                : () async {
                    await onTap!.call();
                  },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Center(
                child: isLoading
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            isPrimary
                                ? Colors.white
                                : const Color(0xFFE53935),
                          ),
                        ),
                      )
                    : Text(
                        label,
                        style: TextStyle(
                          color: isPrimary ? Colors.white : const Color(0xFFE53935),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
