import 'package:cutline/features/user/screens/salon_gallery_screen.dart';
import 'package:cutline/features/user/screens/view_all_salon_services.dart';
import 'package:cutline/features/user/screens/waiting_customer_screen.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'booking_screen.dart';

// Root screen wiring together all sections.
class SalonDetailsScreen extends StatelessWidget {
  final String salonName;

  const SalonDetailsScreen({super.key, required this.salonName});

  static const SizedBox _smallGap = SizedBox(height: 12);
  static const SizedBox _mediumGap = SizedBox(height: 16);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CutlineColors.background,
      appBar: SalonDetailsAppBar(titleText: salonName),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const CoverPhotoSection(),
            SalonInfoSection(salonName: salonName),
            _smallGap,
            const WorkingHoursCard(),
            _mediumGap,
            const BarberListSection(),
            _mediumGap,
            SalonGallerySection(salonName: salonName),
            _mediumGap,
            const ComboOfferCard(),
            _mediumGap,
            ServicesSection(salonName: salonName),
            _mediumGap,
            const LiveQueueSection(),
            const SizedBox(height: 30),
          ],
        ),
      ),
      floatingActionButton: const BookNowFab(),
    );
  }
}

// App bar extracted for readability.
class SalonDetailsAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String titleText;

  const SalonDetailsAppBar({super.key, required this.titleText});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(titleText, style: CutlineTextStyles.appBarTitle),
      backgroundColor: CutlineColors.background,
      foregroundColor: CutlineColors.primary,
      elevation: 0.5,
      actions: [
        IconButton(
          onPressed: () {
            // TODO: Implement favorite toggle functionality.
          },
          icon: const Icon(Icons.favorite_border_rounded),
          tooltip: 'Add to Favorites',
        ),
      ],
    );
  }
}

// Cover photo placeholder.
class CoverPhotoSection extends StatelessWidget {
  const CoverPhotoSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      color: Colors.grey[300],
      child: const Center(
        child: Text(
          'Salon Cover Photo',
          style: TextStyle(color: Colors.grey),
        ),
      ),
    );
  }
}

// Info & contact details.
class SalonInfoSection extends StatelessWidget {
  final String salonName;

  const SalonInfoSection({super.key, required this.salonName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            CutlineColors.primary.withValues(alpha: 0.05),
            CutlineColors.background,
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  salonName,
                  style: CutlineTextStyles.title.copyWith(
                    fontSize: 22,
                    color: CutlineColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Row(
                children: const [
                  Icon(Icons.star, color: CutlineColors.accent, size: 20),
                  SizedBox(width: 4),
                  Text('4.6 (120 reviews)', style: CutlineTextStyles.subtitleBold),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.location_on, size: 18, color: CutlineColors.primary),
              const SizedBox(width: 6),
              const Expanded(
                child: Text(
                  'Banani, Dhaka • 0.8 km away',
                  style: CutlineTextStyles.body,
                ),
              ),
              TextButton(
                onPressed: () {
                  // TODO: Implement map opening function.
                },
                style: TextButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(40, 20),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('See Map', style: CutlineTextStyles.link),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const _IconTextRow(
            icon: Icons.home_outlined,
            label: 'House #12, Road #5, Banani, Dhaka',
          ),
          const SizedBox(height: 6),
          _IconTextRow(
            icon: Icons.phone,
            labelWidget: GestureDetector(
              onTap: () {
                // TODO: Implement phone call.
              },
              child: const Text(
                '+880 1700 123456',
                style: TextStyle(
                  color: CutlineColors.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          const _IconTextRow(
            icon: Icons.email_outlined,
            label: 'urbancuts@gmail.com',
          ),
          const SizedBox(height: 6),
          const _IconTextRow(
            icon: Icons.star_outline,
            label: 'Top Services: Haircut ✂️ • Beard Trim 🧔 • Hair Spa 💆‍♂️',
            wrap: true,
          ),
        ],
      ),
    );
  }
}

// Working hours detail card.
class WorkingHoursCard extends StatelessWidget {
  const WorkingHoursCard({super.key});

  static const List<_WorkingHour> _hours = [
    _WorkingHour(label: 'Monday – Friday', timeRange: '9:00 AM – 9:00 PM'),
    _WorkingHour(label: 'Saturday – Sunday', timeRange: '10:00 AM – 8:00 PM'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CutlineSpacing.section,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: CutlineDecorations.card(
          colors: [CutlineColors.background, CutlineColors.primary.withValues(alpha: 0.06)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: const [
                Icon(Icons.schedule_rounded, color: CutlineColors.primary, size: 22),
                SizedBox(width: 8),
                Text('Working Hours', style: CutlineTextStyles.title),
              ],
            ),
            const Divider(height: 18, thickness: 0.6),
            ..._hours.map(
              (hour) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(hour.label, style: CutlineTextStyles.body.copyWith(fontSize: 15)),
                    Text(hour.timeRange, style: CutlineTextStyles.caption.copyWith(fontSize: 15)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.check_circle, color: Colors.green, size: 18),
                  SizedBox(width: 6),
                  Text(
                    'Open Now • Closes at 9:00 PM',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Horizontal barber list.
class BarberListSection extends StatelessWidget {
  const BarberListSection({super.key});

  static const List<_BarberInfo> _barbers = [
    _BarberInfo(
      name: 'Barber 1',
      skills: 'Fade • Trim • Beard',
      rating: 4.8,
      isAvailable: true,
      waitingClients: 2,
      imagePath: 'assets/images/barber_1.jpg',
    ),
    _BarberInfo(
      name: 'Barber 2',
      skills: 'Fade • Trim • Beard',
      rating: 4.8,
      isAvailable: false,
      waitingClients: 0,
      imagePath: 'assets/images/barber_2.jpg',
    ),
    _BarberInfo(
      name: 'Barber 3',
      skills: 'Fade • Trim • Beard',
      rating: 4.8,
      isAvailable: true,
      waitingClients: 4,
      imagePath: 'assets/images/barber_3.jpg',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CutlineSpacing.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Our Barbers', style: CutlineTextStyles.title),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _barbers
                  .map(
                    (barber) => _BarberCard(barber: barber),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarberCard extends StatelessWidget {
  final _BarberInfo barber;

  const _BarberCard({required this.barber});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 170,
      margin: const EdgeInsets.only(right: 12, bottom: 8),
      decoration: CutlineDecorations.card(
        colors: [CutlineColors.background, CutlineColors.primary.withValues(alpha: 0.04)],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircleAvatar(radius: 32, backgroundImage: AssetImage(barber.imagePath)),
          const SizedBox(height: 10),
          Text(
            barber.name,
            style: CutlineTextStyles.subtitleBold.copyWith(fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(barber.skills, style: CutlineTextStyles.caption),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.star, color: CutlineColors.accent, size: 16),
              const SizedBox(width: 4),
              Text('${barber.rating}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            barber.isAvailable ? 'Available' : 'Unavailable',
            style: TextStyle(
              color: barber.isAvailable ? Colors.green : Colors.redAccent,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          if (barber.isAvailable) ...[
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_alt_rounded, color: CutlineColors.primary, size: 14),
                const SizedBox(width: 4),
                Text('${barber.waitingClients} waiting', style: CutlineTextStyles.caption),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// Gallery preview grid.
class SalonGallerySection extends StatelessWidget {
  final String salonName;

  const SalonGallerySection({super.key, required this.salonName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CutlineSpacing.section.copyWith(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Salon Gallery', style: CutlineTextStyles.title),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SalonGalleryScreen(salonName: salonName),
                    ),
                  );
                },
                child: const Text('See all', style: CutlineTextStyles.link),
              ),
            ],
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: 3,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemBuilder: (context, index) {
              return ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.asset('assets/images/salon_${(index % 4) + 1}.jpg', fit: BoxFit.cover),
              );
            },
          ),
        ],
      ),
    );
  }
}

// Combo offer highlight.
class ComboOfferCard extends StatelessWidget {
  const ComboOfferCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CutlineSpacing.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Combo Offers', style: CutlineTextStyles.title),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ViewAllSalonServices(salonName: ''),
                    ),
                  );
                },
                child: const Text('See all', style: CutlineTextStyles.link),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.orangeAccent, Colors.deepOrange],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(CutlineDecorations.radius),
              boxShadow: [
                BoxShadow(
                  color: Colors.orangeAccent.withValues(alpha: 0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      '💎 Full Grooming Combo',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text('Haircut + Beard + Facial', style: TextStyle(color: Colors.white70, fontSize: 14)),
                    SizedBox(height: 6),
                    Text(
                      'Save 20% Today!',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Text(
                        '৳850',
                        style: TextStyle(
                          color: Colors.deepOrange,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Add booking functionality.
                      },
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
          ),
        ],
      ),
    );
  }
}

// Services quick entry point.
class ServicesSection extends StatelessWidget {
  final String salonName;

  const ServicesSection({super.key, required this.salonName});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CutlineSpacing.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Services', style: CutlineTextStyles.title),
          const SizedBox(height: 12),
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ViewAllSalonServices(salonName: salonName),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
              decoration: CutlineDecorations.card(
                colors: [CutlineColors.background, CutlineColors.primary.withValues(alpha: 0.04)],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: const [
                      Icon(Icons.cut, color: CutlineColors.primary, size: 26),
                      SizedBox(width: 10),
                      Text(
                        'View All Salon Services',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: CutlineColors.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(8),
                    child: const Icon(Icons.arrow_forward_ios, size: 16, color: CutlineColors.primary),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Live queue + animated cards.
class LiveQueueSection extends StatelessWidget {
  const LiveQueueSection({super.key});

  static const List<_QueueEntry> _queueEntries = [
    _QueueEntry(
      customerName: 'Tanvir Ahmed',
      barber: 'Hasan',
      status: 'Waiting',
      eta: '≈ 15 mins',
      color: Colors.orangeAccent,
    ),
    _QueueEntry(
      customerName: 'Nafis Rahman',
      barber: 'Rafi',
      status: 'Waiting',
      eta: '≈ 25 mins',
      color: Colors.blueAccent,
    ),
    _QueueEntry(
      customerName: 'Arafat Hossain',
      barber: 'Sajid',
      status: 'Next',
      eta: '≈ 35 mins',
      color: Colors.green,
    ),
    _QueueEntry(
      customerName: 'Mehedi Hasan',
      barber: 'Rafi',
      status: 'Done',
      eta: 'Completed',
      color: Colors.redAccent,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: CutlineSpacing.section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Live Queue', style: CutlineTextStyles.title),
              Row(
                children: const [
                  Icon(Icons.refresh, size: 16, color: CutlineColors.primary),
                  SizedBox(width: 4),
                  Text('Updating live...', style: CutlineTextStyles.caption),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  CutlineColors.primary.withValues(alpha: 0.7),
                  CutlineColors.primary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(CutlineDecorations.radius),
              boxShadow: [
                BoxShadow(
                  color: CutlineColors.primary.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Now Serving', style: TextStyle(color: Colors.white70, fontSize: 14)),
                SizedBox(height: 4),
                Text(
                  'Hasan Ali',
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 6),
                Text('Barber: Rafi • Haircut & Beard Trim', style: TextStyle(color: Colors.white70, fontSize: 14)),
                SizedBox(height: 8),
                LinearProgressIndicator(
                  value: 0.65,
                  backgroundColor: Colors.white24,
                  color: Colors.white,
                  minHeight: 6,
                ),
                SizedBox(height: 4),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Text('≈ 10 mins left', style: TextStyle(color: Colors.white70, fontSize: 12)),
                ),
              ],
            ),
          )
              .animate()
              .slideY(begin: 0.3, end: 0, duration: 600.ms)
              .fadeIn(duration: 700.ms),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Waiting for Service', style: CutlineTextStyles.subtitleBold),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const WaitingListScreen()),
                  );
                },
                child: const Text('See all', style: CutlineTextStyles.link),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_queueEntries.length, (index) {
                final entry = _queueEntries[index];
                return _QueueCard(entry: entry)
                    .animate()
                    .fadeIn(duration: 400.ms, delay: (index * 100).ms)
                    .slideX(begin: 0.3, end: 0);
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueCard extends StatelessWidget {
  final _QueueEntry entry;

  const _QueueCard({required this.entry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(12),
      decoration: CutlineDecorations.card(solidColor: Colors.white),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: entry.color.withValues(alpha: 0.15),
                child: Icon(Icons.person, color: entry.color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  entry.customerName,
                  style: CutlineTextStyles.subtitleBold.copyWith(fontSize: 14),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Barber: ${entry.barber}', style: CutlineTextStyles.caption),
          const SizedBox(height: 4),
          const Text('Service: Haircut', style: CutlineTextStyles.caption),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: entry.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              entry.status,
              style: TextStyle(
                color: entry.color,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(entry.eta, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}

// Booking floating action button.
class BookNowFab extends StatelessWidget {
  const BookNowFab({super.key});

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.extended(
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const BookingScreen()),
        );
      },
      label: const Text(
        'Book Now',
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
      ),
      icon: const Icon(Icons.calendar_month_rounded, color: Colors.white),
      backgroundColor: CutlineColors.primary,
    );
  }
}

// Helper widgets & models ----------------------------------------------------
class _IconTextRow extends StatelessWidget {
  final IconData icon;
  final String? label;
  final Widget? labelWidget;
  final bool wrap;

  const _IconTextRow({
    required this.icon,
    this.label,
    this.labelWidget,
    this.wrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final textWidget = labelWidget ?? Text(label ?? '', style: CutlineTextStyles.body);

    return Row(
      crossAxisAlignment: wrap ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: CutlineColors.primary),
        const SizedBox(width: 6),
        wrap ? Expanded(child: textWidget) : textWidget,
      ],
    );
  }
}

class _BarberInfo {
  final String name;
  final String skills;
  final double rating;
  final bool isAvailable;
  final int waitingClients;
  final String imagePath;

  const _BarberInfo({
    required this.name,
    required this.skills,
    required this.rating,
    required this.isAvailable,
    required this.waitingClients,
    required this.imagePath,
  });
}

class _QueueEntry {
  final String customerName;
  final String barber;
  final String status;
  final String eta;
  final Color color;

  const _QueueEntry({
    required this.customerName,
    required this.barber,
    required this.status,
    required this.eta,
    required this.color,
  });
}

class _WorkingHour {
  final String label;
  final String timeRange;

  const _WorkingHour({required this.label, required this.timeRange});
}
