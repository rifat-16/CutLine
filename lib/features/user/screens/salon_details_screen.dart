import 'dart:async';
import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/user/providers/salon_details_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:cutline/shared/widgets/cached_profile_image.dart';
import 'package:cutline/shared/widgets/web_safe_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Root screen wiring together all sections.
class SalonDetailsScreen extends StatelessWidget {
  final String salonId;
  final String salonName;

  const SalonDetailsScreen({
    super.key,
    required this.salonId,
    required this.salonName,
  });

  static const SizedBox _smallGap = SizedBox(height: 12);
  static const SizedBox _mediumGap = SizedBox(height: 16);

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().currentUser?.uid ?? '';
    return ChangeNotifierProvider(
      create: (_) => SalonDetailsProvider(
        salonId: salonId,
        salonName: salonName,
        userId: userId,
      )..load(),
      builder: (context, _) {
        final provider = context.watch<SalonDetailsProvider>();
        final details = provider.details;
        final title = details?.name ?? salonName;

        return Scaffold(
          backgroundColor: CutlineColors.background,
          appBar: SalonDetailsAppBar(
            titleText: title,
            isFavorite: provider.isFavorite,
            onFavoriteToggle: provider.toggleFavorite,
          ),
          body: _buildContent(context, provider, details),
          floatingActionButton: details == null
              ? null
              : BookNowFab(
                  salonId: details.id,
                  salonName: details.name,
                ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, SalonDetailsProvider provider,
      SalonDetailsData? details) {
    if (provider.isLoading && details == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.error != null && details == null) {
      return _ErrorState(
        message: provider.error!,
        onRetry: provider.load,
      );
    }

    return RefreshIndicator(
      onRefresh: provider.load,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CoverPhotoSection(coverImageUrl: details?.coverImageUrl),
            if (provider.error != null)
              Padding(
                padding: CutlineSpacing.section.copyWith(top: 8, bottom: 8),
                child: Text(provider.error!,
                    style: const TextStyle(color: Colors.red)),
              ),
            if (details != null) ...[
              SalonInfoSection(details: details),
              _smallGap,
              WorkingHoursCard(
                hours: details.workingHours,
                isOpen: details.isOpen,
              ),
              _mediumGap,
              BarberListSection(barbers: provider.barbers),
              _mediumGap,
              SalonGallerySection(
                salonName: details.name,
                photos: details.galleryPhotos,
              ),
              _mediumGap,
              ComboOfferCard(
                salonName: details.name,
                combo: details.combos.isNotEmpty ? details.combos.first : null,
              ),
              _mediumGap,
              ServicesSection(
                salonName: details.name,
                services: details.services,
                topServices: details.topServices,
              ),
              _mediumGap,
              LiveQueueSection(
                waitMinutes: details.waitMinutes,
                queue: details.queue,
                salonId: details.id,
              ),
            ] else ...[
              const SizedBox(height: 30),
            ],
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}

// App bar extracted for readability.
class SalonDetailsAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final String titleText;
  final bool isFavorite;
  final VoidCallback? onFavoriteToggle;

  const SalonDetailsAppBar({
    super.key,
    required this.titleText,
    required this.isFavorite,
    this.onFavoriteToggle,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(titleText, style: CutlineTextStyles.appBarTitle),
      backgroundColor: CutlineColors.background,
      foregroundColor: CutlineColors.primary,
      elevation: 0.5,
      actions: [
        IconButton(
          onPressed: onFavoriteToggle,
          icon: Icon(
            isFavorite ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: isFavorite ? Colors.redAccent : CutlineColors.primary,
          ),
          tooltip: 'Add to Favorites',
        ),
      ],
    );
  }
}

// Cover photo placeholder / dynamic image.
class CoverPhotoSection extends StatelessWidget {
  final String? coverImageUrl;

  const CoverPhotoSection({super.key, this.coverImageUrl});

  @override
  Widget build(BuildContext context) {
    final hasImage = coverImageUrl != null && coverImageUrl!.isNotEmpty;
    return Container(
      height: 220,
      width: double.infinity,
      color: Colors.grey[300],
      child: hasImage
          ? Stack(
              fit: StackFit.expand,
              children: [
                WebSafeImage(
                  imageUrl: coverImageUrl!,
                  fit: BoxFit.cover,
                  placeholder: Container(
                    color: Colors.grey[300],
                    child: const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                  errorWidget: const Center(
                    child: Text(
                      'Cover image will appear after the next update',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withValues(alpha: 0),
                          Colors.black.withValues(alpha: 0.08),
                          Colors.black.withValues(alpha: 0.15),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            )
          : const Center(
              child: Text(
                'Cover image will appear after the next update',
                style: TextStyle(color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ),
    );
  }
}

// Info & contact details.
class SalonInfoSection extends StatelessWidget {
  final SalonDetailsData details;

  const SalonInfoSection({super.key, required this.details});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CutlineColors.primary.withValues(alpha: 0.05),
            CutlineColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  details.name,
                  style: CutlineTextStyles.title.copyWith(
                    fontSize: 22,
                    color: CutlineColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              TextButton(
                onPressed: () {
                  final point = details.location;
                  if (point == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Location is not available for this salon.'),
                      ),
                    );
                    return;
                  }
                  Navigator.pushNamed(
                    context,
                    AppRoutes.salonMap,
                    arguments: SalonMapArgs(
                      salonName: details.name,
                      address: details.address,
                      lat: point.latitude,
                      lng: point.longitude,
                    ),
                  );
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('See Map', style: CutlineTextStyles.link),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on,
                  size: 18, color: CutlineColors.primary),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  details.locationLabel,
                  style: CutlineTextStyles.body,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _IconTextRow(
            icon: Icons.phone,
            labelWidget: GestureDetector(
              onTap: () {
                // TODO: Implement phone call.
              },
              child: Text(
                details.contact.isNotEmpty
                    ? details.contact
                    : 'Contact unavailable',
                style: const TextStyle(
                  color: CutlineColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _IconTextRow(
            icon: Icons.email_outlined,
            label:
                details.email.isNotEmpty ? details.email : 'Email unavailable',
          ),
          const SizedBox(height: 6),
          _IconTextRow(
            icon: Icons.star_outline,
            label: details.topServices.isNotEmpty
                ? 'Top Services: ${details.topServices.join(' • ')}'
                : 'Top services will appear here',
            wrap: true,
          ),
        ],
      ),
    );
  }
}

// Working hours detail card.
class WorkingHoursCard extends StatelessWidget {
  final List<SalonWorkingHour> hours;
  final bool isOpen;

  const WorkingHoursCard({
    super.key,
    required this.hours,
    required this.isOpen,
  });

  @override
  Widget build(BuildContext context) {
    final displayHours = hours.isNotEmpty ? hours : <SalonWorkingHour>[];
    final closingLabel = _closingLabel(displayHours);
    final statusText = isOpen ? closingLabel : 'Closed now';
    return Padding(
      padding: CutlineSpacing.section,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: CutlineDecorations.card(
          colors: [
            CutlineColors.background,
            CutlineColors.primary.withValues(alpha: 0.06)
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.schedule_rounded,
                    color: CutlineColors.primary, size: 22),
                SizedBox(width: 8),
                Text('Working Hours', style: CutlineTextStyles.title),
              ],
            ),
            const Divider(height: 18, thickness: 0.6),
            ...displayHours.map(
              (hour) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(hour.day,
                        style: CutlineTextStyles.body.copyWith(fontSize: 15)),
                    Text(hour.timeRangeLabel,
                        style:
                            CutlineTextStyles.caption.copyWith(fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isOpen
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(isOpen ? Icons.check_circle : Icons.schedule,
                      color: isOpen ? Colors.green : Colors.red, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    statusText,
                    style: TextStyle(
                      color: isOpen ? Colors.green : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _closingLabel(List<SalonWorkingHour> hours) {
    final todayName = _today();
    final today = hours.firstWhere(
      (h) => h.day == todayName,
      orElse: () => hours.isNotEmpty
          ? hours.first
          : const SalonWorkingHour(
              day: 'Today', isOpen: false, openTime: null, closeTime: null),
    );
    if (!today.isOpen) return 'Closed now';
    final label = today.closeTime != null ? today.timeRangeLabel : null;
    return label != null
        ? 'Open Now • Closes at ${_formatClose(today.closeTime!)}'
        : 'Open Now';
  }

  String _today() => [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday'
      ][DateTime.now().weekday - 1];

  String _formatClose(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $suffix';
  }
}

// Horizontal barber list.
class BarberListSection extends StatelessWidget {
  final List<SalonBarber> barbers;

  const BarberListSection({super.key, required this.barbers});

  @override
  Widget build(BuildContext context) {
    final hasBarbers = barbers.isNotEmpty;
    return Padding(
      padding: CutlineSpacing.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Our Barbers', style: CutlineTextStyles.title),
          const SizedBox(height: 12),
          if (!hasBarbers)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: CutlineDecorations.card(
                solidColor: CutlineColors.background,
              ),
              child: const Text(
                'Barbers will appear here once added.',
                style: CutlineTextStyles.subtitle,
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: barbers
                    .map(
                      (barber) => _BarberCard(barber: barber),
                    )
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}

class _BarberCard extends StatelessWidget {
  final SalonBarber barber;

  const _BarberCard({required this.barber});

  void _showBarberProfile(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _BarberProfileSheet(barber: barber),
    );
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => _showBarberProfile(context),
      borderRadius: BorderRadius.circular(CutlineDecorations.radius),
      child: Container(
        width: 170,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        decoration: CutlineDecorations.card(
          colors: [
            CutlineColors.background,
            CutlineColors.primary.withValues(alpha: 0.04)
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ClipOval(
              child: Container(
                width: 64,
                height: 64,
                color: Colors.grey.shade200,
                child: barber.avatarUrl != null && barber.avatarUrl!.isNotEmpty
                    ? Image.network(
                        barber.avatarUrl!,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                              strokeWidth: 2,
                            ),
                          );
                        },
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person,
                          color: Colors.grey,
                          size: 40,
                        ),
                      )
                    : const Icon(Icons.person, color: Colors.grey, size: 40),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              barber.name,
              style: CutlineTextStyles.subtitleBold.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 4),
            Text(barber.skills, style: CutlineTextStyles.caption),
            const SizedBox(height: 10),
            Text(
              barber.isAvailable ? 'Available' : 'Unavailable',
              style: TextStyle(
                color: barber.isAvailable ? Colors.green : Colors.redAccent,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_alt_rounded,
                    color: CutlineColors.primary, size: 14),
                const SizedBox(width: 4),
                Text('${barber.waitingClients} waiting',
                    style: CutlineTextStyles.caption),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Barber Profile Bottom Sheet
class _BarberProfileSheet extends StatelessWidget {
  final SalonBarber barber;

  const _BarberProfileSheet({required this.barber});

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle bar
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      // Profile Picture
                      ClipOval(
                        child: Container(
                          width: 100,
                          height: 100,
                          color: Colors.grey.shade200,
                          child: barber.avatarUrl != null &&
                                  barber.avatarUrl!.isNotEmpty
                              ? Image.network(
                                  barber.avatarUrl!,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return Center(
                                      child: CircularProgressIndicator(
                                        value: loadingProgress
                                                    .expectedTotalBytes !=
                                                null
                                            ? loadingProgress
                                                    .cumulativeBytesLoaded /
                                                loadingProgress
                                                    .expectedTotalBytes!
                                            : null,
                                        strokeWidth: 2,
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => const Icon(
                                    Icons.person,
                                    color: Colors.grey,
                                    size: 60,
                                  ),
                                )
                              : const Icon(Icons.person,
                                  color: Colors.grey, size: 60),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Name
                      Text(
                        barber.name,
                        style: CutlineTextStyles.title.copyWith(fontSize: 24),
                      ),
                      const SizedBox(height: 8),
                      // Skills
                      Text(
                        barber.skills,
                        style: CutlineTextStyles.subtitle,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      // Availability Status
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: CutlineDecorations.card(
                          solidColor: Colors.white,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Status',
                                  style: CutlineTextStyles.caption,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  barber.isAvailable
                                      ? 'Available'
                                      : 'Unavailable',
                                  style: TextStyle(
                                    color: barber.isAvailable
                                        ? Colors.green
                                        : Colors.redAccent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'Waiting',
                                  style: CutlineTextStyles.caption,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(Icons.people_alt_rounded,
                                        color: CutlineColors.primary, size: 18),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${barber.waitingClients}',
                                      style: CutlineTextStyles.subtitleBold,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// Gallery preview grid.
class SalonGallerySection extends StatelessWidget {
  final String salonName;
  final List<String> photos;

  const SalonGallerySection({
    super.key,
    required this.salonName,
    required this.photos,
  });

  @override
  Widget build(BuildContext context) {
    final display = photos.take(6).toList();
    return Padding(
      padding: CutlineSpacing.section.copyWith(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Salon Gallery', style: CutlineTextStyles.title),
              if (photos.isNotEmpty)
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.salonGallery,
                      arguments: SalonGalleryArgs(
                        salonName: salonName,
                        photos: photos,
                        uploadedCount: photos.length,
                        totalLimit: 10,
                      ),
                    );
                  },
                  child: const Text('See all', style: CutlineTextStyles.link),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (display.isEmpty)
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: const Text(
                'No gallery photos yet.',
                style: CutlineTextStyles.subtitle,
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: display.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemBuilder: (context, index) {
                final url = display[index];
                return ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return Container(
                        color: Colors.grey.shade200,
                        child: Center(
                          child: CircularProgressIndicator(
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                            strokeWidth: 2,
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => Container(
                      color: Colors.grey.shade300,
                      child: const Icon(Icons.broken_image, color: Colors.grey),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

// Combo offer highlight.
class ComboOfferCard extends StatelessWidget {
  final String salonName;
  final SalonCombo? combo;

  const ComboOfferCard({
    super.key,
    required this.salonName,
    this.combo,
  });

  @override
  Widget build(BuildContext context) {
    if (combo == null) {
      return Padding(
        padding: CutlineSpacing.section,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('Combo Offers', style: CutlineTextStyles.title),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              height: 120,
              decoration:
                  CutlineDecorations.card(solidColor: Colors.grey.shade200),
              child: const Center(
                child: Text(
                  'Combo offers coming soon',
                  style: CutlineTextStyles.subtitleBold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    final displayCombo = combo!;
    return Padding(
      padding: CutlineSpacing.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Combo Offers', style: CutlineTextStyles.title),
              TextButton(
                onPressed: () {
                  Navigator.pushNamed(
                    context,
                    AppRoutes.viewAllServices,
                    arguments: ViewAllServicesArgs(salonName: salonName),
                  );
                },
                child: const Text('See all', style: CutlineTextStyles.link),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.orangeAccent, Colors.deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(CutlineDecorations.radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.orangeAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayCombo.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      displayCombo.services,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '৳${displayCombo.price}',
                        style: const TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Add booking functionality.
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.deepOrange,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                      ),
                      child: const Text('Book Now',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Services quick entry point.
class ServicesSection extends StatelessWidget {
  final String salonName;
  final List<SalonService> services;
  final List<String> topServices;

  const ServicesSection({
    super.key,
    required this.salonName,
    required this.services,
    required this.topServices,
  });

  @override
  Widget build(BuildContext context) {
    final preview = _previewLabel();
    return Padding(
      padding: CutlineSpacing.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Services', style: CutlineTextStyles.title),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              Navigator.pushNamed(
                context,
                AppRoutes.viewAllServices,
                arguments: ViewAllServicesArgs(salonName: salonName),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
              decoration: CutlineDecorations.card(
                colors: [
                  CutlineColors.background,
                  CutlineColors.primary.withValues(alpha: 0.04)
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.cut,
                            color: CutlineColors.primary, size: 26),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'View All Salon Services',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                preview,
                                style: CutlineTextStyles.caption,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: CutlineColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.arrow_forward_ios,
                        size: 16, color: CutlineColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _previewLabel() {
    final source = topServices.isNotEmpty
        ? topServices
        : services.map((s) => s.name).toList();
    if (source.isEmpty) return 'Popular services will appear here';
    return source.take(3).join(' • ');
  }
}

// Live queue + animated cards.
class LiveQueueSection extends StatefulWidget {
  final int waitMinutes;
  final List<SalonQueueEntry> queue;
  final String? salonId;

  const LiveQueueSection({
    super.key,
    this.waitMinutes = 0,
    this.queue = const [],
    this.salonId,
  });

  @override
  State<LiveQueueSection> createState() => _LiveQueueSectionState();
}

class _LiveQueueSectionState extends State<LiveQueueSection> {
  @override
  Widget build(BuildContext context) {
    return _LiveQueueContent(
      waitMinutes: widget.waitMinutes,
      queue: widget.queue,
      salonId: widget.salonId,
    );
  }
}

class _LiveQueueContent extends StatefulWidget {
  final int waitMinutes;
  final List<SalonQueueEntry> queue;
  final String? salonId;

  const _LiveQueueContent({
    required this.waitMinutes,
    required this.queue,
    this.salonId,
  });

  @override
  State<_LiveQueueContent> createState() => _LiveQueueContentState();
}

class _LiveQueueContentState extends State<_LiveQueueContent> {
  Timer? _progressTimer;
  double _progress = 0.0;

  @override
  void initState() {
    super.initState();
    _startProgressTimer();
  }

  @override
  void didUpdateWidget(_LiveQueueContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.queue != widget.queue) {
      _updateProgress();
    }
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    super.dispose();
  }

  void _startProgressTimer() {
    _progressTimer?.cancel();
    _updateProgress();
    _progressTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        _updateProgress();
      }
    });
  }

  void _updateProgress() {
    final nowServing = widget.queue.firstWhere(
      (e) => e.isServing,
      orElse: () => const SalonQueueEntry(
        id: '',
        customerName: '',
        barberName: '',
        service: '',
        status: '',
        waitMinutes: 0,
      ),
    );

    if (!nowServing.isServing || nowServing.customerName.isEmpty) {
      if (_progress != 0.0) {
        setState(() => _progress = 0.0);
      }
      return;
    }

    // Calculate progress based on service duration and elapsed time
    final serviceDuration = nowServing.waitMinutes > 0
        ? nowServing.waitMinutes
        : 30; // Default 30 minutes if duration not available

    double newProgress = 0.0;

    if (nowServing.dateTime != null) {
      final startTime = nowServing.dateTime!;
      final now = DateTime.now();
      final elapsed = now.difference(startTime).inMinutes;
      newProgress = (elapsed / serviceDuration).clamp(0.0, 1.0);
    } else {
      // If no start time, use a default progress based on waitMinutes
      // Assume service started recently and show minimal progress
      newProgress = 0.1;
    }

    if ((newProgress - _progress).abs() > 0.01) {
      setState(() => _progress = newProgress);
    }
  }

  @override
  Widget build(BuildContext context) {
    final waitLabel =
        widget.waitMinutes <= 0 ? 'No wait' : '≈ ${widget.waitMinutes} mins';
    final nowServing = widget.queue.firstWhere(
      (e) => e.isServing,
      orElse: () => const SalonQueueEntry(
        id: '',
        customerName: 'No one is being served',
        barberName: '',
        service: '',
        status: '',
        waitMinutes: 0,
      ),
    );
    final waiting = widget.queue.where((e) => e.isWaiting).toList()
      ..sort(_compareQueueEntries);
    return Padding(
      padding: CutlineSpacing.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Queue', style: CutlineTextStyles.title),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.refresh,
                          size: 16, color: CutlineColors.primary),
                      SizedBox(width: 4),
                      Text('Updating live...',
                          style: CutlineTextStyles.caption),
                    ],
                  ),
                  Text('Estimated wait: $waitLabel',
                      style: CutlineTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CutlineColors.primary.withValues(alpha: 0.7),
                  CutlineColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(CutlineDecorations.radius),
              boxShadow: [
                BoxShadow(
                  color: CutlineColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Now Serving',
                    style: TextStyle(color: Colors.white70, fontSize: 14)),
                const SizedBox(height: 4),
                Text(
                  nowServing.customerName,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Text(
                  nowServing.barberName.isNotEmpty ||
                          nowServing.service.isNotEmpty
                      ? 'Barber: ${nowServing.barberName.isNotEmpty ? nowServing.barberName : 'Not assigned'} • ${nowServing.service}'
                      : 'No assignment',
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value:
                      nowServing.isServing && nowServing.customerName.isNotEmpty
                          ? _progress
                          : 0.0,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  minHeight: 6,
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text(waitLabel,
                      style:
                          const TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
          )
              .animate()
              .slideY(begin: 0.3, end: 0, duration: 600.ms)
              .fadeIn(duration: 700.ms),
          const SizedBox(height: 16),
          if (waiting.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Waiting for Service',
                    style: CutlineTextStyles.subtitleBold),
                TextButton(
                  onPressed: () {
                    Navigator.pushNamed(
                      context,
                      AppRoutes.waitingCustomers,
                      arguments: widget.salonId,
                    );
                  },
                  child: const Text('See all', style: CutlineTextStyles.link),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: List.generate(waiting.length, (index) {
                  final entry = waiting[index];
                  return _QueueCard(entry: entry)
                      .animate()
                      .fadeIn(duration: 400.ms, delay: (index * 100).ms)
                      .slideX(begin: 0.3, end: 0);
                }),
              ),
            ),
          ] else
            Container(
              margin: const EdgeInsets.only(top: 12),
              padding: const EdgeInsets.all(16),
              decoration: CutlineDecorations.card(solidColor: Colors.white),
              child: Row(
                children: const [
                  Icon(Icons.inbox_outlined, color: Colors.grey),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'No customers waiting right now.',
                      style: CutlineTextStyles.caption,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

int _compareQueueEntries(SalonQueueEntry a, SalonQueueEntry b) {
  final aKey = _scheduleKey(a);
  final bKey = _scheduleKey(b);
  if (aKey != null && bKey != null) return aKey.compareTo(bKey);
  if (aKey != null) return -1;
  if (bKey != null) return 1;
  return a.waitMinutes.compareTo(b.waitMinutes);
}

DateTime? _scheduleKey(SalonQueueEntry entry) {
  if (entry.dateTime != null) return entry.dateTime;
  if (entry.date != null &&
      entry.date!.isNotEmpty &&
      entry.time != null &&
      entry.time!.isNotEmpty) {
    try {
      final parsedDate = DateTime.parse(entry.date!);
      final normalizedTime = entry.time!
          .replaceAll('\u00A0', ' ')
          .replaceAll('\u202F', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      final parsedTime = DateFormat('h:mm a', 'en_US').parse(normalizedTime);
      return DateTime(parsedDate.year, parsedDate.month, parsedDate.day,
          parsedTime.hour, parsedTime.minute);
    } catch (_) {
      return null;
    }
  }
  return null;
}

class _QueueCard extends StatelessWidget {
  final SalonQueueEntry entry;

  const _QueueCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: CutlineDecorations.card(solidColor: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CachedProfileImage(
                imageUrl: entry.avatarUrl,
                radius: 18,
                backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                errorWidget: const Icon(Icons.person,
                    color: Colors.blueAccent, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.customerName,
                  style: CutlineTextStyles.subtitleBold.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Barber: ${entry.barberName}', style: CutlineTextStyles.caption),
          const SizedBox(height: 4),
          Text('Service: ${entry.service}', style: CutlineTextStyles.caption),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orangeAccent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'Waiting',
              style: TextStyle(
                color: Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.calendar_today_outlined,
                  size: 14, color: Colors.blueAccent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entry.dateLabel,
                  style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.access_time, size: 14, color: Colors.blueAccent),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  entry.timeLabel,
                  style: const TextStyle(
                      color: Colors.blueAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w600),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Booking floating action button.
class BookNowFab extends StatelessWidget {
  final String salonId;
  final String salonName;

  const BookNowFab({super.key, required this.salonId, required this.salonName});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.pushNamed(
          context,
          AppRoutes.booking,
          arguments: BookingArgs(salonId: salonId, salonName: salonName),
        );
      },
      label: const Text(
        'Book Now',
        style: TextStyle(
            fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
      ),
      icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
      backgroundColor: CutlineColors.primary,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper widgets & models ----------------------------------------------------
class _IconTextRow extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Widget? labelWidget;
  final bool wrap;

  const _IconTextRow({
    required this.icon,
    this.label,
    this.labelWidget,
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget =
        labelWidget ?? Text(label ?? '', style: CutlineTextStyles.body);

    return Row(
      crossAxisAlignment:
          wrap ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: CutlineColors.primary),
        const SizedBox(width: 6),
        wrap ? Expanded(child: textWidget) : textWidget,
      ],
    );
  }
}
