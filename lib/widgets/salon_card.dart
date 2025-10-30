import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/salon_model.dart';
import '../theme/app_colors.dart';
import '../utils/helpers.dart';

class SalonCard extends StatelessWidget {
  final SalonModel salon;
  final VoidCallback onTap;

  const SalonCard({
    super.key,
    required this.salon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Salon Image
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: salon.imageUrl != null
                    ? CachedNetworkImage(
                        imageUrl: salon.imageUrl!,
                        width: 80,
                        height: 80,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => Container(
                          width: 80,
                          height: 80,
                          color: AppColors.gray200,
                          child: const Icon(Icons.store, size: 40),
                        ),
                        errorWidget: (context, url, error) => Container(
                          width: 80,
                          height: 80,
                          color: AppColors.gray200,
                          child: const Icon(Icons.store, size: 40),
                        ),
                      )
                    : Container(
                        width: 80,
                        height: 80,
                        color: AppColors.gray200,
                        child: const Icon(Icons.store, size: 40),
                      ),
              ),
              const SizedBox(width: 16),
              
              // Salon Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      salon.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppColors.gray500,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            salon.location,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.gray600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.person,
                          size: 16,
                          color: AppColors.gray500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${salon.barbers.length} barber${salon.barbers.length != 1 ? 's' : ''}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.gray600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              
              // Arrow Icon
              const Icon(
                Icons.chevron_right,
                color: AppColors.gray400,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
