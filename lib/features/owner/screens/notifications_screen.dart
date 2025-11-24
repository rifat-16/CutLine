import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class OwnerNotificationsScreen extends StatelessWidget {
  const OwnerNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pendingRequest = _latestPendingRequest();
    final formatter = DateFormat('EEE, d MMM • hh:mm a');

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('New booking request'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        child: pendingRequest == null
            ? const _EmptyNewRequest()
            : _NewBookingHighlight(
                request: pendingRequest,
                formatter: formatter,
              ),
      ),
    );
  }

  OwnerBookingRequest? _latestPendingRequest() {
    for (final request in kOwnerBookingRequests) {
      if (request.status == OwnerBookingRequestStatus.pending) {
        return request;
      }
    }
    return null;
  }
}

class _NewBookingHighlight extends StatelessWidget {
  final OwnerBookingRequest request;
  final DateFormat formatter;

  const _NewBookingHighlight({
    required this.request,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final service =
        request.services.isEmpty ? 'Custom service' : request.services.first;
    final appointment = formatter.format(request.dateTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Incoming request',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            gradient: const LinearGradient(
              colors: [Color(0xFFFFFFFF), Color(0xFFF2F7FF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 24,
                offset: const Offset(0, 16),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _CustomerAvatar(name: request.customerName),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          request.customerName,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'sent a new booking request',
                          style: TextStyle(
                            color: Colors.blueGrey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text(
                      'New',
                      style: TextStyle(
                          color: Colors.deepPurple,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _InfoRow(
                icon: Icons.design_services_outlined,
                label: 'Service requested',
                value: service,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.person_pin_circle_outlined,
                label: 'Preferred barber',
                value: request.barberName,
              ),
              const SizedBox(height: 12),
              _InfoRow(
                icon: Icons.calendar_today_outlined,
                label: 'Date & time',
                value: appointment,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: Colors.indigo.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.indigo),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.blueGrey)),
                const SizedBox(height: 4),
                Text(value,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerAvatar extends StatelessWidget {
  final String name;

  const _CustomerAvatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final initials = _initials(name);
    final color = _avatarColor(name);
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
              color: Colors.white, fontWeight: FontWeight.w700, fontSize: 24),
        ),
      ),
    );
  }
}

class _EmptyNewRequest extends StatelessWidget {
  const _EmptyNewRequest();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.blueGrey.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.inbox_outlined,
              size: 64, color: Color(0xFF2563EB)),
          const SizedBox(height: 16),
          const Text('No new booking request',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            'You will see the latest customer request here as soon as someone books a slot.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.blueGrey.shade600),
          ),
          const SizedBox(height: 20),
          TextButton(
            onPressed: () {
              Navigator.maybePop(context);
            },
            child: const Text('Back to dashboard'),
          ),
        ],
      ),
    );
  }
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final list = parts.toList();
  if (list.isEmpty) {
    return '--';
  }
  if (list.length == 1) {
    final word = list.first;
    if (word.length >= 2) {
      return (word[0] + word[1]).toUpperCase();
    }
    return word[0].toUpperCase();
  }
  final first = list.first[0];
  final last = list.last[0];
  return (first + last).toUpperCase();
}

Color _avatarColor(String name) {
  const colors = [
    Color(0xFF2563EB),
    Color(0xFF7C3AED),
    Color(0xFFEC4899),
    Color(0xFF0EA5E9),
    Color(0xFF10B981),
    Color(0xFFF97316),
  ];
  final index = name.hashCode.abs() % colors.length;
  return colors[index];
}
