import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/barber_model.dart';
import '../theme/app_colors.dart';

class BarberCard extends StatelessWidget {
  final BarberModel barber;
  final VoidCallback? onTap;

  const BarberCard({
    super.key,
    required this.barber,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final queueCount = barber.currentQueue
        .where((b) => b.status.toString() == 'waiting')
        .length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Barber Image
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: barber.imageUrl != null
                        ? CachedNetworkImage(
                            imageUrl: barber.imageUrl!,
                            width: 70,
                            height: 70,
                            fit: BoxFit.cover,
                            placeholder: (context, url) => Container(
                              width: 70,
                              height: 70,
                              color: AppColors.gray200,
                              child: const Icon(Icons.face, size: 35),
                            ),
                            errorWidget: (context, url, error) => Container(
                              width: 70,
                              height: 70,
                              color: AppColors.gray200,
                              child: const Icon(Icons.face, size: 35),
                            ),
                          )
                        : Container(
                            width: 70,
                            height: 70,
                            color: AppColors.gray200,
                            child: const Icon(Icons.face, size: 35),
                          ),
                  ),
                  // Availability indicator
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: barber.available
                            ? AppColors.successGreen
                            : AppColors.gray400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              
              // Barber Info
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
                    Row(
                      children: [
                        Icon(
                          Icons.queue,
                          size: 16,
                          color: queueCount > 0
                              ? AppColors.primaryOrange
                              : AppColors.gray400,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          queueCount > 0
                              ? '$queueCount in queue'
                              : 'No queue',
                          style: TextStyle(
                            fontSize: 14,
                            color: queueCount > 0
                                ? AppColors.primaryOrange
                                : AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Arrow or Status
              if (onTap != null)
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.gray400,
                )
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: barber.available
                        ? AppColors.successGreen.withOpacity(0.1)
                        : AppColors.gray200,
                    borderRadius: BorderRadius.circular(20),
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
      ),
    );
  }
}
