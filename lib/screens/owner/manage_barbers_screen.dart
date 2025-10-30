import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/salon_provider.dart';
import '../../widgets/barber_card.dart';
import '../../widgets/empty_state.dart';

class ManageBarbersScreen extends StatelessWidget {
  const ManageBarbersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final salonProvider = Provider.of<SalonProvider>(context);
    final salon = salonProvider.currentSalon;

    if (salon == null) {
      return const Scaffold(
        body: Center(child: Text('No salon found')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Barbers'),
      ),
      body: StreamBuilder(
        stream: salonProvider.getBarbersStream(salon.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final barbers = snapshot.data ?? [];

          if (barbers.isEmpty) {
            return EmptyState(
              icon: Icons.people_outline,
              title: 'No Barbers',
              message: 'Add your first barber to get started',
            );
          }

          return ListView.builder(
            itemCount: barbers.length,
            itemBuilder: (context, index) {
              final barber = barbers[index];
              return BarberCard(
                barber: barber,
                onTap: () {
                  // TODO: Show barber details/edit
                },
              );
            },
          );
        },
      ),
    );
  }
}
