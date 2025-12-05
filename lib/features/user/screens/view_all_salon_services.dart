import 'package:cutline/features/user/providers/salon_services_provider.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ViewAllSalonServices extends StatefulWidget {
  final String salonName;

  const ViewAllSalonServices({super.key, required this.salonName});

  @override
  State<ViewAllSalonServices> createState() => _ViewAllSalonServicesState();
}

class _ViewAllSalonServicesState extends State<ViewAllSalonServices> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          SalonServicesProvider(salonName: widget.salonName)..load(),
      builder: (context, _) {
        final provider = context.watch<SalonServicesProvider>();
        return Scaffold(
          appBar: CutlineAppBar(
            title: '${widget.salonName} Services',
            centerTitle: true,
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: CutlineColors.primary,
              labelColor: CutlineColors.primary,
              unselectedLabelColor: Colors.black54,
              tabs: const [
                Tab(text: 'All Services'),
                Tab(text: 'Combo Offers'),
              ],
            ),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : provider.error != null
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          provider.error!,
                          style: CutlineTextStyles.subtitle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _ServiceList(services: provider.services),
                        _ComboOfferList(combos: provider.combos),
                      ],
                    ),
        );
      },
    );
  }
}

class _ServiceList extends StatelessWidget {
  final List<SalonService> services;

  const _ServiceList({required this.services});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const _EmptyState(message: 'Services will appear here soon.');
    }
    return ListView.builder(
      padding: CutlineSpacing.section.copyWith(top: 16, bottom: 16),
      itemCount: services.length,
      itemBuilder: (context, index) {
        final svc = services[index];
        return CutlineAnimations.staggeredList(
          index: index,
          child: _ServiceTile(
            title: svc.name,
            duration: 'Duration: ${svc.durationMinutes} min',
            price: '৳${svc.price}',
          ),
        );
      },
    );
  }
}

class _ServiceTile extends StatelessWidget {
  final String title;
  final String duration;
  final String price;

  const _ServiceTile({required this.title, required this.duration, required this.price});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CutlineSpacing.sm),
      padding: CutlineSpacing.card,
      decoration: CutlineDecorations.card(solidColor: CutlineColors.background),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: CutlineColors.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.content_cut_rounded, color: CutlineColors.primary),
          ),
          const SizedBox(width: CutlineSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: CutlineTextStyles.subtitleBold.copyWith(fontSize: 16)),
                const SizedBox(height: 4),
                Text(duration, style: CutlineTextStyles.caption),
              ],
            ),
          ),
          Text(price, style: CutlineTextStyles.title.copyWith(color: CutlineColors.primary, fontSize: 16)),
        ],
      ),
    );
  }
}

class _ComboOfferList extends StatelessWidget {
  final List<SalonCombo> combos;

  const _ComboOfferList({required this.combos});

  @override
  Widget build(BuildContext context) {
    if (combos.isEmpty) {
      return const _EmptyState(message: 'Combo offers will appear here soon.');
    }
    return ListView.builder(
      padding: CutlineSpacing.section.copyWith(top: 16, bottom: 16),
      itemCount: combos.length,
      itemBuilder: (context, index) {
        final offer = combos[index];
        return CutlineAnimations.staggeredList(
          index: index,
          child: _ComboOfferCard(offer: offer),
        );
      },
    );
  }
}

class _ComboOfferCard extends StatelessWidget {
  final SalonCombo offer;

  const _ComboOfferCard({required this.offer});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: CutlineSpacing.md),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Colors.orangeAccent, Colors.deepOrange], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(CutlineDecorations.radius),
        boxShadow: [
          BoxShadow(color: Colors.orangeAccent.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
        ],
      ),
      padding: CutlineSpacing.card,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(offer.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 6),
              Text(offer.details, style: const TextStyle(color: Colors.white70, fontSize: 14)),
              if (offer.discountLabel.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(offer.discountLabel,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
              ],
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text('৳${offer.price}', style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {},
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: Colors.deepOrange,
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
                child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          style: CutlineTextStyles.subtitle,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
