import 'dart:async';

import 'package:cutline/ui/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

class WaitingListScreen extends StatefulWidget {
  const WaitingListScreen({super.key});

  @override
  State<WaitingListScreen> createState() => _WaitingListScreenState();
}

class _WaitingListScreenState extends State<WaitingListScreen> {
  bool sortAscending = true;
  late Timer _timer;

  final List<_WaitingCustomer> waitingList = [
    const _WaitingCustomer(
      profile: 'https://i.pravatar.cc/150?img=3',
      name: 'Rafi Ahmed',
      barber: 'Kamal',
      service: 'Haircut + Beard',
      timeLeft: 12,
      status: 'In Queue',
    ),
    const _WaitingCustomer(
      profile: 'https://i.pravatar.cc/150?img=4',
      name: 'Jihan Rahman',
      barber: 'Imran',
      service: 'Facial + Beard Trim',
      timeLeft: 3,
      status: 'Serving Soon',
    ),
    const _WaitingCustomer(
      profile: 'https://i.pravatar.cc/150?img=5',
      name: 'Tania Akter',
      barber: 'Sajjad',
      service: 'Hair Color',
      timeLeft: 20,
      status: 'In Queue',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      setState(() {
        for (var i = 0; i < waitingList.length; i++) {
          final entry = waitingList[i];
          if (entry.timeLeft > 0) {
            waitingList[i] = entry.copyWith(timeLeft: entry.timeLeft - 1);
          }
        }
      });
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sorted = [...waitingList]
      ..sort((a, b) => sortAscending ? a.timeLeft.compareTo(b.timeLeft) : b.timeLeft.compareTo(a.timeLeft));

    return Scaffold(
      backgroundColor: CutlineColors.secondaryBackground,
      appBar: CutlineAppBar(
        title: 'Waiting for Service',
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by time',
            onPressed: () => setState(() => sortAscending = !sortAscending),
          ),
        ],
      ),
      body: ListView.builder(
        padding: CutlineSpacing.section.copyWith(top: 16, bottom: 16),
        itemCount: sorted.length,
        itemBuilder: (context, index) {
          final item = sorted[index];
          return CutlineAnimations.staggeredList(
            index: index,
            child: Container(
              margin: const EdgeInsets.only(bottom: CutlineSpacing.sm),
              padding: CutlineSpacing.card,
              decoration: CutlineDecorations.card(solidColor: CutlineColors.background),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(backgroundImage: NetworkImage(item.profile), radius: 28),
                  const SizedBox(width: CutlineSpacing.md),
                  Expanded(child: _WaitingDetails(item: item)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _WaitingDetails extends StatelessWidget {
  final _WaitingCustomer item;

  const _WaitingDetails({required this.item});

  Color _statusColor(String status) {
    switch (status) {
      case 'Serving Soon':
        return Colors.green;
      case 'Cancelled':
        return Colors.red;
      default:
        return CutlineColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(item.status);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(item.name, style: CutlineTextStyles.subtitleBold.copyWith(fontSize: 16)),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
              child: Text(item.status, style: TextStyle(color: statusColor, fontWeight: FontWeight.w600, fontSize: 12)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text('Barber: ${item.barber}', style: CutlineTextStyles.caption.copyWith(fontSize: 13)),
        Text('Service: ${item.service}', style: CutlineTextStyles.caption.copyWith(fontSize: 13)),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.access_time, size: 16, color: CutlineColors.primary),
            const SizedBox(width: 4),
            Text('${item.timeLeft} min left', style: CutlineTextStyles.subtitleBold.copyWith(color: CutlineColors.primary)),
          ],
        ),
      ],
    );
  }
}

class _WaitingCustomer {
  final String profile;
  final String name;
  final String barber;
  final String service;
  final int timeLeft;
  final String status;

  const _WaitingCustomer({
    required this.profile,
    required this.name,
    required this.barber,
    required this.service,
    required this.timeLeft,
    required this.status,
  });

  _WaitingCustomer copyWith({int? timeLeft}) {
    return _WaitingCustomer(
      profile: profile,
      name: name,
      barber: barber,
      service: service,
      timeLeft: timeLeft ?? this.timeLeft,
      status: status,
    );
  }
}
