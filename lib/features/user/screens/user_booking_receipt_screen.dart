import 'package:cutline/features/user/providers/booking_receipt_provider.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BookingReceiptScreen extends StatelessWidget {
  final String salonId;
  final String bookingId;

  const BookingReceiptScreen({
    super.key,
    required this.salonId,
    required this.bookingId,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BookingReceiptProvider(
        salonId: salonId,
        bookingId: bookingId,
      )..load(),
      builder: (context, _) {
        final provider = context.watch<BookingReceiptProvider>();
        final data = provider.data;

        return Scaffold(
          appBar: const CutlineAppBar(title: 'Booking Receipt', centerTitle: true),
          backgroundColor: CutlineColors.secondaryBackground,
          body: provider.isLoading && data == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    children: [
                      if (provider.error != null && data == null)
                        Padding(
                          padding: CutlineSpacing.section,
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      if (data != null)
                        CutlineAnimations.entrance(
                          _ReceiptCard(
                            data: data,
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
                            child: const Text('Back to My Bookings',
                                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }
}

class _ReceiptCard extends StatelessWidget {
  final BookingReceiptData data;

  const _ReceiptCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final services = data.services
        .map((s) => _ServiceLine(
              title: s.name,
              price: '৳${s.price}',
              icon: Icons.content_cut,
            ))
        .toList();
    final totals = _PriceSummary(
      subtotal: '৳${data.subtotal}',
      serviceCharge: '৳${data.serviceCharge}',
      total: '৳${data.total}',
    );
    return Container(
      width: double.infinity,
      margin: CutlineSpacing.section,
      padding: CutlineSpacing.card,
      decoration: CutlineDecorations.card(solidColor: CutlineColors.background),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionTitle(icon: Icons.storefront, title: data.salonName),
          const SizedBox(height: CutlineSpacing.xs),
          ...[
            data.address.isNotEmpty ? data.address : 'Address unavailable',
            'Phone: ${data.contact.isNotEmpty ? data.contact : 'N/A'}',
            'Email: ${data.email.isNotEmpty ? data.email : 'N/A'}',
            if (data.barberName.isNotEmpty) 'Stylist: ${data.barberName}',
            'Date: ${data.date} ${data.time}',
          ].map((line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(line, style: CutlineTextStyles.body),
              )),
          const Divider(height: 32),
          const Text('Customer Information', style: CutlineTextStyles.title),
          const SizedBox(height: CutlineSpacing.sm),
          _InfoRow(label: 'Name', value: data.customerName.isNotEmpty ? data.customerName : 'N/A'),
          _InfoRow(label: 'Phone', value: data.customerPhone.isNotEmpty ? data.customerPhone : 'N/A'),
          _InfoRow(label: 'Email', value: data.customerEmail.isNotEmpty ? data.customerEmail : 'N/A'),
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
          _PaymentStatusCard(
            paymentMethod: data.paymentMethod,
            status: data.status,
          ),
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
  final String paymentMethod;
  final String status;

  const _PaymentStatusCard({
    required this.paymentMethod,
    required this.status,
  });

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
        children: [
          _InfoRow(label: '💳 Payment Method', value: paymentMethod),
          const SizedBox(height: 8),
          _InfoRow(label: '✅ Booking Status', value: status),
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

class _PriceSummary {
  final String subtotal;
  final String serviceCharge;
  final String total;

  const _PriceSummary({required this.subtotal, required this.serviceCharge, required this.total});
}
