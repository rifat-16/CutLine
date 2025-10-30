import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/queue_provider.dart';
import '../../providers/auth_provider.dart';
import '../../routes/app_routes.dart';
import '../../models/salon_model.dart';
import '../../models/barber_model.dart';
import '../../widgets/custom_button.dart';
import '../../theme/app_colors.dart';
import '../../utils/helpers.dart';

class BookingScreen extends StatefulWidget {
  final Map<String, dynamic> arguments;

  const BookingScreen({required this.arguments, super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  String? _selectedServiceId;

  @override
  Widget build(BuildContext context) {
    final salon = widget.arguments['salon'] as SalonModel;
    final barber = widget.arguments['barber'] as BarberModel;
    final services = barber.services.isEmpty ? salon.services : barber.services;
    
    final authProvider = Provider.of<AuthProvider>(context);
    final queueProvider = Provider.of<QueueProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book a Slot'),
      ),
      body: Column(
        children: [
          // Barber Info Card
          Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: barber.imageUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(barber.imageUrl!, fit: BoxFit.cover),
                          )
                        : const Icon(Icons.face, size: 30),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          barber.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: barber.available
                                ? AppColors.successGreen.withOpacity(0.1)
                                : AppColors.gray200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            barber.available ? 'Available' : 'Busy',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: barber.available
                                  ? AppColors.successGreen
                                  : AppColors.gray600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Select Service',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Services List
          Expanded(
            child: services.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.content_cut, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        const Text('No services available'),
                        const SizedBox(height: 24),
                        CustomButton(
                          text: 'Go Back',
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      final service = services[index];
                      final isSelected = _selectedServiceId == service.id;
                      
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        elevation: isSelected ? 4 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isSelected ? AppColors.primaryBlue : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() => _selectedServiceId = service.id);
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: AppColors.primaryOrange.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.content_cut,
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        service.name,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${service.duration} min',
                                        style: const TextStyle(
                                          fontSize: 14,
                                          color: AppColors.gray600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  AppHelpers.formatCurrency(service.price),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Icon(
                                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                                  color: isSelected ? AppColors.primaryBlue : AppColors.gray300,
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),

          // Book Button
          if (services.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: CustomButton(
                text: 'Book Now',
                onPressed: _selectedServiceId == null
                    ? null
                    : () async {
                        final service = services.firstWhere((s) => s.id == _selectedServiceId);
                        
                        if (!barber.available) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Barber is currently busy'),
                              backgroundColor: Colors.orange,
                            ),
                          );
                          return;
                        }

                        final success = await queueProvider.bookSlot(
                          user: authProvider.currentUser!,
                          salonId: salon.id,
                          salonName: salon.name,
                          barberId: barber.id,
                          barberName: barber.name,
                          serviceId: service.id,
                          serviceName: service.name,
                          servicePrice: service.price,
                        );

                        if (!mounted) return;

                        if (success) {
                          Navigator.of(context).pushReplacementNamed(AppRoutes.queueStatus);
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(queueProvider.error ?? 'Booking failed'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }
                      },
                isLoading: queueProvider.isLoading,
              ),
            ),
        ],
      ),
    );
  }
}
