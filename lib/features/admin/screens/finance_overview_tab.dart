import 'package:flutter/material.dart';

import 'package:cutline/features/admin/models/admin_models.dart';
import 'package:cutline/features/admin/services/admin_service.dart';

class FinanceOverviewTab extends StatefulWidget {
  const FinanceOverviewTab({super.key});

  @override
  State<FinanceOverviewTab> createState() => _FinanceOverviewTabState();
}

class _FinanceOverviewTabState extends State<FinanceOverviewTab> {
  final AdminService _service = AdminService();
  final TextEditingController _salonController = TextEditingController();
  String _status = 'all';
  String _window = 'all';
  late Future<AdminFinanceSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _service.loadFinanceSnapshot();
  }

  @override
  void dispose() {
    _salonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _salonController,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.store_mall_directory_outlined),
                  hintText: 'Filter by salon id or salon name',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _status,
                      decoration: const InputDecoration(labelText: 'Status'),
                      items: const [
                        DropdownMenuItem(
                            value: 'all', child: Text('All statuses')),
                        DropdownMenuItem(
                            value: 'pending', child: Text('Pending')),
                        DropdownMenuItem(
                            value: 'confirmed', child: Text('Confirmed')),
                        DropdownMenuItem(value: 'paid', child: Text('Paid')),
                        DropdownMenuItem(
                            value: 'unpaid', child: Text('Unpaid')),
                        DropdownMenuItem(
                            value: 'partial', child: Text('Partial')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _status = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _window,
                      decoration:
                          const InputDecoration(labelText: 'Date window'),
                      items: const [
                        DropdownMenuItem(value: 'all', child: Text('All time')),
                        DropdownMenuItem(
                            value: '7', child: Text('Last 7 days')),
                        DropdownMenuItem(
                            value: '30', child: Text('Last 30 days')),
                        DropdownMenuItem(
                            value: '90', child: Text('Last 90 days')),
                      ],
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() => _window = value);
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async {
              setState(() => _future = _service.loadFinanceSnapshot());
              await _future;
            },
            child: FutureBuilder<AdminFinanceSnapshot>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError || !snapshot.hasData) {
                  return ListView(
                    padding: const EdgeInsets.all(24),
                    children: const [
                      SizedBox(height: 80),
                      Center(child: Text('Failed to load finance data.')),
                    ],
                  );
                }
                final data = snapshot.data!;
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  children: [
                    _FinanceSection(
                      title: 'Platform Fee Ledger',
                      children: _filterLedger(data.platformFeeLedger),
                    ),
                    const SizedBox(height: 16),
                    _FinanceSection(
                      title: 'Platform Fee Payments',
                      children: _filterPayments(data.platformFeePayments),
                    ),
                    const SizedBox(height: 16),
                    _FinanceSection(
                      title: 'Barber Tip Ledger',
                      children: _filterLedger(data.barberTipLedger),
                    ),
                    const SizedBox(height: 16),
                    _FinanceSection(
                      title: 'Barber Payouts',
                      children: _filterPayments(data.barberPayouts),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _filterLedger(List<AdminFinanceLedgerItem> items) {
    final query = _salonController.text.trim().toLowerCase();
    final now = DateTime.now();
    final filtered = items.where((item) {
      final matchesStatus = _status == 'all' || item.status == _status;
      final salonId = item.salonId.toLowerCase();
      final salonName = item.salonName.toLowerCase();
      final matchesSalon =
          query.isEmpty || salonId.contains(query) || salonName.contains(query);
      final matchesDate = _matchesWindow(item.date, now);
      return matchesStatus && matchesSalon && matchesDate;
    }).toList();
    if (filtered.isEmpty) {
      return const [Text('No matching records.')];
    }
    return filtered
        .map(
          (item) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('৳${item.amount} • ${item.status}'),
            subtitle: Text(
              'Salon: ${item.salonId.isEmpty ? 'n/a' : item.salonId} • Ref: ${item.relatedId} • Paid: ৳${item.paidAmount}',
            ),
            trailing: Text(_formatDate(item.date)),
          ),
        )
        .toList();
  }

  List<Widget> _filterPayments(List<AdminPaymentItem> items) {
    final query = _salonController.text.trim().toLowerCase();
    final now = DateTime.now();
    final filtered = items.where((item) {
      final matchesStatus = _status == 'all' || item.status == _status;
      final salonId = item.salonId.toLowerCase();
      final salonName = item.salonName.toLowerCase();
      final matchesSalon =
          query.isEmpty || salonId.contains(query) || salonName.contains(query);
      final matchesDate = _matchesWindow(item.date, now);
      return matchesStatus && matchesSalon && matchesDate;
    }).toList();
    if (filtered.isEmpty) {
      return const [Text('No matching records.')];
    }
    return filtered
        .map(
          (item) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('৳${item.amount} • ${item.status}'),
            subtitle: Text(
              'Salon: ${item.salonName.isEmpty ? item.salonId : item.salonName} • Method: ${item.paymentMethod}${item.note.isEmpty ? '' : ' • ${item.note}'}',
            ),
            trailing: Text(_formatDate(item.date)),
          ),
        )
        .toList();
  }

  bool _matchesWindow(DateTime? date, DateTime now) {
    if (_window == 'all' || date == null) return true;
    final days = int.tryParse(_window);
    if (days == null) return true;
    return date.isAfter(now.subtract(Duration(days: days)));
  }
}

class _FinanceSection extends StatelessWidget {
  const _FinanceSection({
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime? value) {
  if (value == null) return 'Unknown';
  final mm = value.month.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  return '${value.year}-$mm-$dd';
}
