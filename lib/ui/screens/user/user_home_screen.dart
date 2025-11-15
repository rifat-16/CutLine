import 'package:cutline/ui/screens/user/chats_screen.dart';
import 'package:cutline/ui/screens/user/favorite_salon_screen.dart';
import 'package:cutline/ui/screens/user/my_booking_screen.dart';
import 'package:cutline/ui/screens/user/notification_screen.dart';
import 'package:cutline/ui/screens/user/salon_details_screen.dart';
import 'package:cutline/ui/screens/user/user_profile_screen.dart';
import 'package:cutline/ui/theme/cutline_theme.dart';
import 'package:flutter/material.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final List<String> nearbySalons = const ['Salon Luxe', 'Urban Cuts', 'Style Studio', 'Glamour Hub', 'Chic Salon'];
  final List<String> offers = const [
    'Get 20% off on your next visit!',
    'Refer a friend and earn discounts!',
    'Happy Hour: 10AM–1PM, 30% OFF!',
    'Book early and skip the queue!',
  ];

  late final PageController _pageController;
  int _currentOfferIndex = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    _startOfferSlider();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _startOfferSlider() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 5));
      if (_pageController.hasClients) {
        final nextPage = (_pageController.page?.round() ?? 0) + 1;
        _pageController.animateToPage(nextPage, duration: const Duration(milliseconds: 600), curve: Curves.easeInOut);
        if (nextPage == offers.length + 1) {
          await Future.delayed(const Duration(milliseconds: 600));
          _pageController.jumpToPage(1);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CutlineColors.secondaryBackground,
      appBar: CutlineAppBar(
        title: 'Home',
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationScreen())),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: CutlineSpacing.section.copyWith(top: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SearchBar(),
                const SizedBox(height: CutlineSpacing.sm),
                _PromoCarousel(
                  offers: offers,
                  currentIndex: _currentOfferIndex,
                  controller: _pageController,
                  onChanged: (index) {
                    setState(() {
                      if (index == 0) {
                        _currentOfferIndex = offers.length - 1;
                      } else if (index == offers.length + 1) {
                        _currentOfferIndex = 0;
                      } else {
                        _currentOfferIndex = index - 1;
                      }
                    });
                  },
                ),
                const SizedBox(height: CutlineSpacing.sm),
                _PromoIndicator(count: offers.length, activeIndex: _currentOfferIndex),
                const SizedBox(height: CutlineSpacing.md),
                Text('Nearby Salons', style: CutlineTextStyles.title.copyWith(color: CutlineColors.primary)),
                const SizedBox(height: CutlineSpacing.sm),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              padding: CutlineSpacing.section.copyWith(bottom: 20),
              itemCount: nearbySalons.length,
              separatorBuilder: (_, __) => const SizedBox(height: CutlineSpacing.md),
              itemBuilder: (context, index) {
                return CutlineAnimations.staggeredList(
                  index: index,
                  child: _NearbySalonCard(
                    salonName: nearbySalons[index],
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => SalonDetailsScreen(salonName: nearbySalons[index])),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _HomeBottomNavigation(onItemTapped: (index) => _handleBottomTap(context, index)),
    );
  }

  void _handleBottomTap(BuildContext context, int index) {
    if (index == 1) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => MyBookingScreen()));
    } else if (index == 2) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const FavoriteSalonScreen()));
    } else if (index == 3) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const ChatsScreen()));
    } else if (index == 4) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => const UserProfileScreen()));
    }
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();

  @override
  Widget build(BuildContext context) {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search salons...',
        prefixIcon: const Icon(Icons.search, color: CutlineColors.primary),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

class _PromoCarousel extends StatelessWidget {
  final List<String> offers;
  final int currentIndex;
  final PageController controller;
  final ValueChanged<int> onChanged;

  const _PromoCarousel({
    required this.offers,
    required this.currentIndex,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: SizedBox(
        height: 140,
        child: PageView.builder(
          controller: controller,
          onPageChanged: onChanged,
          itemCount: offers.length + 2,
          itemBuilder: (context, index) {
            int realIndex;
            if (index == 0) {
              realIndex = offers.length - 1;
            } else if (index == offers.length + 1) {
              realIndex = 0;
            } else {
              realIndex = index - 1;
            }
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [CutlineColors.primary.withValues(alpha: 0.7), CutlineColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Center(
                child: Text(
                  offers[realIndex],
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _PromoIndicator extends StatelessWidget {
  final int count;
  final int activeIndex;

  const _PromoIndicator({required this.count, required this.activeIndex});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        count,
        (index) => AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          height: 8,
          width: activeIndex == index ? 20 : 8,
          decoration: BoxDecoration(
            color: activeIndex == index ? CutlineColors.primary : CutlineColors.primary.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }
}

class _NearbySalonCard extends StatelessWidget {
  final String salonName;
  final VoidCallback onTap;

  const _NearbySalonCard({required this.salonName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(CutlineDecorations.radius),
      child: Container(
        decoration: CutlineDecorations.card(solidColor: CutlineColors.background),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  height: 200,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(CutlineDecorations.radius),
                      topRight: Radius.circular(CutlineDecorations.radius),
                    ),
                    color: Colors.grey.shade300,
                  ),
                  child: const Center(child: Text('Cover Image Area', style: CutlineTextStyles.subtitle)),
                ),
                Positioned(
                  right: 12,
                  top: 12,
                  child: Container(
                    decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(50)),
                    padding: const EdgeInsets.all(4),
                    child: const Icon(Icons.favorite_border, color: Colors.white),
                  ),
                ),
                Positioned(
                  left: 16,
                  bottom: 16,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(salonName, style: CutlineTextStyles.title.copyWith(color: Colors.white)),
                      Row(
                        children: const [
                          Icon(Icons.star, size: 16, color: CutlineColors.accent),
                          SizedBox(width: 4),
                          Text('4.6 (120)', style: TextStyle(color: Colors.white)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.location_on, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Expanded(child: Text('Banani, Dhaka • 0.8 km away', style: CutlineTextStyles.body)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: const [
                      Icon(Icons.access_time, size: 16, color: Colors.grey),
                      SizedBox(width: 4),
                      Text('Wait time: 10 mins  •  ', style: CutlineTextStyles.body),
                      Text('Open Now', style: TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const Text('Top Services: Haircut, Beard Trim, Facial', style: CutlineTextStyles.subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBottomNavigation extends StatelessWidget {
  final ValueChanged<int> onItemTapped;

  const _HomeBottomNavigation({required this.onItemTapped});

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: 0,
      selectedItemColor: CutlineColors.primary,
      showUnselectedLabels: true,
      type: BottomNavigationBarType.fixed,
      elevation: 8,
      backgroundColor: CutlineColors.background,
      onTap: onItemTapped,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), activeIcon: Icon(Icons.home), label: 'Home'),
        BottomNavigationBarItem(icon: Icon(Icons.queue_outlined), activeIcon: Icon(Icons.queue), label: 'My Booking'),
        BottomNavigationBarItem(icon: Icon(Icons.favorite_border), activeIcon: Icon(Icons.favorite), label: 'Favorite'),
        BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), activeIcon: Icon(Icons.chat_bubble), label: 'Chat'),
        BottomNavigationBarItem(icon: Icon(Icons.person_outline), activeIcon: Icon(Icons.person), label: 'Profile'),
      ],
    );
  }
}
