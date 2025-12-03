import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class BookingReceiptScreen extends StatelessWidget {
  const BookingReceiptScreen({super.key, this.booking});

  final OwnerBooking? booking;

  @override
  Widget build(BuildContext context) {
    final ownerName = context.read<AuthProvider>().currentUser?.displayName;
    final fmt = DateFormat('EEE, d MMM yyyy • hh:mm a');

    final data = booking;
    if (data == null) {
      return Scaffold(
        appBar:
            const CutlineAppBar(title: 'Booking Receipt', centerTitle: true),
        body: const Center(child: Text('No booking data')),
      );
    }

    final services = [
      _ServiceLine(
          title: data.service,
          price: '৳${data.price}',
          icon: Icons.content_cut),
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
                salonDetails: _SalonDetails(
                  name: data.salonName,
                  address: '—',
                  phone: '',
                  email: '',
                  stylist: ownerName ?? 'Stylist',
                  appointment: fmt.format(data.dateTime),
                ),
                customer: _CustomerInfo(
                  name: data.customerName,
                  phone: '',
                  email: '',
                ),
                services: services,
                totals: _PriceSummary(
                  subtotal: '৳${data.price}',
                  serviceCharge: '৳0',
                  total: '৳${data.price}',
                ),
                paymentMethod: data.paymentMethod,
                status: data.status,
              ),
            ),
            const SizedBox(height: CutlineSpacing.lg),
            Padding(
              padding: CutlineSpacing.section,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: CutlineButtons.primary(
                      padding: const EdgeInsets.symmetric(vertical: 14)),
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Back to Bookings',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
  final String paymentMethod;
  final OwnerBookingStatus status;

  const _ReceiptCard({
    required this.salonDetails,
    required this.customer,
    required this.services,
    required this.totals,
    required this.paymentMethod,
    required this.status,
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
            if (salonDetails.phone.isNotEmpty) 'Phone: ${salonDetails.phone}',
            if (salonDetails.email.isNotEmpty) 'Email: ${salonDetails.email}',
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
          if (customer.phone.isNotEmpty)
            _InfoRow(label: 'Phone', value: customer.phone),
          if (customer.email.isNotEmpty)
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
          _PaymentStatusCard(paymentMethod: paymentMethod, status: status),
          const SizedBox(height: CutlineSpacing.lg),
          const Center(
            child: Column(
              children: [
                Text('Thank you for choosing CutLine 💈',
                    style: CutlineTextStyles.subtitle),
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

  const _ServiceLine(
      {required this.title, required this.price, required this.icon});

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

  const _PriceRow(
      {required this.label, required this.value, this.emphasize = false});

  @override
  Widget build(BuildContext context) {
    final style =
        emphasize ? CutlineTextStyles.title : CutlineTextStyles.subtitleBold;
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
  final String paymentMethod;
  final OwnerBookingStatus status;

  const _PaymentStatusCard({
    required this.paymentMethod,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    final statusLabel = _statusLabel(status);
    return Container(
      width: double.infinity,
      padding: CutlineSpacing.card,
      decoration: BoxDecoration(
        color: CutlineColors.secondaryBackground,
        borderRadius: BorderRadius.circular(CutlineDecorations.radius),
      ),
      child: Column(
        children: [
          _InfoRow(label: '💳 Payment Method', value: paymentMethod),
          const SizedBox(height: 8),
          _InfoRow(label: '✅ Booking Status', value: statusLabel),
        ],
      ),
    );
  }

  String _statusLabel(OwnerBookingStatus status) {
    switch (status) {
      case OwnerBookingStatus.upcoming:
        return 'Upcoming';
      case OwnerBookingStatus.completed:
        return 'Completed';
      case OwnerBookingStatus.cancelled:
        return 'Cancelled';
    }
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
        Icon(icon, color: CutlineColors.accent),
        const SizedBox(width: 8),
        Text(title, style: CutlineTextStyles.title),
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

  const _CustomerInfo({
    required this.name,
    required this.phone,
    required this.email,
  });
}

class _PriceSummary {
  final String subtotal;
  final String serviceCharge;
  final String total;

  const _PriceSummary({
    required this.subtotal,
    required this.serviceCharge,
    required this.total,
  });
}
