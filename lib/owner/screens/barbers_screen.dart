import 'package:cutline/owner/screens/add_barber_screen.dart';
import 'package:cutline/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class OwnerBarbersScreen extends StatefulWidget {
  const OwnerBarbersScreen({super.key});

  @override
  State<OwnerBarbersScreen> createState() => _OwnerBarbersScreenState();
}

class _OwnerBarbersScreenState extends State<OwnerBarbersScreen> {
  final List<OwnerBarber> _barbers = List.of(kOwnerBarbers);

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredBarbers();

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text('Barbers'),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddBarber,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('Add barber'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          if (filtered.isEmpty)
            _EmptyState(
                message:
                    'No barbers in this state right now. Try another filter.')
          else
            ...filtered.map(
              (barber) => _BarberCard(
                barber: barber,
                onMoreInfo: () => _showBarberDetails(barber),
              ),
            ),
        ],
      ),
    );
  }

  List<OwnerBarber> _filteredBarbers() => _barbers;

  Future<void> _openAddBarber() async {
    final result = await Navigator.push<OwnerBarber>(
      context,
      MaterialPageRoute(builder: (_) => const AddBarberScreen()),
    );
    if (result != null) {
      setState(() => _barbers.add(result));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${result.name} added to team')),
      );
    }
  }

  void _showBarberDetails(OwnerBarber barber) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (_) => _BarberDetailSheet(barber: barber),
    );
  }
}

class _BarberCard extends StatelessWidget {
  final OwnerBarber barber;
  final VoidCallback onMoreInfo;

  const _BarberCard({required this.barber, required this.onMoreInfo});

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(barber.status);
    final statusLabel = _statusLabel(barber.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: statusColor.withValues(alpha: 0.12)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x11000000), blurRadius: 18, offset: Offset(0, 10))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: statusColor.withValues(alpha: 0.12),
                child: Text(
                  barber.name
                      .split(' ')
                      .where((part) => part.isNotEmpty)
                      .map((part) => part[0])
                      .take(2)
                      .join()
                      .toUpperCase(),
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(barber.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(barber.specialization,
                        style: const TextStyle(
                            color: Colors.black54, fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(Icons.star_rounded, color: Colors.amber.shade400, size: 20),
              const SizedBox(width: 4),
              Text('${barber.rating}',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 16),
              const Icon(Icons.check_circle_outline,
                  color: Color(0xFF10B981), size: 18),
              const SizedBox(width: 4),
              Text('${barber.servedToday} served today',
                  style: const TextStyle(color: Colors.black54)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.schedule_outlined,
                  color: Colors.black45, size: 18),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  barber.nextClient ?? 'Next slot free',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline)),
              IconButton(
                  onPressed: () {}, icon: const Icon(Icons.phone_outlined)),
            ],
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onMoreInfo,
              icon: const Icon(Icons.info_outline),
              label: const Text('See more info'),
            ),
          ),
        ],
      ),
    );
  }

  Color _statusColor(OwnerBarberStatus status) => _barberStatusColor(status);

  String _statusLabel(OwnerBarberStatus status) => _barberStatusLabel(status);
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        children: [
          const Icon(Icons.chrome_reader_mode_outlined,
              size: 30, color: Colors.blueGrey),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

class _BarberDetailSheet extends StatelessWidget {
  final OwnerBarber barber;

  const _BarberDetailSheet({required this.barber});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                    color: Colors.black12,
                    borderRadius: BorderRadius.circular(20)),
              ),
            ),
            const SizedBox(height: 18),
            Text(barber.name,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(barber.specialization,
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            _DetailInfoRow(
                icon: Icons.email_outlined,
                label: 'Email',
                value: barber.email),
            const SizedBox(height: 12),
            _DetailInfoRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: barber.phone),
            const SizedBox(height: 12),
            _DetailInfoRow(
                icon: Icons.lock_outline,
                label: 'Password',
                value: barber.password),
            const SizedBox(height: 12),
            _DetailInfoRow(
                icon: Icons.flag_outlined,
                label: 'Status',
                value: _barberStatusLabel(barber.status)),
            const SizedBox(height: 18),
            Text(
                'Rating • ${barber.rating.toStringAsFixed(1)}   |   Served today • ${barber.servedToday}',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailInfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailInfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueGrey),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: const TextStyle(
                      fontSize: 11, color: Colors.black54, letterSpacing: 0.6)),
              const SizedBox(height: 4),
              Text(value,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600)),
            ],
          ),
        )
      ],
    );
  }
}

Color _barberStatusColor(OwnerBarberStatus status) {
  switch (status) {
    case OwnerBarberStatus.onFloor:
      return const Color(0xFF2563EB);
    case OwnerBarberStatus.onBreak:
      return const Color(0xFFF97316);
    case OwnerBarberStatus.offDuty:
      return Colors.blueGrey;
  }
}

String _barberStatusLabel(OwnerBarberStatus status) {
  switch (status) {
    case OwnerBarberStatus.onFloor:
      return 'On floor';
    case OwnerBarberStatus.onBreak:
      return 'On break';
    case OwnerBarberStatus.offDuty:
      return 'Off duty';
  }
}
