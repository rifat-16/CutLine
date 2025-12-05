import 'package:cutline/features/user/providers/booking_summary_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BookingSummaryScreen extends StatefulWidget {
  final String salonId;
  final String salonName;
  final List<String> services;
  final String barberName;
  final DateTime date;
  final String time;
  final String customerName;
  final String customerPhone;
  final String customerEmail;
  final String customerUid;

  const BookingSummaryScreen({
    super.key,
    required this.salonId,
    required this.salonName,
    required this.services,
    required this.barberName,
    required this.date,
    required this.time,
    required this.customerName,
    required this.customerPhone,
    required this.customerEmail,
    required this.customerUid,
  });

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  String selectedPayment = 'Pay at Salon';

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => BookingSummaryProvider(
        salonId: widget.salonId,
        salonName: widget.salonName,
        selectedServices: widget.services,
        selectedBarber: widget.barberName,
        selectedDate: widget.date,
        selectedTime: widget.time,
        customerName: widget.customerName,
        customerPhone: widget.customerPhone,
        customerEmail: widget.customerEmail,
        customerUid: widget.customerUid,
      )..load(),
      builder: (context, _) {
        final provider = context.watch<BookingSummaryProvider>();
        final services = provider.services
            .map((s) => {'name': s.name, 'price': s.price})
            .toList();
        return Scaffold(
          backgroundColor: CutlineColors.secondaryBackground,
          appBar:
              const CutlineAppBar(title: 'Booking Summary', centerTitle: true),
          body: provider.isLoading && provider.services.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding:
                      CutlineSpacing.section.copyWith(top: 20, bottom: 32),
                  child: Column(
                    children: [
                      if (provider.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      CutlineAnimations.entrance(
                        _SummaryCard(
                          salonName: widget.salonName,
                          address: provider.address,
                          contact: provider.contact,
                          rating: provider.rating,
                          barberName: widget.barberName,
                          dateLabel: provider.formattedDate,
                          timeLabel: widget.time,
                          services: services,
                          selectedPayment: selectedPayment,
                          onPaymentChanged: (value) =>
                              setState(() => selectedPayment = value),
                          onConfirm: () => _handleConfirm(context),
                          total: provider.total,
                          serviceCharge: provider.serviceCharge,
                          isSaving: provider.isSaving,
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Future<void> _handleConfirm(BuildContext context) async {
    final provider = context.read<BookingSummaryProvider>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final success = await provider.saveBooking(selectedPayment);
    if (!mounted) return;
    if (!success) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not confirm booking.')),
      );
      return;
    }

    showDialog<void>(
      context: navigator.context,
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
                Navigator.of(context, rootNavigator: true).pop(); // close dialog
                Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil(
                  AppRoutes.myBookings,
                  (route) => false,
                );
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
  final String salonName;
  final String address;
  final String contact;
  final double rating;
  final String barberName;
  final String dateLabel;
  final String timeLabel;
  final List<Map<String, dynamic>> services;
  final String selectedPayment;
  final ValueChanged<String> onPaymentChanged;
  final VoidCallback onConfirm;
  final int total;
  final int serviceCharge;
  final bool isSaving;

  const _SummaryCard({
    required this.salonName,
    required this.address,
    required this.contact,
    required this.rating,
    required this.barberName,
    required this.dateLabel,
    required this.timeLabel,
    required this.services,
    required this.selectedPayment,
    required this.onPaymentChanged,
    required this.onConfirm,
    required this.total,
    required this.serviceCharge,
    required this.isSaving,
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
          _SalonOverview(
            salonName: salonName,
            address: address,
            contact: contact,
            rating: rating,
          ),
          const Divider(height: 32),
          _BookingDetails(
            dateLabel: dateLabel,
            timeLabel: timeLabel,
            barberName: barberName,
          ),
          const Divider(height: 32),
          _ServiceList(services: services),
          const Divider(height: 32),
          _FeesSection(serviceCharge: serviceCharge),
          const SizedBox(height: CutlineSpacing.md),
          _TotalsRow(total: total),
          const Divider(height: 32),
          _PaymentOptions(selectedPayment: selectedPayment, onChanged: onPaymentChanged),
          const SizedBox(height: CutlineSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isSaving ? null : onConfirm,
              style: CutlineButtons.primary(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: isSaving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Confirm Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}

class _SalonOverview extends StatelessWidget {
  final String salonName;
  final String address;
  final String contact;
  final double rating;

  const _SalonOverview({
    required this.salonName,
    required this.address,
    required this.contact,
    required this.rating,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const CircleAvatar(
          radius: 26,
          backgroundColor: Colors.grey,
          child: Icon(Icons.store, color: Colors.white),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(salonName.isNotEmpty ? salonName : 'Salon',
                style: CutlineTextStyles.subtitleBold),
            const SizedBox(height: 2),
            Text(
              address.isNotEmpty ? address : 'Address unavailable',
              style: CutlineTextStyles.subtitle,
            ),
            Text(
              contact.isNotEmpty ? '📞 $contact' : 'Contact unavailable',
              style: CutlineTextStyles.subtitle,
            ),
            Text('⭐ ${rating.toStringAsFixed(1)}',
                style: CutlineTextStyles.caption),
          ],
        ),
      ],
    );
  }
}

class _BookingDetails extends StatelessWidget {
  final String dateLabel;
  final String timeLabel;
  final String barberName;

  const _BookingDetails({
    required this.dateLabel,
    required this.timeLabel,
    required this.barberName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _InfoRow(icon: Icons.calendar_today, label: 'Date', value: dateLabel),
        _InfoRow(icon: Icons.access_time, label: 'Time', value: timeLabel),
        _InfoRow(icon: Icons.person, label: 'Barber', value: barberName),
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
  final int serviceCharge;

  const _FeesSection({required this.serviceCharge});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _FeeRow(label: 'Service Charge', value: '৳$serviceCharge'),
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
