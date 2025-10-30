import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/salon_provider.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/salon_card.dart';
import '../../widgets/empty_state.dart';
import '../../theme/app_colors.dart';

class UserHomeScreen extends StatelessWidget {
  const UserHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cutline'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person),
            onPressed: () {
              // TODO: Navigate to profile
            },
          ),
        ],
      ),
      body: StreamBuilder(
        stream: Provider.of<SalonProvider>(context, listen: false).salonsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          final salons = snapshot.data ?? [];

          if (salons.isEmpty) {
            return EmptyState(
              icon: Icons.store_outlined,
              title: 'No Salons Available',
              message: 'Check back later for new salons',
            );
          }

          return ListView.builder(
            itemCount: salons.length,
            itemBuilder: (context, index) {
              final salon = salons[index];
              return SalonCard(
                salon: salon,
                onTap: () {
                  Navigator.of(context).pushNamed(
                    AppRoutes.salonDetails,
                    arguments: salon.id,
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // TODO: Implement search
        },
        icon: const Icon(Icons.search),
        label: const Text('Search'),
      ),
    );
  }
}
