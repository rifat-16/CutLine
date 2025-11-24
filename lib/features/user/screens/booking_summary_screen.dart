import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({super.key});

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  String selectedPayment = 'Pay at Salon';

  final List<Map<String, dynamic>> services = const [
    {'name': 'Haircut', 'price': 300},
    {'name': 'Facial', 'price': 500},
    {'name': 'Beard Trim', 'price': 200},
  ];

  int get totalPrice => services.fold(0, (sum, item) => sum + (item['price'] as int)) + 10;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CutlineColors.secondaryBackground,
      appBar: const CutlineAppBar(title: 'Booking Summary', centerTitle: true),
      body: SingleChildScrollView(
        padding: CutlineSpacing.section.copyWith(top: 20, bottom: 32),
        child: Column(
          children: [
            CutlineAnimations.entrance(
              _SummaryCard(
                services: services,
                selectedPayment: selectedPayment,
                onPaymentChanged: (value) => setState(() => selectedPayment = value),
                onConfirm: () => _showConfirmationDialog(context),
                total: totalPrice,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showConfirmationDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Booking Confirmed!', style: CutlineTextStyles.title),
        content: const Text('Your booking has been successfully submitted.'),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: CutlineButtons.primary(),
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('View Booking'),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final List<Map<String, dynamic>> services;
  final String selectedPayment;
  final ValueChanged<String> onPaymentChanged;
  final VoidCallback onConfirm;
  final int total;

  const _SummaryCard({
    required this.services,
    required this.selectedPayment,
    required this.onPaymentChanged,
    required this.onConfirm,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: CutlineSpacing.card,
      decoration: CutlineDecorations.card(solidColor: CutlineColors.background),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Booking Summary', style: CutlineTextStyles.title),
          const Divider(height: 24),
          const _SalonOverview(),
          const Divider(height: 32),
          const _BookingDetails(),
          const Divider(height: 32),
          _ServiceList(services: services),
          const Divider(height: 32),
          const _FeesSection(),
          const SizedBox(height: CutlineSpacing.md),
          _TotalsRow(total: total),
          const Divider(height: 32),
          _PaymentOptions(selectedPayment: selectedPayment, onChanged: onPaymentChanged),
          const SizedBox(height: CutlineSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onConfirm,
              style: CutlineButtons.primary(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Confirm Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalonOverview extends StatelessWidget {
  const _SalonOverview();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundImage: NetworkImage('https://i.pravatar.cc/150?img=12'),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('Urban Fade Salon', style: CutlineTextStyles.subtitleBold),
            SizedBox(height: 2),
            Text('45 Dhanmondi Rd, Dhaka', style: CutlineTextStyles.subtitle),
            Text('📞 017XXXXXXXX', style: CutlineTextStyles.subtitle),
          ],
        ),
      ],
    );
  }
}

class _BookingDetails extends StatelessWidget {
  const _BookingDetails();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _InfoRow(icon: Icons.calendar_today, label: 'Date', value: '10 Nov 2025'),
        _InfoRow(icon: Icons.access_time, label: 'Time', value: '4:30 PM'),
        _InfoRow(icon: Icons.person, label: 'Barber', value: 'Rafi'),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: CutlineColors.primary),
          const SizedBox(width: 10),
          Text(label, style: CutlineTextStyles.subtitleBold),
          const Spacer(),
          Text(value, style: CutlineTextStyles.body),
        ],
      ),
    );
  }
}

class _ServiceList extends StatelessWidget {
  final List<Map<String, dynamic>> services;

  const _ServiceList({required this.services});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Selected Services', style: CutlineTextStyles.title),
        const SizedBox(height: CutlineSpacing.sm),
        ...services.asMap().entries.map(
          (entry) => CutlineAnimations.staggeredList(
            index: entry.key,
            child: ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(entry.value['name'] as String, style: CutlineTextStyles.body.copyWith(fontSize: 16)),
              trailing: Text('৳${entry.value['price']}', style: CutlineTextStyles.subtitleBold),
            ),
          ),
        ),
      ],
    );
  }
}

class _FeesSection extends StatelessWidget {
  const _FeesSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        _FeeRow(label: 'Service Charge', value: '৳10'),
      ],
    );
  }
}

class _FeeRow extends StatelessWidget {
  final String label;
  final String value;

  const _FeeRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: CutlineTextStyles.body),
          Text(value, style: CutlineTextStyles.body),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  final int total;

  const _TotalsRow({required this.total});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text('Total', style: CutlineTextStyles.title),
        Text('৳$total', style: CutlineTextStyles.title.copyWith(color: CutlineColors.primary)),
      ],
    );
  }
}

class _PaymentOptions extends StatelessWidget {
  final String selectedPayment;
  final ValueChanged<String> onChanged;

  const _PaymentOptions({required this.selectedPayment, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Choose Payment Method', style: CutlineTextStyles.title),
        const SizedBox(height: CutlineSpacing.sm),
        Container(
          decoration: BoxDecoration(
            color: CutlineColors.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            children: [
              _PaymentOptionTile(
                label: 'Pay at Salon',
                selected: selectedPayment == 'Pay at Salon',
                onTap: () => onChanged('Pay at Salon'),
              ),
              Divider(height: 1, color: Colors.grey.shade200),
              const _PaymentOptionTile(
                label: 'Online Payment (Coming Soon)',
                selected: false,
                enabled: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PaymentOptionTile extends StatelessWidget {
  final String label;
  final bool selected;
  final bool enabled;
  final VoidCallback? onTap;

  const _PaymentOptionTile({
    required this.label,
    required this.selected,
    this.enabled = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: enabled ? onTap : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: enabled ? CutlineColors.primary : Colors.grey,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: enabled ? CutlineTextStyles.body : CutlineTextStyles.subtitle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
