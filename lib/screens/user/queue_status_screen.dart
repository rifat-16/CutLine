import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/queue_provider.dart';
import '../../widgets/queue_tile.dart';
import '../../widgets/empty_state.dart';
import '../../theme/app_colors.dart';
import '../../utils/helpers.dart';

class QueueStatusScreen extends StatefulWidget {
  const QueueStatusScreen({super.key});

  @override
  State<QueueStatusScreen> createState() => _QueueStatusScreenState();
}

class _QueueStatusScreenState extends State<QueueStatusScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final queueProvider = Provider.of<QueueProvider>(context, listen: false);
      if (queueProvider.currentBooking != null) {
        queueProvider.loadUserBookings(queueProvider.currentBooking!.userId);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final queueProvider = Provider.of<QueueProvider>(context);
    final currentBooking = queueProvider.currentBooking;

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Queue'),
      ),
      body: currentBooking == null
          ? EmptyState(
              icon: Icons.queue_outlined,
              title: 'No Active Bookings',
              message: 'Book a slot to see your queue status',
            )
          : StreamBuilder(
              stream: queueProvider.getUserBookingsStream(currentBooking.userId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }

                final bookings = snapshot.data ?? [];
                final activeBookings = bookings.where((b) =>
                  b.status.toString() == 'waiting' ||
                  b.status.toString() == 'inProgress',
                ).toList();

                if (activeBookings.isEmpty) {
                  return EmptyState(
                    icon: Icons.check_circle_outline,
                    title: 'No Active Bookings',
                    message: 'All your bookings have been completed',
                  );
                }

                return Column(
                  children: [
                    // Status Card
                    Container(
                      margin: const EdgeInsets.all(16),
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primaryBlue,
                            AppColors.primaryBlue.withOpacity(0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 48,
                            color: Colors.white,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Queue Position',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '#${activeBookings.first.queuePosition}',
                            style: const TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${activeBookings.length} active booking${activeBookings.length > 1 ? "s" : ""}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Text(
                        'Your Bookings',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Bookings List
                    Expanded(
                      child: ListView.builder(
                        itemCount: bookings.length,
                        itemBuilder: (context, index) {
                          final booking = bookings[index];
                          return QueueTile(booking: booking);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}
