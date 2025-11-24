import 'package:cutline/features/user/screens/booking_summary_screen.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  final List<String> services = const ['Haircut', 'Beard Trim', 'Facial', 'Coloring'];
  final List<String> barbers = const ['Arafat', 'Rafi', 'Siam', 'Hasan'];
  final List<String> timeSlots = const [
    '10:00 AM',
    '10:30 AM',
    '11:00 AM',
    '11:30 AM',
    '12:00 PM',
    '12:30 PM',
    '1:00 PM',
    '1:30 PM',
    '2:00 PM',
    '2:30 PM',
    '3:00 PM',
    '3:30 PM',
    '4:00 PM',
    '4:30 PM',
    '5:00 PM',
    '5:30 PM',
    '6:00 PM',
    '6:30 PM',
    '7:00 PM',
    '7:30 PM',
  ];
  final List<String> bookedSlots = const ['11:00 AM', '2:30 PM', '5:00 PM'];
  final Map<String, int> servicePrices = const {
    'Haircut': 500,
    'Beard Trim': 300,
    'Facial': 800,
    'Coloring': 1200,
  };

  List<String> selectedServiceList = [];
  String? selectedBarber;
  DateTime selectedDate = DateTime.now();
  String? selectedTime;
  int currentWaiting = 3;

  @override
  Widget build(BuildContext context) {
    final total = selectedServiceList.fold<int>(0, (sum, service) => sum + (servicePrices[service] ?? 0));

    return Scaffold(
      appBar: const CutlineAppBar(title: 'Book Your Slot'),
      body: SingleChildScrollView(
        padding: CutlineSpacing.screen.copyWith(bottom: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CutlineAnimations.entrance(
              _SalonInfoCard(
                salonName: 'Urban Fade Salon',
                location: 'Dhanmondi, Dhaka',
                rating: 4.8,
                workingHours: '10 AM - 8 PM',
                imageUrl: 'https://images.unsplash.com/photo-1600891964093-3b40cc0d2c7e',
              ),
            ),
            const SizedBox(height: CutlineSpacing.md),
            const CutlineSectionHeader(title: 'Select Service'),
            const SizedBox(height: CutlineSpacing.sm),
            _ServiceSelector(
              services: services,
              servicePrices: servicePrices,
              selectedServices: selectedServiceList,
              onToggle: (service) {
                setState(() {
                  if (selectedServiceList.contains(service)) {
                    selectedServiceList.remove(service);
                  } else {
                    selectedServiceList.add(service);
                  }
                });
              },
            ),
            const SizedBox(height: CutlineSpacing.md),
            const CutlineSectionHeader(title: 'Select Barber'),
            const SizedBox(height: CutlineSpacing.sm),
            _BarberGrid(
              barbers: barbers,
              selectedBarber: selectedBarber,
              onSelected: (value) => setState(() => selectedBarber = value),
            ),
            const SizedBox(height: CutlineSpacing.md),
            const CutlineSectionHeader(title: 'Select Date'),
            const SizedBox(height: CutlineSpacing.sm),
            _DateScroller(
              selectedDate: selectedDate,
              onSelected: (date) => setState(() => selectedDate = date),
            ),
            const SizedBox(height: CutlineSpacing.md),
            const CutlineSectionHeader(title: 'Select Time Slot'),
            const SizedBox(height: CutlineSpacing.sm),
            _TimeSlotGrid(
              timeSlots: timeSlots,
              bookedSlots: bookedSlots,
              selectedSlot: selectedTime,
              onTap: (slot) => setState(() => selectedTime = slot),
            ),
            const SizedBox(height: CutlineSpacing.sm),
            Text(
              'Current waiting: $currentWaiting people ahead',
              style: CutlineTextStyles.subtitle,
            ),
            const SizedBox(height: CutlineSpacing.sm),
            const Text('Estimated wait time: 20 min', style: CutlineTextStyles.subtitle),
            const SizedBox(height: CutlineSpacing.lg),
            _BookingSummaryCard(
              totalAmount: total,
              canProceed: selectedServiceList.isNotEmpty && selectedBarber != null && selectedTime != null,
              onConfirm: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const BookingSummaryScreen()),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _SalonInfoCard extends StatelessWidget {
  final String salonName;
  final String location;
  final double rating;
  final String workingHours;
  final String imageUrl;

  const _SalonInfoCard({
    required this.salonName,
    required this.location,
    required this.rating,
    required this.workingHours,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CutlineDecorations.card(
        colors: [CutlineColors.background, CutlineColors.primary.withValues(alpha: 0.04)],
      ),
      padding: CutlineSpacing.card,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              imageUrl,
              width: 60,
              height: 60,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => Container(
                width: 60,
                height: 60,
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: const Icon(Icons.image_not_supported, color: Colors.grey),
              ),
            ),
          ),
          const SizedBox(width: CutlineSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  salonName,
                  style: CutlineTextStyles.title.copyWith(fontSize: 20),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  location,
                  style: CutlineTextStyles.subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    _IconText(icon: Icons.star, text: rating.toStringAsFixed(1)),
                    _IconText(icon: Icons.schedule, text: workingHours),
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

class _ServiceSelector extends StatelessWidget {
  final List<String> services;
  final Map<String, int> servicePrices;
  final List<String> selectedServices;
  final ValueChanged<String> onToggle;

  const _ServiceSelector({
    required this.services,
    required this.servicePrices,
    required this.selectedServices,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(services.length, (index) {
        final service = services[index];
        final isSelected = selectedServices.contains(service);
        final chip = ChoiceChip(
          label: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(isSelected ? Icons.check : Icons.add, size: 18, color: isSelected ? Colors.white : CutlineColors.primary),
                const SizedBox(width: 6),
                Text('$service  ৳${servicePrices[service] ?? 0}'),
              ],
            ),
          ),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: CutlineColors.primary,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(color: isSelected ? Colors.white : CutlineColors.primary, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: isSelected ? CutlineColors.primary : Colors.grey.shade300, width: 1.2),
          ),
          onSelected: (_) => onToggle(service),
        );
        return CutlineAnimations.staggeredList(child: chip, index: index);
      }),
    );
  }
}

class _BarberGrid extends StatelessWidget {
  final List<String> barbers;
  final String? selectedBarber;
  final ValueChanged<String> onSelected;

  const _BarberGrid({required this.barbers, required this.selectedBarber, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: barbers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final barber = barbers[index];
        final isSelected = barber == selectedBarber;
        final card = GestureDetector(
          onTap: () => onSelected(barber),
          child: Container(
            decoration: CutlineDecorations.card(
              colors: isSelected
                  ? [CutlineColors.primary.withValues(alpha: 0.7), CutlineColors.primary]
                  : [CutlineColors.background, CutlineColors.secondaryBackground],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ClipOval(
                  child: Image.network(
                    'https://i.pravatar.cc/150?img=${index + 10}',
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      width: 44,
                      height: 44,
                      color: Colors.grey.shade200,
                      alignment: Alignment.center,
                      child: const Icon(Icons.person, color: Colors.grey, size: 22),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  barber,
                  style: TextStyle(
                    color: isSelected ? Colors.white : CutlineColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '⭐ 4.9 • Hair Specialist',
                  style: TextStyle(color: isSelected ? Colors.white70 : Colors.black54, fontSize: 12),
                ),
              ],
            ),
          ),
        );
        return CutlineAnimations.staggeredList(child: card, index: index);
      },
    );
  }
}

class _DateScroller extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onSelected;

  const _DateScroller({required this.selectedDate, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final isSelected = selectedDate.year == date.year && selectedDate.month == date.month && selectedDate.day == date.day;
          final card = GestureDetector(
            onTap: () => onSelected(date),
            child: Container(
              width: 70,
              margin: EdgeInsets.only(right: index == 6 ? 0 : 12),
              decoration: BoxDecoration(
                color: isSelected ? CutlineColors.primary : Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CutlineColors.primary),
              ),
              child: Center(
                child: Text(
                  DateFormat('EEE\ndd').format(date),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isSelected ? Colors.white : CutlineColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          );
          return CutlineAnimations.staggeredList(child: card, index: index);
        },
      ),
    );
  }
}

class _TimeSlotGrid extends StatelessWidget {
  final List<String> timeSlots;
  final List<String> bookedSlots;
  final String? selectedSlot;
  final ValueChanged<String> onTap;

  const _TimeSlotGrid({
    required this.timeSlots,
    required this.bookedSlots,
    required this.selectedSlot,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: timeSlots.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.6,
      ),
      itemBuilder: (context, index) {
        final slot = timeSlots[index];
        final isBooked = bookedSlots.contains(slot);
        final isSelected = selectedSlot == slot;
        final card = GestureDetector(
          onTap: isBooked ? () {} : () => onTap(slot),
          child: Container(
            decoration: BoxDecoration(
              color: isBooked
                  ? Colors.grey.shade200
                  : (isSelected ? CutlineColors.primary : Colors.white),
              border: Border.all(color: isBooked ? Colors.grey.shade300 : CutlineColors.primary),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                slot,
                style: TextStyle(
                  color: isBooked
                      ? Colors.grey
                      : (isSelected ? Colors.white : CutlineColors.primary),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
        return CutlineAnimations.staggeredList(child: card, index: index);
      },
    );
  }
}

class _BookingSummaryCard extends StatelessWidget {
  final int totalAmount;
  final bool canProceed;
  final VoidCallback onConfirm;

  const _BookingSummaryCard({
    required this.totalAmount,
    required this.canProceed,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: CutlineSpacing.md),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: canProceed ? onConfirm : null,
              style: CutlineButtons.primary(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: const Text('Confirm Booking', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;

  const _IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: CutlineColors.primary),
        const SizedBox(width: 4),
        Text(text, style: CutlineTextStyles.subtitle),
      ],
    );
  }
}
