import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/user/providers/user_home_provider.dart';
import 'package:cutline/features/user/widgets/home_bottom_navigation.dart';
import 'package:cutline/features/user/widgets/nearby_salon_card.dart';
import 'package:cutline/features/user/widgets/user_promo_carousel.dart';
import 'package:cutline/features/user/widgets/user_promo_indicator.dart';
import 'package:cutline/features/user/widgets/user_search_bar.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({super.key});

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
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
        _pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
        if (nextPage == offers.length + 1) {
          await Future.delayed(const Duration(milliseconds: 600));
          _pageController.jumpToPage(1);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = context.read<AuthProvider>().currentUser?.uid ?? '';
    return ChangeNotifierProvider(
      create: (_) {
        final provider = UserHomeProvider(userId: userId);
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<UserHomeProvider>();
        return Scaffold(
          backgroundColor: CutlineColors.secondaryBackground,
          appBar: CutlineAppBar(
            title: 'Home',
            actions: [
              IconButton(
                icon: const Icon(Icons.notifications_none),
                onPressed: () =>
                    Navigator.pushNamed(context, AppRoutes.userNotifications),
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
                      UserPromoIndicator(
                        count: offers.length,
                        activeIndex: _currentOfferIndex,
                      ),
                      SizedBox(height: CutlineSpacing.md),
                      Text(
                        'Nearby Salons',
                        style: CutlineTextStyles.title
                            .copyWith(color: CutlineColors.primary),
                      ),
                      SizedBox(height: CutlineSpacing.sm),
                      if (provider.error != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: () => provider.load(),
                    child: provider.isLoading
                        ? ListView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            children: [
                              SizedBox(height: 140.h),
                              const Center(
                                child: CircularProgressIndicator(),
                              ),
                            ],
                          )
                        : provider.salons.isEmpty
                            ? ListView(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: CutlineSpacing.section
                                    .copyWith(bottom: 20.h),
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: CutlineDecorations.card(
                                      solidColor: CutlineColors.background,
                                    ),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: const [
                                        Text(
                                          'No salons found nearby.',
                                          style: CutlineTextStyles.title,
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          'Pull to refresh or try again later.',
                                          style: CutlineTextStyles.subtitle,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              )
                            : ListView.separated(
                                padding: CutlineSpacing.section
                                    .copyWith(bottom: 20.h),
                                itemCount: provider.salons.length,
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: CutlineSpacing.md),
                                itemBuilder: (context, index) {
                                  final salon = provider.salons[index];
                                  return CutlineAnimations.staggeredList(
                                    index: index,
                                    child: NearbySalonCard(
                                      salonName: salon.name,
                                      location: salon.locationLabel,
                                      waitMinutes: salon.waitMinutes,
                                      isOpen: salon.isOpenNow,
                                      isFavorite: salon.isFavorite,
                                      topServices: salon.topServices,
                                      onTap: () => Navigator.pushNamed(
                                        context,
                                        AppRoutes.salonDetails,
                                        arguments: SalonDetailsArgs(
                                          salonId: salon.id,
                                          salonName: salon.name,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                  ),
                ),
              ],
            ),
          ),
          bottomNavigationBar: HomeBottomNavigation(
            onItemTapped: (index) => _handleBottomTap(context, index),
          ),
        );
      },
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
