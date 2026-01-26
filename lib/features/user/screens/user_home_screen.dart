import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/user/providers/user_home_provider.dart';
import 'package:cutline/features/user/providers/user_location_provider.dart';
import 'package:cutline/features/user/widgets/home_bottom_navigation.dart';
import 'package:cutline/features/user/widgets/nearby_salon_card.dart';
import 'package:cutline/features/user/widgets/user_location_picker_bar.dart';
import 'package:cutline/shared/models/picked_location.dart';
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
  String? _lastAppliedLocationKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<UserLocationProvider>().initSilently();
    });
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
        final locationProvider = context.watch<UserLocationProvider>();
        final hasLocation = locationProvider.location != null;
        final locationLabel =
            locationProvider.location?.address ?? 'Set your location';

        _applyLocation(provider, locationProvider.location);
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
                      UserLocationPickerBar(
                        label: locationLabel,
                        isBusy: locationProvider.isBusy,
                        onTap: () => context
                            .read<UserLocationProvider>()
                            .pickLocation(context),
                      ),
                      if (locationProvider.error != null) ...[
                        SizedBox(height: 6.h),
                        Text(
                          locationProvider.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ],
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
                                      children: [
                                        Text(
                                          hasLocation
                                              ? 'No salons found nearby.'
                                              : 'Choose your location',
                                          style: CutlineTextStyles.title,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          hasLocation
                                              ? 'Pull to refresh or try again later.'
                                              : 'Tap the location bar above to set your area (5km radius).',
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
                                itemCount: provider.salons.length +
                                    (provider.canLoadMore ? 1 : 0),
                                separatorBuilder: (_, __) =>
                                    SizedBox(height: CutlineSpacing.md),
                                itemBuilder: (context, index) {
                                  if (index >= provider.salons.length) {
                                    provider.loadMore();
                                    return const Center(
                                      child: Padding(
                                        padding: EdgeInsets.all(16),
                                        child: CircularProgressIndicator(),
                                      ),
                                    );
                                  }
                                  final salon = provider.salons[index];
                                  return CutlineAnimations.staggeredList(
                                    index: index,
                                    child: NearbySalonCard(
                                      salonName: salon.name,
                                      location: salon.locationLabel,
                                      distanceLabel: salon.distanceLabel,
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

  void _applyLocation(UserHomeProvider homeProvider, PickedLocation? location) {
    final key = location == null
        ? null
        : '${location.latitude.toStringAsFixed(5)},${location.longitude.toStringAsFixed(5)}';
    if (key == _lastAppliedLocationKey) return;
    _lastAppliedLocationKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      homeProvider.setUserLocation(location);
    });
  }
}
