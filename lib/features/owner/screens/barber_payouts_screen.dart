import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/barber_payouts_provider.dart';
import 'package:cutline/features/owner/screens/barber_payout_detail_screen.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class OwnerBarberPayoutsScreen extends StatelessWidget {
  const OwnerBarberPayoutsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider =
            OwnerBarberPayoutsProvider(authProvider: context.read<AuthProvider>());
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<OwnerBarberPayoutsProvider>();
        final currency = NumberFormat.currency(symbol: '৳', decimalDigits: 0);
        final totalTips = provider.barbers
            .fold<int>(0, (acc, item) => acc + item.totalTips);
        final paidTips = provider.barbers
            .fold<int>(0, (acc, item) => acc + item.paidTips);
        final dueTips =
            provider.barbers.fold<int>(0, (acc, item) => acc + item.dueTips);

        return Scaffold(
          backgroundColor: CutlineColors.secondaryBackground,
          appBar: AppBar(
            title: const Text('Barber payouts'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : RefreshIndicator(
                  onRefresh: () => provider.load(),
                  child: ListView(
                    padding: CutlineSpacing.section.copyWith(bottom: 32),
                    children: [
                      const SizedBox(height: 16),
                      _SummaryCard(
                        total: currency.format(totalTips),
                        paid: currency.format(paidTips),
                        due: currency.format(dueTips),
                      ),
                      const SizedBox(height: 16),
                      _SectionTitle(
                        title: 'Barbers',
                        subtitle: provider.barbers.isEmpty
                            ? 'No barbers yet'
                            : null,
                      ),
                      const SizedBox(height: 8),
                      if (provider.barbers.isEmpty)
                        _EmptyState(
                          message:
                              'No payout data yet. Tips will appear after completed bookings.',
                        )
                      else
                        ...provider.barbers.map((barber) {
                          return _BarberTile(
                            name: barber.barberName,
                            total: currency.format(barber.totalTips),
                            paid: currency.format(barber.paidTips),
                            due: currency.format(barber.dueTips),
                            hasDue: barber.dueTips > 0,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => OwnerBarberPayoutDetailScreen(
                                    barberId: barber.barberId,
                                    barberName: barber.barberName,
                                  ),
                                ),
                              );
                            },
                          );
                        }),
                      if (provider.error != null) ...[
                        const SizedBox(height: 12),
                        Text(provider.error!,
                            style: const TextStyle(color: Colors.red)),
                      ],
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String total;
  final String paid;
  final String due;

  const _SummaryCard({
    required this.total,
    required this.paid,
    required this.due,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: CutlineSpacing.card,
      decoration: CutlineDecorations.card(solidColor: Colors.white),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _SummaryItem(label: 'Total', value: total),
          _SummaryItem(label: 'Paid', value: paid),
          _SummaryItem(label: 'Due', value: due),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryItem({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: CutlineTextStyles.caption),
        const SizedBox(height: 6),
        Text(value,
            style: CutlineTextStyles.subtitleBold.copyWith(fontSize: 16)),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;

  const _SectionTitle({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: CutlineTextStyles.subtitleBold),
        if (subtitle != null) Text(subtitle!, style: CutlineTextStyles.caption),
      ],
    );
  }
}

class _BarberTile extends StatelessWidget {
  final String name;
  final String total;
  final String paid;
  final String due;
  final bool hasDue;
  final VoidCallback onTap;

  const _BarberTile({
    required this.name,
    required this.total,
    required this.paid,
    required this.due,
    required this.hasDue,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: Colors.blueGrey.shade50,
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : 'B',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        title: Text(name, style: CutlineTextStyles.subtitleBold),
        subtitle: Text('Total: $total • Paid: $paid'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('Due', style: CutlineTextStyles.caption),
            Text(
              due,
              style: CutlineTextStyles.subtitleBold.copyWith(
                color: hasDue ? Colors.redAccent : Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Text(message, style: CutlineTextStyles.body),
    );
  }
}
