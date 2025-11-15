import 'package:cutline/ui/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

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
      body: TabBarView(
        controller: _tabController,
        children: const [
          _ServiceList(),
          _ComboOfferList(),
        ],
      ),
    );
  }
}

class _ServiceList extends StatelessWidget {
  const _ServiceList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: CutlineSpacing.section.copyWith(top: 16, bottom: 16),
      itemCount: 6,
      itemBuilder: (context, index) {
        return CutlineAnimations.staggeredList(
          index: index,
          child: _ServiceTile(
            title: 'Premium Service ${index + 1}',
            duration: 'Duration: 30 min',
            price: '৳${(index + 1) * 250}',
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
  const _ComboOfferList();

  static final List<_ComboOffer> comboOffers = [
    const _ComboOffer(title: '💎 Full Grooming Combo', details: 'Haircut + Beard + Facial', discount: 'Save 20% Today!', price: '৳850'),
    const _ComboOffer(title: '🔥 Classic Style Combo', details: 'Haircut + Beard Trim', discount: 'Save 15% on this combo!', price: '৳650'),
    const _ComboOffer(title: '✨ Luxury Spa Combo', details: 'Facial + Head Massage + Steam', discount: 'Save 25% Today!', price: '৳1200'),
  ];

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: CutlineSpacing.section.copyWith(top: 16, bottom: 16),
      itemCount: comboOffers.length,
      itemBuilder: (context, index) {
        final offer = comboOffers[index];
        return CutlineAnimations.staggeredList(index: index, child: _ComboOfferCard(offer: offer));
      },
    );
  }
}

class _ComboOfferCard extends StatelessWidget {
  final _ComboOffer offer;

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
              const SizedBox(height: 6),
              Text(offer.discount, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                child: Text(offer.price, style: const TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.bold, fontSize: 16)),
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

class _ComboOffer {
  final String title;
  final String details;
  final String discount;
  final String price;

  const _ComboOffer({required this.title, required this.details, required this.discount, required this.price});
}
