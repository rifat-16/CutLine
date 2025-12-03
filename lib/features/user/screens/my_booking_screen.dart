import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

class MyBookingScreen extends StatelessWidget {
  const MyBookingScreen({super.key});

  final List<_Booking> _upcomingBookings = const [
    _Booking(
      image: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=facearea&w=400&h=200',
      salon: 'Chic Cuts Salon',
      location: '123 Main St, Springfield',
      services: ['Hair Cut', 'Hair Wash'],
      datetime: 'Fri, 20 Jun 2024 • 2:30 PM',
    ),
    _Booking(
      image: 'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?auto=format&fit=facearea&w=400&h=200',
      salon: 'Urban Style Studio',
      location: '456 Park Ave, Metropolis',
      services: ['Beard Trim', 'Shave'],
      datetime: 'Mon, 24 Jun 2024 • 5:00 PM',
    ),
  ];

  final List<_Booking> _completedBookings = const [
    _Booking(
      image: 'https://images.unsplash.com/photo-1517841905240-472988babdf9?auto=format&fit=facearea&w=400&h=200',
      salon: 'Glamour Lounge',
      location: '789 Elm St, Gotham',
      services: ['Hair Color', 'Blow Dry'],
      datetime: 'Tue, 11 Jun 2024 • 1:00 PM',
    ),
  ];

  final List<_Booking> _cancelledBookings = const [
    _Booking(
      image: 'https://images.unsplash.com/photo-1515378791036-0648a3ef77b2?auto=format&fit=facearea&w=400&h=200',
      salon: 'Classic Cutz',
      location: '321 Oak St, Star City',
      services: ['Hair Cut'],
      datetime: 'Sat, 15 Jun 2024 • 11:00 AM',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: CutlineColors.secondaryBackground,
        appBar: CutlineAppBar(
          title: 'Bookings',
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Container(
              color: CutlineColors.background,
              child: TabBar(
                indicatorColor: CutlineColors.primary,
                labelColor: CutlineColors.primary,
                unselectedLabelColor: Colors.grey,
                labelStyle: CutlineTextStyles.subtitleBold,
                tabs: const [
                  Tab(text: 'Upcoming'),
                  Tab(text: 'Completed'),
                  Tab(text: 'Cancelled'),
                ],
              ),
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _BookingList(
              bookings: _upcomingBookings,
              emptyLabel: 'No upcoming bookings.',
              showCancel: true,
              showReceipt: true,
              onCancel: (context) => _showCancelDialog(context),
            ),
            _BookingList(
              bookings: _completedBookings,
              emptyLabel: 'No completed bookings.',
              showCancel: false,
              showReceipt: true,
            ),
            _BookingList(
              bookings: _cancelledBookings,
              emptyLabel: 'No cancelled bookings.',
              showCancel: false,
              showReceipt: false,
              isCancelledList: true,
            ),
          ],
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Booking', style: CutlineTextStyles.title),
        content: const Text(
          'Are you sure you want to cancel? Canceling your appointment will remove it from your upcoming bookings.',
          style: CutlineTextStyles.body,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _showCancelSuccessDialog(context);
            },
            child: const Text('Yes, Cancel Booking', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Appointment', style: CutlineTextStyles.link),
          ),
        ],
      ),
    );
  }

  void _showCancelSuccessDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Icon(Icons.check_circle, color: CutlineColors.primary, size: 40),
            SizedBox(height: 12),
            Text('Booking Canceled', style: CutlineTextStyles.title),
          ],
        ),
        content: const Text('Your appointment has been successfully canceled.', style: CutlineTextStyles.body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Back to Bookings', style: CutlineTextStyles.link),
          ),
        ],
      ),
    );
  }
}

class _BookingList extends StatelessWidget {
  final List<_Booking> bookings;
  final String emptyLabel;
  final bool showCancel;
  final bool showReceipt;
  final bool isCancelledList;
  final void Function(BuildContext context)? onCancel;

  const _BookingList({
    required this.bookings,
    required this.emptyLabel,
    required this.showCancel,
    required this.showReceipt,
    this.isCancelledList = false,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (bookings.isEmpty) {
      return Center(child: Text(emptyLabel, style: CutlineTextStyles.subtitle));
    }

    return ListView.separated(
      padding: CutlineSpacing.section.copyWith(top: 20, bottom: 20),
      itemCount: bookings.length,
      separatorBuilder: (_, __) => const SizedBox(height: CutlineSpacing.md),
      itemBuilder: (context, index) {
        final booking = bookings[index];
        return CutlineAnimations.staggeredList(
          index: index,
          child: _BookingCard(
            booking: booking,
            showCancel: showCancel,
            showReceipt: showReceipt,
            isCancelled: isCancelledList,
            onCancel: showCancel ? () => onCancel?.call(context) : null,
          ),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final _Booking booking;
  final bool showCancel;
  final bool showReceipt;
  final bool isCancelled;
  final VoidCallback? onCancel;

  const _BookingCard({
    required this.booking,
    required this.showCancel,
    required this.showReceipt,
    required this.isCancelled,
    this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CutlineDecorations.card(solidColor: CutlineColors.background),
      padding: CutlineSpacing.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(booking.datetime, style: CutlineTextStyles.subtitleBold),
              if (isCancelled)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text('Cancelled', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: CutlineSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  booking.image,
                  width: 70,
                  height: 70,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 70,
                    height: 70,
                    color: Colors.grey.shade200,
                    child: const Icon(Icons.image, color: Colors.grey),
                  ),
                ),
              ),
              const SizedBox(width: CutlineSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.salon, style: CutlineTextStyles.subtitleBold.copyWith(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text(booking.location, style: CutlineTextStyles.subtitle),
                    const SizedBox(height: 6),
                    Text('Services: ${booking.services.join(', ')}', style: CutlineTextStyles.body),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: CutlineSpacing.md),
          Row(
            children: [
              if (showCancel)
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: CutlineColors.primary),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: onCancel,
                    child: const Text('Cancel Booking', style: TextStyle(color: CutlineColors.primary, fontWeight: FontWeight.w600)),
                  ),
                ),
              if (showCancel) const SizedBox(width: CutlineSpacing.sm),
              if (showReceipt)
                Expanded(
                  child: ElevatedButton(
                    style: CutlineButtons.primary(padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.bookingReceipt),
                    child: const Text('View Receipt', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Booking {
  final String image;
  final String salon;
  final String location;
  final List<String> services;
  final String datetime;

  const _Booking({
    required this.image,
    required this.salon,
    required this.location,
    required this.services,
    required this.datetime,
  });
}
