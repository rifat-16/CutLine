import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/user/providers/booking_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class BookingScreen extends StatefulWidget {
  final String salonId;
  final String salonName;

  const BookingScreen({
    super.key,
    required this.salonId,
    required this.salonName,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<String> selectedServiceList = [];
  String? selectedBarber;
  DateTime selectedDate = DateTime.now();
  String? selectedTime;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          BookingProvider(salonId: widget.salonId, salonName: widget.salonName)
            ..loadInitial(selectedDate),
      builder: (context, _) {
        final provider = context.watch<BookingProvider>();
        final services = provider.services;
        final barbers = provider.barbers;
        final servicePrices = {
          for (final s in services) s.name: s.price,
        };
        final total = selectedServiceList.fold<int>(
            0, (sum, service) => sum + (servicePrices[service] ?? 0));
        return Scaffold(
          appBar: const CutlineAppBar(title: 'Book Your Slot'),
          body: provider.isLoading && provider.services.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: CutlineSpacing.screen.copyWith(bottom: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CutlineAnimations.entrance(
                        _SalonInfoCard(
                          salonName: widget.salonName.isNotEmpty
                              ? widget.salonName
                              : 'Salon',
                          location: provider.address.isNotEmpty
                              ? provider.address
                              : 'Location unavailable',
                          rating: provider.rating,
                          workingHours: provider.workingHoursLabel,
                          imageUrl: provider.coverImageUrl ??
                              'https://images.unsplash.com/photo-1600891964093-3b40cc0d2c7e',
                        ),
                      ),
                      const SizedBox(height: CutlineSpacing.md),
                      if (provider.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      const CutlineSectionHeader(title: 'Select Service'),
                      const SizedBox(height: CutlineSpacing.sm),
                      _ServiceSelector(
                        services: services.map((e) => e.name).toList(),
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
                        barbers: barbers.map((e) => e.name).toList(),
                        selectedBarber: selectedBarber,
                        onSelected: (value) =>
                            setState(() => selectedBarber = value),
                      ),
                      const SizedBox(height: CutlineSpacing.md),
                      const CutlineSectionHeader(title: 'Select Date'),
                      const SizedBox(height: CutlineSpacing.sm),
                      _DateScroller(
                        selectedDate: selectedDate,
                        isClosed: provider.isClosedOn,
                        onSelected: (date) {
                          setState(() {
                            selectedDate = date;
                            selectedTime = null;
                          });
                          provider.updateTimeSlotsForDate(date);
                          provider.loadBookedSlots(date);
                        },
                      ),
                      const SizedBox(height: CutlineSpacing.md),
                      const CutlineSectionHeader(title: 'Select Time Slot'),
                      const SizedBox(height: CutlineSpacing.sm),
                      _TimeSlotGrid(
                        timeSlots: provider.timeSlots,
                        bookedSlots: provider.bookedSlots,
                        selectedSlot: selectedTime,
                        selectedDate: selectedDate,
                        now: DateTime.now(),
                        onTap: (slot) => setState(() => selectedTime = slot),
                      ),
                      const SizedBox(height: CutlineSpacing.sm),
                      Text(
                        'Current waiting: ${provider.currentWaiting} people ahead',
                        style: CutlineTextStyles.subtitle,
                      ),
                      const SizedBox(height: CutlineSpacing.sm),
                      const Text('Estimated wait time: 20 min',
                          style: CutlineTextStyles.subtitle),
                      const SizedBox(height: CutlineSpacing.lg),
                      _BookingSummaryCard(
                        totalAmount: total,
                        canProceed: selectedServiceList.isNotEmpty &&
                            selectedBarber != null &&
                            selectedTime != null,
                        onConfirm: () {
                          final auth = context.read<AuthProvider>();
                          final user = auth.currentUser;
                          final profile = auth.profile;
                          final customerName =
                              user?.displayName?.trim().isNotEmpty == true
                                  ? user!.displayName!
                                  : 'Guest';
                          final customerEmail =
                              user?.email?.trim().isNotEmpty == true
                                  ? user!.email!
                                  : '';
                          final customerPhone = (profile?.phone ??
                                  user?.phoneNumber ??
                                  '')
                              .trim();
                          final customerUid = user?.uid ?? '';

                          Navigator.pushNamed(
                            context,
                            AppRoutes.bookingSummary,
                            arguments: BookingSummaryArgs(
                              salonId: widget.salonId,
                              salonName: widget.salonName,
                              services: selectedServiceList,
                              barberName: selectedBarber ?? '',
                              date: selectedDate,
                              time: selectedTime ?? '',
                              customerName: customerName,
                              customerPhone: customerPhone,
                              customerEmail: customerEmail,
                              customerUid: customerUid,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
        );
      },
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
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.grey.shade200,
                  child: const Icon(Icons.person, color: Colors.grey, size: 22),
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
  final bool Function(DateTime)? isClosed;

  const _DateScroller({
    required this.selectedDate,
    required this.onSelected,
    this.isClosed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: 7,
        itemBuilder: (context, index) {
          final date = DateTime.now().add(Duration(days: index));
          final closed = isClosed?.call(date) ?? false;
          final isSelected = selectedDate.year == date.year && selectedDate.month == date.month && selectedDate.day == date.day;
          final card = GestureDetector(
            onTap: closed ? null : () => onSelected(date),
            child: Container(
              width: 70,
              margin: EdgeInsets.only(right: index == 6 ? 0 : 12),
              decoration: BoxDecoration(
                color: closed
                    ? Colors.grey.shade200
                    : (isSelected ? CutlineColors.primary : Colors.white),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CutlineColors.primary),
              ),
              child: Center(
                child: Text(
                  DateFormat('EEE\ndd').format(date),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: closed
                        ? Colors.grey
                        : (isSelected ? Colors.white : CutlineColors.primary),
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
  final DateTime selectedDate;
  final DateTime now;

  const _TimeSlotGrid({
    required this.timeSlots,
    required this.bookedSlots,
    required this.selectedSlot,
    required this.onTap,
    required this.selectedDate,
    required this.now,
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
        final isPast = _isPastSlot(slot);
        final isDisabled = isBooked || isPast;
        final card = GestureDetector(
          onTap: isDisabled ? () {} : () => onTap(slot),
          child: Container(
            decoration: BoxDecoration(
              color: isDisabled
                  ? Colors.grey.shade200
                  : (isSelected ? CutlineColors.primary : Colors.white),
              border: Border.all(
                  color: isDisabled ? Colors.grey.shade300 : CutlineColors.primary),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Text(
                slot,
                style: TextStyle(
                  color: isDisabled
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

  bool _isPastSlot(String slot) {
    // Only block past times on the selected date (today).
    if (selectedDate.year != now.year ||
        selectedDate.month != now.month ||
        selectedDate.day != now.day) {
      return false;
    }
    try {
      final parsed = DateFormat('h:mm a').parse(slot);
      final slotDateTime = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        parsed.hour,
        parsed.minute,
      );
      return slotDateTime.isBefore(now);
    } catch (_) {
      return false;
    }
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
