import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/user/providers/user_home_provider.dart';
import 'package:cutline/features/user/widgets/home_bottom_navigation.dart';
import 'package:cutline/features/user/widgets/nearby_salon_card.dart';
import 'package:cutline/features/user/widgets/user_search_bar.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:cutline/shared/widgets/notification_badge_icon.dart';
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
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
              NotificationBadgeIcon(
                userId: userId,
                onTap: () =>
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
                      UserSearchBar(
                        controller: _searchController,
                        onChanged: (query) {
                          context.read<UserHomeProvider>().setSearchQuery(query);
                        },
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
                        ? const Center(
                            child: CircularProgressIndicator(),
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
                                      coverImageUrl: salon.coverImageUrl,
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
