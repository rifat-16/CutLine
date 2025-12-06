import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/bookings_provider.dart';
import 'package:cutline/features/owner/screens/booking_detail_screen.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/booking_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final auth = context.read<AuthProvider>();
        final provider = BookingsProvider(authProvider: auth);
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<BookingsProvider>();
        final grouped = provider.grouped();
        return DefaultTabController(
          length: OwnerBookingStatus.values.length,
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F6FB),
            appBar: AppBar(
              title: const Text('Bookings'),
              backgroundColor: Colors.white,
              elevation: 0,
              scrolledUnderElevation: 0,
              bottom: TabBar(
                labelColor: const Color(0xFF5B21B6),
                unselectedLabelColor: Colors.grey.shade700,
                indicatorColor: const Color(0xFF5B21B6),
                tabs: OwnerBookingStatus.values
                    .map((status) => Tab(text: _label(status)))
                    .toList(),
              ),
            ),
            body: provider.isLoading
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    children: OwnerBookingStatus.values.map((status) {
                      final filtered = grouped[status] ?? [];
                      if (filtered.isEmpty) {
                        return const Center(
                          child: Text(
                            'No bookings.',
                            style: TextStyle(color: Colors.black54),
                          ),
                        );
                      }
                      return RefreshIndicator(
                        onRefresh: () => provider.load(),
                        child: ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (_, index) {
                            final booking = filtered[index];
                            return OwnerBookingCard(
                              booking: booking,
                              onTap: () => _openDetails(context, booking),
                            );
                          },
                        ),
                      );
                    }).toList(),
                  ),
          ),
        );
      },
    );
  }

  String _label(OwnerBookingStatus status) {
    switch (status) {
      case OwnerBookingStatus.upcoming:
        return 'Upcoming';
      case OwnerBookingStatus.completed:
        return 'Completed';
      case OwnerBookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  void _openDetails(BuildContext context, OwnerBooking booking) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BookingReceiptScreen(
          booking: booking,
          bookingId: booking.id,
        ),
      ),
    );
  }
}
