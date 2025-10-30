import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/barber_provider.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/queue_tile.dart';
import '../../widgets/empty_state.dart';
import '../../theme/app_colors.dart';
import '../../widgets/custom_button.dart';

class BarberQueueScreen extends StatefulWidget {
  const BarberQueueScreen({super.key});

  @override
  State<BarberQueueScreen> createState() => _BarberQueueScreenState();
}

class _BarberQueueScreenState extends State<BarberQueueScreen> {
  bool _isAvailable = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      // TODO: Load barber data and queue
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // TODO: Get barber's salonId from user model or context
    const salonId = 'temp_salon_id';
    final barberId = authProvider.currentUser?.id ?? '';

    if (barberId.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Barber ID not found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Queue'),
        actions: [
          // Toggle Availability
          Switch(
            value: _isAvailable,
            onChanged: (value) async {
              setState(() => _isAvailable = value);
              final barberProvider = Provider.of<BarberProvider>(context, listen: false);
              await barberProvider.toggleAvailability(salonId, barberId);
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: Provider.of<BarberProvider>(context, listen: false)
            .getQueueStream(salonId, barberId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final queue = snapshot.data ?? [];
          final activeQueue = queue.where((b) =>
            b.status.toString() == 'waiting' ||
            b.status.toString() == 'inProgress',
          ).toList();

          if (activeQueue.isEmpty) {
            return EmptyState(
              icon: Icons.queue_outlined,
              title: 'No Active Queue',
              message: 'Waiting for customers to book...',
            );
          }

          return ListView.builder(
            itemCount: queue.length,
            itemBuilder: (context, index) {
              final booking = queue[index];
              return QueueTile(
                booking: booking,
                showActions: booking.status.toString() == 'waiting' ||
                    booking.status.toString() == 'inProgress',
                onServe: () async {
                  final barberProvider = Provider.of<BarberProvider>(context, listen: false);
                  await barberProvider.markAsServed(salonId, barberId, booking.id);
                },
                onSkip: () async {
                  final barberProvider = Provider.of<BarberProvider>(context, listen: false);
                  await barberProvider.skipCustomer(salonId, barberId, booking.id);
                },
              );
            },
          );
        },
      ),
    );
  }
}
