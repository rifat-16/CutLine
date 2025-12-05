import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/user/providers/favorite_salon_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class FavoriteSalonScreen extends StatelessWidget {
  const FavoriteSalonScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().currentUser?.uid ?? '';
    return ChangeNotifierProvider(
      create: (_) => FavoriteSalonProvider(userId: userId)..load(),
      builder: (context, _) {
        final provider = context.watch<FavoriteSalonProvider>();
        final salons = provider.salons;
        return Scaffold(
          appBar:
              const CutlineAppBar(title: 'Favorite Salons', centerTitle: true),
          backgroundColor: CutlineColors.secondaryBackground,
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : salons.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          provider.error ??
                              'No favorite salons yet.\nTap the heart on a salon to add it here.',
                          textAlign: TextAlign.center,
                          style: CutlineTextStyles.subtitle,
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding:
                          CutlineSpacing.section.copyWith(top: 20, bottom: 32),
                      itemCount: salons.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(height: CutlineSpacing.md),
                      itemBuilder: (context, index) {
                        final salon = salons[index];
                        final card = _FavoriteSalonCard(
                          salon: salon,
                          onTap: () => Navigator.pushNamed(
                            context,
                            AppRoutes.salonDetails,
                            arguments: SalonDetailsArgs(
                                salonId: salon.id, salonName: salon.name),
                          ),
                        );
                        return CutlineAnimations.staggeredList(
                            child: card, index: index);
                      },
                    ),
        );
      },
    );
  }
}

class _FavoriteSalonCard extends StatelessWidget {
  final FavoriteSalon salon;
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
            _CoverImage(
                coverImageUrl: salon.coverImageUrl,
                rating: salon.rating,
                reviews: salon.reviews,
                name: salon.name),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _LocationRow(address: salon.address),
                  const SizedBox(height: 6),
                  _WaitTimeRow(waitLabel: salon.waitLabel, isOpen: salon.isOpen),
                  const SizedBox(height: 6),
                  Text('Top Services: ${salon.servicesLabel}',
                      style: CutlineTextStyles.subtitle),
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
  final String? coverImageUrl;
  final double rating;
  final int reviews;
  final String name;

  const _CoverImage(
      {required this.coverImageUrl,
      required this.rating,
      required this.reviews,
      required this.name});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          color: Colors.grey.shade200,
          child: coverImageUrl == null
              ? Center(
                  child: Text('Cover image', style: CutlineTextStyles.subtitle))
              : Image.network(
                  coverImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Center(
                    child: Text('Cover image', style: CutlineTextStyles.subtitle),
                  ),
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
  final String address;

  const _LocationRow({required this.address});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.location_on, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Expanded(
          child: Text(address, style: CutlineTextStyles.body),
        ),
      ],
    );
  }
}

class _WaitTimeRow extends StatelessWidget {
  final String waitLabel;
  final bool isOpen;

  const _WaitTimeRow({required this.waitLabel, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.access_time, size: 16, color: Colors.grey),
        const SizedBox(width: 4),
        Text('Wait time: $waitLabel  •  ', style: CutlineTextStyles.body),
        Text(
          isOpen ? 'Open Now' : 'Closed',
          style: CutlineTextStyles.subtitleBold.copyWith(color: isOpen ? Colors.green : Colors.redAccent),
        ),
      ],
    );
  }
}
