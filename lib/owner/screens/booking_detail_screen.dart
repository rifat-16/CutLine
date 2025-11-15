import 'package:cutline/ui/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

class BookingReceiptScreen extends StatelessWidget {
  const BookingReceiptScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const salonDetails = _SalonDetails(
      name: 'Salon Luxe',
      address: '123 Main Street, Dhaka',
      phone: '+880 1712 345678',
      email: 'salonluxe@example.com',
      stylist: 'Rafi Uddin',
      appointment: '12 Nov 2025, 3:00 PM',
    );

    const customer = _CustomerInfo(name: 'Boss', phone: '+880 1999 556677', email: 'boss@email.com');

    const services = [
      _ServiceLine(title: 'Haircut', price: '৳250', icon: Icons.content_cut),
      _ServiceLine(title: 'Beard Trim', price: '৳150', icon: Icons.face_6_outlined),
    ];

    return Scaffold(
      appBar: const CutlineAppBar(title: 'Booking Receipt', centerTitle: true),
      backgroundColor: CutlineColors.secondaryBackground,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            CutlineAnimations.entrance(
              _ReceiptCard(
                salonDetails: salonDetails,
                customer: customer,
                services: services,
                totals: const _PriceSummary(subtotal: '৳400', serviceCharge: '৳40', total: '৳440'),
              ),
            ),
            const SizedBox(height: CutlineSpacing.lg),
            Padding(
              padding: CutlineSpacing.section,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: CutlineButtons.primary(padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to My Bookings', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final _SalonDetails salonDetails;
  final _CustomerInfo customer;
  final List<_ServiceLine> services;
  final _PriceSummary totals;

  const _ReceiptCard({
    required this.salonDetails,
    required this.customer,
    required this.services,
    required this.totals,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: CutlineSpacing.section,
      padding: CutlineSpacing.card,
      decoration: CutlineDecorations.card(solidColor: CutlineColors.background),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.storefront, title: salonDetails.name),
          const SizedBox(height: CutlineSpacing.xs),
          ...[
            salonDetails.address,
            'Phone: ${salonDetails.phone}',
            'Email: ${salonDetails.email}',
            'Stylist: ${salonDetails.stylist}',
            'Date: ${salonDetails.appointment}',
          ].map((line) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(line, style: CutlineTextStyles.body),
          )),
          const Divider(height: 32),
          const Text('Customer Information', style: CutlineTextStyles.title),
          const SizedBox(height: CutlineSpacing.sm),
          _InfoRow(label: 'Name', value: customer.name),
          _InfoRow(label: 'Phone', value: customer.phone),
          _InfoRow(label: 'Email', value: customer.email),
          const Divider(height: 32),
          const Text('Service Details', style: CutlineTextStyles.title),
          const SizedBox(height: CutlineSpacing.sm),
          ...services,
          const Divider(height: 32),
          _PriceRow(label: 'Subtotal', value: totals.subtotal),
          _PriceRow(label: 'Service Charge', value: totals.serviceCharge),
          const Divider(height: 32),
          _PriceRow(label: 'Total', value: totals.total, emphasize: true),
          const SizedBox(height: CutlineSpacing.md),
          const _PaymentStatusCard(),
          const SizedBox(height: CutlineSpacing.lg),
          const Center(
            child: Column(
              children: [
                Text('Thank you for choosing CutLine 💈', style: CutlineTextStyles.subtitle),
                SizedBox(height: 4),
                Text('Powered by CutLine', style: CutlineTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: CutlineTextStyles.subtitleBold),
          Text(value, style: CutlineTextStyles.body),
        ],
      ),
    );
  }
}

class _ServiceLine extends StatelessWidget {
  final String title;
  final String price;
  final IconData icon;

  const _ServiceLine({required this.title, required this.price, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(icon, color: CutlineColors.accent, size: 20),
              const SizedBox(width: 8),
              Text(title, style: CutlineTextStyles.body),
            ],
          ),
          Text(price, style: CutlineTextStyles.subtitleBold),
        ],
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  final String label;
  final String value;
  final bool emphasize;

  const _PriceRow({required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final style = emphasize ? CutlineTextStyles.title : CutlineTextStyles.subtitleBold;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: CutlineTextStyles.body),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _PaymentStatusCard extends StatelessWidget {
  const _PaymentStatusCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: CutlineSpacing.card,
      decoration: BoxDecoration(
        color: CutlineColors.secondaryBackground,
        borderRadius: BorderRadius.circular(CutlineDecorations.radius),
      ),
      child: Column(
        children: const [
          _InfoRow(label: '💳 Payment Method', value: 'Pay at salon'),
          SizedBox(height: 8),
          _InfoRow(label: '✅ Booking Status', value: 'Completed'),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;

  const _SectionTitle({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: CutlineColors.primary),
        const SizedBox(width: 8),
        Text(title, style: CutlineTextStyles.title.copyWith(fontSize: 20)),
      ],
    );
  }
}

class _SalonDetails {
  final String name;
  final String address;
  final String phone;
  final String email;
  final String stylist;
  final String appointment;

  const _SalonDetails({
    required this.name,
    required this.address,
    required this.phone,
    required this.email,
    required this.stylist,
    required this.appointment,
  });
}

class _CustomerInfo {
  final String name;
  final String phone;
  final String email;

  const _CustomerInfo({required this.name, required this.phone, required this.email});
}

class _PriceSummary {
  final String subtotal;
  final String serviceCharge;
  final String total;

  const _PriceSummary({required this.subtotal, required this.serviceCharge, required this.total});
}
