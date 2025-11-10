import 'package:cutline/ui/screens/user/chats_screen.dart';
import 'package:cutline/ui/screens/user/favorite_salon_screen.dart';
import 'package:cutline/ui/screens/user/user_profile_screen.dart';
import 'package:flutter/material.dart';
import 'salon_details_screen.dart';
import 'my_booking_screen.dart';

class UserHomeScreen extends StatefulWidget {
  const UserHomeScreen({Key? key}) : super(key: key);

  @override
  State<UserHomeScreen> createState() => _UserHomeScreenState();
}

class _UserHomeScreenState extends State<UserHomeScreen> {
  final List<String> nearbySalons = const [
    'Salon Luxe',
    'Urban Cuts',
    'Style Studio',
    'Glamour Hub',
    'Chic Salon',
  ];

  final List<String> offers = [
    'Get 20% off on your next visit!',
    'Refer a friend and earn discounts!',
    'Happy Hour: 10AM–1PM, 30% OFF!',
    'Book early and skip the queue!',
  ];
  int _currentOfferIndex = 0;
  // double _offsetX = 300.0;

  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: 1);
    _startOfferSlider();
  }

  void _startOfferSlider() async {
    while (mounted) {
      await Future.delayed(const Duration(seconds: 5));
      if (_pageController.hasClients) {
        int nextPage = (_pageController.page?.round() ?? 0) + 1;
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
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 1,
        title: const Text(
          'Home',
          style: TextStyle(
            color: Colors.blueAccent,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
        actions: [
          IconButton(
            icon:
                const Icon(Icons.notifications_none, color: Colors.blueAccent),
            onPressed: () {},
            tooltip: 'Notifications',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search salons...",
                    prefixIcon:
                        const Icon(Icons.search, color: Colors.blueAccent),
                    filled: true,
                    fillColor: Colors.grey[200],
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Animated Auto-Sliding Promotional Banners
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    height: 140,
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (index) {
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
                      itemCount:
                          offers.length + 2, // extra first and last duplicate
                      itemBuilder: (context, index) {
                        int realIndex;
                        if (index == 0) {
                          realIndex = offers.length -
                              1; // duplicate last offer at start
                        } else if (index == offers.length + 1) {
                          realIndex = 0; // duplicate first offer at end
                        } else {
                          realIndex = index - 1;
                        }
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: LinearGradient(
                              colors: [
                                Colors.blueAccent.shade400,
                                Colors.blueAccent.shade700,
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                          ),
                          child: Center(
                            child: Text(
                              offers[realIndex],
                              style: theme.textTheme.headlineSmall?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black26,
                                    blurRadius: 4,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(offers.length, (index) {
                    return AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      height: 8,
                      width: _currentOfferIndex == index ? 20 : 8,
                      decoration: BoxDecoration(
                        color: _currentOfferIndex == index
                            ? Colors.blueAccent
                            : Colors.blueAccent.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 32),

                // "Nearby Salons" section label
                Text(
                  "Nearby Salons",
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent.shade700,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                children: [
                  const SizedBox(height: 12),

                  // Nearby Salons Vertical List
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: nearbySalons.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 16),
                    itemBuilder: (context, index) {
                      return InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => SalonDetailsScreen(salonName: nearbySalons[index]),
                            ),
                          );
                        },
                        child: Container(
                          height: 300,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black12.withOpacity(0.05),
                                blurRadius: 4,
                                spreadRadius: 1,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Cover Image + Favorite Icon + Name/Rating Overlay
                              Stack(
                                children: [
                                  // Cover image placeholder
                                  Container(
                                    height: 200,
                                    width: double.infinity,
                                    decoration: BoxDecoration(
                                      borderRadius: const BorderRadius.only(
                                        topLeft: Radius.circular(16),
                                        topRight: Radius.circular(16),
                                      ),
                                      color: Colors.grey[300],
                                    ),
                                    child: const Center(
                                      child: Text(
                                        'Cover Image Area',
                                        style: TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 10,
                                    top: 10,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: Colors.black38,
                                        borderRadius: BorderRadius.circular(50),
                                      ),
                                      padding: const EdgeInsets.all(4),
                                      child: const Icon(Icons.favorite_border,
                                          color: Colors.white, size: 22),
                                    ),
                                  ),
                                  Positioned(
                                    left: 12,
                                    bottom: 10,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          nearbySalons[index],
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Row(
                                          children: const [
                                            Icon(Icons.star,
                                                size: 16,
                                                color: Colors.orangeAccent),
                                            SizedBox(width: 4),
                                            Text(
                                              "4.6 (120)",
                                              style: TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              // Info section
                              Flexible(fit: FlexFit.loose,
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: const [
                                              Icon(Icons.location_on,
                                                  size: 16, color: Colors.grey),
                                              SizedBox(width: 4),
                                              Expanded(
                                                child: Text(
                                                  "Banani, Dhaka • 0.8 km away",
                                                  style: TextStyle(
                                                      color: Colors.black87,
                                                      fontSize: 13),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 6),
                                          Row(
                                            children: const [
                                              Icon(Icons.access_time,
                                                  size: 16, color: Colors.grey),
                                              SizedBox(width: 4),
                                              Text(
                                                "Wait time: 10 mins  •  ",
                                                style: TextStyle(
                                                    color: Colors.black87,
                                                    fontSize: 13),
                                              ),
                                              Text(
                                                "Open Now",
                                                style: TextStyle(
                                                    color: Colors.green,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w600),
                                              ),
                                            ],
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            "Top Services: Haircut, Beard Trim, Facial",
                                            style: TextStyle(
                                                color: Colors.grey[700],
                                                fontSize: 13),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        selectedItemColor: Colors.blueAccent,
        unselectedItemColor: Colors.blueAccent.shade200,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        backgroundColor: Colors.white,
        onTap: (index) {
          if (index == 1) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MyBookingScreen()),
            );
          }
          if (index == 2) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => FavoriteSalonScreen()),
            );
          }
          if (index == 3) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => ChatsScreen()),
            );
          }
          if (index == 4) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => UserProfileScreen()),
            );
          }
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.queue_outlined),
            activeIcon: Icon(Icons.queue),
            label: 'My Booking',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.favorite_border),
            activeIcon: Icon(Icons.favorite),
            label: 'Favorite',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            activeIcon: Icon(Icons.chat_bubble),
            label: 'Chat',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            activeIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
