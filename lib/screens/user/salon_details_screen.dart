import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/salon_provider.dart';
import '../../routes/app_routes.dart';
import '../../widgets/barber_card.dart';
import '../../widgets/empty_state.dart';
import '../../theme/app_colors.dart';

class SalonDetailsScreen extends StatefulWidget {
  final String salonId;

  const SalonDetailsScreen(this.salonId, {super.key});

  @override
  State<SalonDetailsScreen> createState() => _SalonDetailsScreenState();
}

class _SalonDetailsScreenState extends State<SalonDetailsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<SalonProvider>(context, listen: false).loadSalon(widget.salonId);
    });
  }

  @override
  Widget build(BuildContext context) {
    final salonProvider = Provider.of<SalonProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(salonProvider.currentSalon?.name ?? 'Salon'),
      ),
      body: salonProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : salonProvider.currentSalon == null
              ? const Center(child: Text('Salon not found'))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Salon Info
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (salonProvider.currentSalon!.imageUrl != null)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.network(
                                salonProvider.currentSalon!.imageUrl!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              ),
                            )
                          else
                            Container(
                              height: 200,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.gray200,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.store, size: 80),
                            ),
                          const SizedBox(height: 16),
                          Text(
                            salonProvider.currentSalon!.location,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.gray600,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Text(
                        'Select a Barber',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),

                    // Barbers List
                    Expanded(
                      child: StreamBuilder(
                        stream: salonProvider.getBarbersStream(widget.salonId),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState ==
                              ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }

                          if (snapshot.hasError) {
                            return Center(child: Text('Error: ${snapshot.error}'));
                          }

                          final barbers = snapshot.data ?? [];

                          if (barbers.isEmpty) {
                            return EmptyState(
                              icon: Icons.face_outlined,
                              title: 'No Barbers Available',
                              message: 'Check back later',
                            );
                          }

                          return ListView.builder(
                            itemCount: barbers.length,
                            itemBuilder: (context, index) {
                              final barber = barbers[index];
                              return BarberCard(
                                barber: barber,
                                onTap: () {
                                  Navigator.of(context).pushNamed(
                                    AppRoutes.booking,
                                    arguments: {
                                      'salon': salonProvider.currentSalon,
                                      'barber': barber,
                                    },
                                  );
                                },
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
    );
  }
}
