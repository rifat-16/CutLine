import 'package:cutline/features/user/screens/salon_details_screen.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

class FavoriteSalonScreen extends StatelessWidget {
  const FavoriteSalonScreen({super.key});

  static final List<_FavoriteSalon> _salons = [
    const _FavoriteSalon(
      name: 'Urban Cuts',
      rating: 4.6,
      reviews: 120,
      distance: '0.8 km',
      waitTime: '10 mins',
      isOpen: true,
      topServices: 'Haircut, Beard Trim, Facial',
      coverPlaceholder: 'Cover Image Area',
    ),
    const _FavoriteSalon(
      name: 'Salon Luxe',
      rating: 4.8,
      reviews: 98,
      distance: '1.2 km',
      waitTime: '15 mins',
      isOpen: false,
      topServices: 'Spa, Styling, Hair Color',
      coverPlaceholder: 'Cover Image Area',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CutlineAppBar(title: 'Favorite Salons', centerTitle: true),
      backgroundColor: CutlineColors.secondaryBackground,
      body: ListView.separated(
        padding: CutlineSpacing.section.copyWith(top: 20, bottom: 32),
        itemCount: _salons.length,
        separatorBuilder: (_, __) => const SizedBox(height: CutlineSpacing.md),
        itemBuilder: (context, index) {
          final salon = _salons[index];
          final card = _FavoriteSalonCard(
            salon: salon,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => SalonDetailsScreen(salonName: salon.name),
              ),
            ),
          );
          return CutlineAnimations.staggeredList(child: card, index: index);
        },
      ),
    );
  }
}

class _FavoriteSalonCard extends StatelessWidget {
  final _FavoriteSalon salon;
  final VoidCallback onTap;

  const _FavoriteSalonCard({required this.salon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CutlineDecorations.radius),
      child: Container(
        decoration: CutlineDecorations.card(solidColor: CutlineColors.background),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _CoverImage(placeholder: salon.coverPlaceholder, rating: salon.rating, reviews: salon.reviews, name: salon.name),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LocationRow(distance: salon.distance),
                  const SizedBox(height: 6),
                  _WaitTimeRow(waitTime: salon.waitTime, isOpen: salon.isOpen),
                  const SizedBox(height: 6),
                  Text('Top Services: ${salon.topServices}', style: CutlineTextStyles.subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverImage extends StatelessWidget {
  final String placeholder;
  final double rating;
  final int reviews;
  final String name;

  const _CoverImage({required this.placeholder, required this.rating, required this.reviews, required this.name});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          color: Colors.grey.shade300,
          child: Center(
            child: Text(placeholder, style: CutlineTextStyles.subtitle),
          ),
        ),
        Positioned(
          right: 12,
          top: 12,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(50),
            ),
            padding: const EdgeInsets.all(6),
            child: const Icon(Icons.favorite, color: Colors.white, size: 20),
          ),
        ),
        Positioned(
          left: 16,
          bottom: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: CutlineTextStyles.title.copyWith(color: Colors.white)),
              Row(
                children: [
                  const Icon(Icons.star, size: 16, color: CutlineColors.accent),
                  const SizedBox(width: 4),
                  Text('$rating ($reviews)', style: const TextStyle(color: Colors.white)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LocationRow extends StatelessWidget {
  final String distance;

  const _LocationRow({required this.distance});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.location_on, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text('Banani, Dhaka • $distance away', style: CutlineTextStyles.body),
        ),
      ],
    );
  }
}

class _WaitTimeRow extends StatelessWidget {
  final String waitTime;
  final bool isOpen;

  const _WaitTimeRow({required this.waitTime, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text('Wait time: $waitTime  •  ', style: CutlineTextStyles.body),
        Text(
          isOpen ? 'Open Now' : 'Closed',
          style: CutlineTextStyles.subtitleBold.copyWith(color: isOpen ? Colors.green : Colors.redAccent),
        ),
      ],
    );
  }
}

class _FavoriteSalon {
  final String name;
  final double rating;
  final int reviews;
  final String distance;
  final String waitTime;
  final bool isOpen;
  final String topServices;
  final String coverPlaceholder;

  const _FavoriteSalon({
    required this.name,
    required this.rating,
    required this.reviews,
    required this.distance,
    required this.waitTime,
    required this.isOpen,
    required this.topServices,
    required this.coverPlaceholder,
  });
}
