import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/user/providers/my_booking_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MyBookingScreen extends StatelessWidget {
  const MyBookingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final user = auth.currentUser;
    final profile = auth.profile;
    final userId = user?.uid ?? '';
    final userEmail = (user?.email ?? '').trim();
    final userPhone = (profile?.phone ?? user?.phoneNumber ?? '').trim();
    return ChangeNotifierProvider(
      create: (_) => MyBookingProvider(
        userId: userId,
        userEmail: userEmail,
        userPhone: userPhone,
      )..load(),
      builder: (context, _) {
        final provider = context.watch<MyBookingProvider>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _goHome(context);
        }
      },
      child: DefaultTabController(
            length: 3,
            child: Scaffold(
              backgroundColor: CutlineColors.secondaryBackground,
              appBar: CutlineAppBar(
                title: 'Bookings',
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () => _goHome(context),
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
              body: provider.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(
                      children: [
                        _BookingList(
                          bookings: provider.upcoming,
                          emptyLabel: provider.error ?? 'No upcoming bookings.',
                          showCancel: true,
                          showReceipt: true,
                          onCancel: (context, booking) =>
                              _showCancelDialog(context, booking),
                        ),
                        _BookingList(
                          bookings: provider.completed,
                          emptyLabel:
                              provider.error ?? 'No completed bookings.',
                          showCancel: false,
                          showReceipt: true,
                        ),
                        _BookingList(
                          bookings: provider.cancelled,
                          emptyLabel:
                              provider.error ?? 'No cancelled bookings.',
                          showCancel: false,
                          showReceipt: false,
                          isCancelledList: true,
                        ),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }

  void _goHome(BuildContext context) {
    Navigator.of(context)
        .pushNamedAndRemoveUntil(AppRoutes.userHome, (route) => false);
  }

  void _showCancelDialog(BuildContext context, UserBooking booking) {
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
              context.read<MyBookingProvider>().cancelBooking(booking);
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
  final List<UserBooking> bookings;
  final String emptyLabel;
  final bool showCancel;
  final bool showReceipt;
  final bool isCancelledList;
  final void Function(BuildContext context, UserBooking booking)? onCancel;

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
            onCancel:
                showCancel ? () => onCancel?.call(context, booking) : null,
          ),
        );
      },
    );
  }
}

class _BookingCard extends StatelessWidget {
  final UserBooking booking;
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
              Text('${booking.dateLabel} • ${booking.timeLabel}',
                  style: CutlineTextStyles.subtitleBold),
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
                child: booking.coverImageUrl != null &&
                        booking.coverImageUrl!.isNotEmpty
                    ? Image.network(
                        booking.coverImageUrl!,
                        width: 70,
                        height: 70,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => _placeholder(),
                      )
                    : _placeholder(),
              ),
              const SizedBox(width: CutlineSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(booking.salonName, style: CutlineTextStyles.subtitleBold.copyWith(fontSize: 16)),
                    const SizedBox(height: 4),
                    Text('Barber: ${booking.barberName}', style: CutlineTextStyles.subtitle),
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
                    onPressed: () => Navigator.pushNamed(
                      context,
                      AppRoutes.bookingReceipt,
                      arguments: BookingReceiptArgs(
                        salonId: booking.salonId,
                        bookingId: booking.id,
                      ),
                    ),
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

Widget _placeholder() {
  return Container(
    width: 70,
    height: 70,
    decoration: BoxDecoration(
      color: Colors.grey.shade200,
      borderRadius: BorderRadius.circular(12),
    ),
    alignment: Alignment.center,
    child: const Icon(Icons.store, color: Colors.grey),
  );
}
