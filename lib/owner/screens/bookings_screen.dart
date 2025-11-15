import 'package:cutline/owner/screens/booking_detail_screen.dart';
import 'package:cutline/owner/utils/constants.dart';
import 'package:cutline/owner/widgets/booking_card.dart';
import 'package:flutter/material.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Bookings'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Upcoming'),
              Tab(text: 'Completed'),
              Tab(text: 'Cancelled'),
            ],
          ),
        ),
        body: TabBarView(
          children: OwnerBookingStatus.values.map((status) {
            final filtered = kOwnerBookings
                .where((booking) => booking.status == status)
                .toList();
            if (filtered.isEmpty) {
              return const Center(child: Text('No bookings.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filtered.length,
              itemBuilder: (_, index) {
                final booking = filtered[index];
                return OwnerBookingCard(
                  booking: booking,
                  onTap: () => _openDetails(context, booking),
                );
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  void _openDetails(BuildContext context, OwnerBooking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookingReceiptScreen()),
    );
  }
}
