import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingRequestsScreen extends StatefulWidget {
  const BookingRequestsScreen({super.key});

  @override
  State<BookingRequestsScreen> createState() => _BookingRequestsScreenState();
}

class _BookingRequestsScreenState extends State<BookingRequestsScreen> {
  late List<OwnerBookingRequest> _requests;
  final _formatter = DateFormat('EEE, d MMM • hh:mm a');

  @override
  void initState() {
    super.initState();
    _requests = List.of(kOwnerBookingRequests);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Booking requests'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        itemCount: _requests.length,
        itemBuilder: (_, index) {
          final request = _requests[index];
          return _BookingRequestCard(
            request: request,
            formatter: _formatter,
            onDecision: (status) => _updateRequest(request.id, status),
          );
        },
      ),
    );
  }

  void _updateRequest(String id, OwnerBookingRequestStatus status) {
    setState(() {
      _requests = _requests
          .map((request) =>
              request.id == id ? request.copyWith(status: status) : request)
          .toList();
    });
    final label = status == OwnerBookingRequestStatus.accepted
        ? 'Booking accepted'
        : 'Booking rejected';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(label)));
  }
}

class _BookingRequestCard extends StatelessWidget {
  final OwnerBookingRequest request;
  final DateFormat formatter;
  final ValueChanged<OwnerBookingRequestStatus> onDecision;

  const _BookingRequestCard({
    required this.request,
    required this.formatter,
    required this.onDecision,
  });

  @override
  Widget build(BuildContext context) {
    final bool isPending = request.status == OwnerBookingRequestStatus.pending;
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
              CircleAvatar(
                radius: 28,
                backgroundColor:
                    hasAvatar ? const Color(0xFFE8ECF6) : const Color(0xFF2563EB),
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
                        const Icon(Icons.phone, size: 16, color: Colors.blueGrey),
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
                  icon: Icons.payments_outlined,
                  label: 'Total price',
                  value: '৳${request.totalPrice}',
                  compact: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isPending)
            Row(
              children: [
                Expanded(
                  child: _DecisionButton(
                    label: 'Accept',
                    onTap: () =>
                        onDecision(OwnerBookingRequestStatus.accepted),
                    isPrimary: true,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _DecisionButton(
                    label: 'Reject',
                    onTap: () =>
                        onDecision(OwnerBookingRequestStatus.rejected),
                    isPrimary: false,
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
    final second = parts.length > 1 ? parts[1].substring(0, 1).toUpperCase() : '';
    return '$first$second';
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
  final VoidCallback onTap;
  final bool isPrimary;

  const _DecisionButton({
    required this.label,
    required this.onTap,
    required this.isPrimary,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(18);
    final gradient = const LinearGradient(
      colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return DecoratedBox(
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
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Center(
              child: Text(
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
    );
  }
}
