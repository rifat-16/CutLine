import 'package:cutline/routes/app_router.dart';
import 'package:cutline/features/user/widgets/home_bottom_navigation.dart';
import 'package:cutline/features/user/widgets/nearby_salon_card.dart';
import 'package:cutline/features/user/widgets/user_promo_carousel.dart';
import 'package:cutline/features/user/widgets/user_promo_indicator.dart';
import 'package:cutline/features/user/widgets/user_search_bar.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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
            onPressed: () => Navigator.pushNamed(context, AppRoutes.userNotifications),
          ),
          SizedBox(width: 8.w),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: CutlineSpacing.section.copyWith(top: 16.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const UserSearchBar(),
                  SizedBox(height: CutlineSpacing.sm),
                  UserPromoCarousel(
                    offers: offers,
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
                  UserPromoIndicator(count: offers.length, activeIndex: _currentOfferIndex),
                  SizedBox(height: CutlineSpacing.md),
                  Text('Nearby Salons',
                      style: CutlineTextStyles.title.copyWith(color: CutlineColors.primary)),
                  SizedBox(height: CutlineSpacing.sm),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: CutlineSpacing.section.copyWith(bottom: 20.h),
                itemCount: nearbySalons.length,
                separatorBuilder: (_, __) => SizedBox(height: CutlineSpacing.md),
                itemBuilder: (context, index) {
                  return CutlineAnimations.staggeredList(
                    index: index,
                    child: NearbySalonCard(
                      salonName: nearbySalons[index],
                      onTap: () => Navigator.pushNamed(
                        context,
                        AppRoutes.salonDetails,
                        arguments: SalonDetailsArgs(salonName: nearbySalons[index]),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar:
          HomeBottomNavigation(onItemTapped: (index) => _handleBottomTap(context, index)),
    );
  }

  void _handleBottomTap(BuildContext context, int index) {
    if (index == 1) {
      Navigator.pushNamed(context, AppRoutes.myBookings);
    } else if (index == 2) {
      Navigator.pushNamed(context, AppRoutes.favoriteSalons);
    } else if (index == 3) {
      Navigator.pushNamed(context, AppRoutes.userChats);
    } else if (index == 4) {
      Navigator.pushNamed(context, AppRoutes.userProfile);
    }
  }
}
