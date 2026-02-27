import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/user/providers/booking_provider.dart';
import 'package:cutline/routes/app_router.dart';
import 'package:cutline/shared/theme/cutline_theme.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

enum BookingFlowMode { nextFree, custom }

class BookingScreen extends StatefulWidget {
  final String salonId;
  final String salonName;
  final List<String> preselectedServices;
  final bool lockServices;

  const BookingScreen({
    super.key,
    required this.salonId,
    required this.salonName,
    this.preselectedServices = const [],
    this.lockServices = false,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  List<String> selectedServiceList = [];
  String? selectedBarber;
  String? selectedBarberId;
  String? selectedBarberAvatar;
  DateTime selectedDate = DateTime.now();
  String? selectedTime;
  bool _comboServicesResolved = false;
  bool _hasManualServiceChange = false;
  BookingFlowMode bookingMode = BookingFlowMode.nextFree;

  @override
  void initState() {
    super.initState();
    selectedServiceList = List<String>.from(widget.preselectedServices);
  }

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
        _resolveComboServices(provider);
        final selectedBarberModel = barbers.where((barber) {
          if (selectedBarberId != null && selectedBarberId!.isNotEmpty) {
            return barber.uid == selectedBarberId;
          }
          return barber.name == selectedBarber;
        }).toList();
        final activeBarber =
            selectedBarberModel.isNotEmpty ? selectedBarberModel.first : null;
        final selectedInsight = activeBarber == null
            ? null
            : provider.queueInsightForBarber(
                barberId: activeBarber.uid,
                barberName: activeBarber.name,
              );
        final predictedSerialNo = selectedInsight?.nextSerial;
        final predictedStartAt = activeBarber == null
            ? null
            : provider.estimatedStartForBarber(
                barberId: activeBarber.uid,
                barberName: activeBarber.name,
              );
        final isNextFreeMode = bookingMode == BookingFlowMode.nextFree;
        final isSelectedBarberAvailable = activeBarber?.isAvailable ?? false;
        final servicePrices = {
          for (final s in services) s.name: s.price,
        };
        final total = selectedServiceList.fold<int>(
            0, (sum, service) => sum + (servicePrices[service] ?? 0));
        final canProceedNextFree = selectedServiceList.isNotEmpty &&
            selectedBarber != null &&
            provider.isSalonOpen &&
            isSelectedBarberAvailable;
        final canProceedCustom = selectedServiceList.isNotEmpty &&
            selectedBarber != null &&
            selectedTime != null;
        final canLockServices =
            widget.lockServices && selectedServiceList.isNotEmpty;
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
                      if (!canLockServices) ...[
                        const CutlineSectionHeader(title: 'Select Service'),
                        const SizedBox(height: CutlineSpacing.sm),
                        _ServiceSelector(
                          services: services.map((e) => e.name).toList(),
                          servicePrices: servicePrices,
                          selectedServices: selectedServiceList,
                          onToggle: (service) {
                            _hasManualServiceChange = true;
                            setState(() {
                              if (selectedServiceList.contains(service)) {
                                selectedServiceList.remove(service);
                              } else {
                                selectedServiceList.add(service);
                              }
                            });
                          },
                        ),
                        if (widget.lockServices &&
                            widget.preselectedServices.isNotEmpty &&
                            selectedServiceList.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              'Combo services not matched. Please select services manually.',
                              style: const TextStyle(color: Colors.orange),
                            ),
                          ),
                      ] else ...[
                        const CutlineSectionHeader(title: 'Selected Services'),
                        const SizedBox(height: CutlineSpacing.sm),
                        _SelectedServiceChips(
                          services: selectedServiceList,
                        ),
                      ],
                      const SizedBox(height: CutlineSpacing.md),
                      const CutlineSectionHeader(title: 'Booking Type'),
                      const SizedBox(height: CutlineSpacing.sm),
                      _BookingModeSelector(
                        selectedMode: bookingMode,
                        nextFreeEnabled: provider.isSalonOpen,
                        onChanged: (mode) async {
                          if (mode == bookingMode) return;
                          setState(() {
                            bookingMode = mode;
                            if (mode == BookingFlowMode.nextFree) {
                              selectedTime = null;
                            }
                          });
                          if (mode == BookingFlowMode.nextFree) {
                            await provider.refreshQueueInsights();
                            return;
                          }
                          if (selectedBarber != null) {
                            await provider.loadBookedSlots(
                              selectedDate,
                              barberName: selectedBarber,
                            );
                          }
                        },
                      ),
                      if (!provider.isSalonOpen && isNextFreeMode)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Salon is closed now. Use Custom Date & Time for future booking.',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      if (isNextFreeMode &&
                          selectedBarber != null &&
                          !isSelectedBarberAvailable)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            'Selected barber is unavailable for next free queue. Choose another barber or switch to custom.',
                            style: TextStyle(
                              color: Colors.orange.shade700,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      const SizedBox(height: CutlineSpacing.md),
                      const CutlineSectionHeader(title: 'Select Barber'),
                      const SizedBox(height: CutlineSpacing.sm),
                      _BarberGrid(
                        barbers: barbers,
                        selectedBarber: selectedBarber,
                        bookingMode: bookingMode,
                        insightForBarber: (barber) =>
                            provider.queueInsightForBarber(
                          barberId: barber.uid,
                          barberName: barber.name,
                        ),
                        onSelected: (barber) async {
                          if (isNextFreeMode && !barber.isAvailable) return;
                          setState(() {
                            selectedBarber = barber.name;
                            selectedBarberId = barber.uid;
                            selectedBarberAvatar = barber.avatarUrl;
                          });
                          await provider.refreshQueueInsights();
                          if (!mounted) return;
                          if (bookingMode == BookingFlowMode.nextFree) return;
                          await provider.loadBookedSlots(
                            selectedDate,
                            barberName: barber.name,
                          );
                          if (!mounted) return;
                          if (selectedTime != null &&
                              provider.bookedSlots.contains(selectedTime)) {
                            setState(() => selectedTime = null);
                          }
                        },
                      ),
                      if (isNextFreeMode) ...[
                        const SizedBox(height: CutlineSpacing.md),
                        _NextFreePreview(
                          serialNo: predictedSerialNo,
                          estimatedStart: predictedStartAt,
                        ),
                      ] else ...[
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
                            provider.loadBookedSlots(
                              date,
                              barberName: selectedBarber,
                            );
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
                      ],
                      const SizedBox(height: CutlineSpacing.sm),
                      Text(
                        provider.currentWaiting <= 0
                            ? 'Avg wait: No wait'
                            : 'Avg wait: ${provider.currentWaiting} min',
                        style: CutlineTextStyles.subtitle,
                      ),
                      const SizedBox(height: CutlineSpacing.lg),
                      _BookingSummaryCard(
                        totalAmount: total,
                        canProceed: isNextFreeMode
                            ? canProceedNextFree
                            : canProceedCustom,
                        buttonLabel:
                            isNextFreeMode ? 'Join Queue' : 'Confirm Booking',
                        onConfirm: () {
                          final auth = context.read<AuthProvider>();
                          final user = auth.currentUser ??
                              fb_auth.FirebaseAuth.instance.currentUser;
                          final profile = auth.profile;
                          final customerName =
                              user?.displayName?.trim().isNotEmpty == true
                                  ? user!.displayName!
                                  : 'Guest';
                          final customerEmail =
                              user?.email?.trim().isNotEmpty == true
                                  ? user!.email!
                                  : '';
                          final customerPhone =
                              (profile?.phone ?? user?.phoneNumber ?? '')
                                  .trim();
                          final customerUid = user?.uid ?? '';
                          final effectiveStartAt =
                              predictedStartAt ?? DateTime.now();
                          final bookingDate =
                              isNextFreeMode ? effectiveStartAt : selectedDate;
                          final bookingTime = isNextFreeMode
                              ? DateFormat('h:mm a').format(effectiveStartAt)
                              : (selectedTime ?? '');

                          Navigator.pushNamed(
                            context,
                            AppRoutes.bookingSummary,
                            arguments: BookingSummaryArgs(
                              salonId: widget.salonId,
                              salonName: widget.salonName,
                              services: selectedServiceList,
                              barberName: selectedBarber ?? '',
                              barberId: selectedBarberId ?? '',
                              barberAvatar: selectedBarberAvatar,
                              date: bookingDate,
                              time: bookingTime,
                              customerName: customerName,
                              customerPhone: customerPhone,
                              customerEmail: customerEmail,
                              customerUid: customerUid,
                              bookingMode: _modeValue(bookingMode),
                              predictedSerialNo:
                                  isNextFreeMode ? predictedSerialNo : null,
                              predictedStartAt:
                                  isNextFreeMode ? predictedStartAt : null,
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

  String _modeValue(BookingFlowMode mode) {
    return mode == BookingFlowMode.nextFree ? 'next_free' : 'custom';
  }

  void _resolveComboServices(BookingProvider provider) {
    if (_comboServicesResolved ||
        _hasManualServiceChange ||
        widget.preselectedServices.isEmpty) {
      return;
    }
    if (provider.services.isEmpty) return;

    final available = provider.services.map((e) => e.name).toList();
    final matched = _matchServices(widget.preselectedServices, available);
    _comboServicesResolved = true;
    if (matched.isEmpty) {
      if (selectedServiceList.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          setState(() {
            selectedServiceList = [];
          });
        });
      }
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        selectedServiceList = matched;
      });
    });
  }

  List<String> _matchServices(
      List<String> desiredServices, List<String> available) {
    final normalizedMap = <String, String>{};
    for (final service in available) {
      final normalized = _normalizeServiceName(service);
      if (normalized.isEmpty) continue;
      normalizedMap.putIfAbsent(normalized, () => service);
    }

    final matched = <String>[];
    for (final desired in desiredServices) {
      final normalizedDesired = _normalizeServiceName(desired);
      if (normalizedDesired.isEmpty) continue;
      final exact = normalizedMap[normalizedDesired];
      if (exact != null) {
        matched.add(exact);
        continue;
      }
      String? fallback;
      for (final entry in normalizedMap.entries) {
        if (entry.key.contains(normalizedDesired) ||
            normalizedDesired.contains(entry.key)) {
          fallback = entry.value;
          break;
        }
      }
      if (fallback != null) matched.add(fallback);
    }
    return matched.toSet().toList();
  }

  String _normalizeServiceName(String input) {
    return input.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '').trim();
  }
}

class _SalonInfoCard extends StatelessWidget {
  final String salonName;
  final String location;
  final String workingHours;
  final String imageUrl;

  const _SalonInfoCard({
    required this.salonName,
    required this.location,
    required this.workingHours,
    required this.imageUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: CutlineDecorations.card(
        colors: [
          CutlineColors.background,
          CutlineColors.primary.withValues(alpha: 0.04)
        ],
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
                child:
                    const Icon(Icons.image_not_supported, color: Colors.grey),
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
                Icon(isSelected ? Icons.check : Icons.add,
                    size: 18,
                    color: isSelected ? Colors.white : CutlineColors.primary),
                const SizedBox(width: 6),
                Text('$service  ৳${servicePrices[service] ?? 0}'),
              ],
            ),
          ),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: CutlineColors.primary,
          backgroundColor: Colors.white,
          labelStyle: TextStyle(
              color: isSelected ? Colors.white : CutlineColors.primary,
              fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
                color:
                    isSelected ? CutlineColors.primary : Colors.grey.shade300,
                width: 1.2),
          ),
          onSelected: (_) => onToggle(service),
        );
        return CutlineAnimations.staggeredList(child: chip, index: index);
      }),
    );
  }
}

class _SelectedServiceChips extends StatelessWidget {
  final List<String> services;

  const _SelectedServiceChips({required this.services});

  @override
  Widget build(BuildContext context) {
    if (services.isEmpty) {
      return const Text(
        'No services selected.',
        style: CutlineTextStyles.subtitle,
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: services.map((service) {
        return Chip(
          label: Text(service),
          backgroundColor: CutlineColors.primary.withValues(alpha: 0.12),
          labelStyle: const TextStyle(
            color: CutlineColors.primary,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side:
                BorderSide(color: CutlineColors.primary.withValues(alpha: 0.4)),
          ),
        );
      }).toList(),
    );
  }
}

class _BookingModeSelector extends StatelessWidget {
  final BookingFlowMode selectedMode;
  final bool nextFreeEnabled;
  final ValueChanged<BookingFlowMode> onChanged;

  const _BookingModeSelector({
    required this.selectedMode,
    required this.nextFreeEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ChoiceChip(
            label: const Text('Next Free Slot'),
            selected: selectedMode == BookingFlowMode.nextFree,
            onSelected: nextFreeEnabled
                ? (_) => onChanged(BookingFlowMode.nextFree)
                : null,
            selectedColor: CutlineColors.primary.withValues(alpha: 0.16),
            backgroundColor: Colors.grey.shade100,
            labelStyle: TextStyle(
              color: selectedMode == BookingFlowMode.nextFree
                  ? CutlineColors.primary
                  : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: ChoiceChip(
            label: const Text('Custom Date & Time'),
            selected: selectedMode == BookingFlowMode.custom,
            onSelected: (_) => onChanged(BookingFlowMode.custom),
            selectedColor: CutlineColors.primary.withValues(alpha: 0.16),
            backgroundColor: Colors.grey.shade100,
            labelStyle: TextStyle(
              color: selectedMode == BookingFlowMode.custom
                  ? CutlineColors.primary
                  : Colors.black87,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class _NextFreePreview extends StatelessWidget {
  final int? serialNo;
  final DateTime? estimatedStart;

  const _NextFreePreview({
    required this.serialNo,
    required this.estimatedStart,
  });

  @override
  Widget build(BuildContext context) {
    final serialLabel = serialNo != null ? '#$serialNo' : '--';
    final timeLabel = estimatedStart != null
        ? DateFormat('EEE, dd MMM • h:mm a').format(estimatedStart!)
        : '--';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Next Free Slot Preview',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Serial Preview: $serialLabel',
            style: CutlineTextStyles.subtitleBold,
          ),
          const SizedBox(height: 4),
          Text(
            'Estimated Start: $timeLabel',
            style: CutlineTextStyles.subtitle,
          ),
        ],
      ),
    );
  }
}

class _BarberGrid extends StatelessWidget {
  final List<BookingBarber> barbers;
  final String? selectedBarber;
  final BookingFlowMode bookingMode;
  final BarberQueueInsight Function(BookingBarber barber) insightForBarber;
  final ValueChanged<BookingBarber> onSelected;

  const _BarberGrid({
    required this.barbers,
    required this.selectedBarber,
    required this.bookingMode,
    required this.insightForBarber,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: barbers.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.98,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final barber = barbers[index];
        final insight = insightForBarber(barber);
        final isSelected = barber.name == selectedBarber;
        final canTap =
            bookingMode != BookingFlowMode.nextFree || barber.isAvailable;
        final card = GestureDetector(
          onTap: canTap ? () => onSelected(barber) : null,
          child: Container(
            decoration: CutlineDecorations.card(
              colors: isSelected
                  ? [
                      CutlineColors.primary.withValues(alpha: 0.7),
                      CutlineColors.primary
                    ]
                  : [
                      CutlineColors.background,
                      CutlineColors.secondaryBackground
                    ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipOval(
                  child: Container(
                    width: 56,
                    height: 56,
                    color: Colors.grey.shade200,
                    child: barber.avatarUrl != null &&
                            barber.avatarUrl!.isNotEmpty
                        ? Image.network(
                            barber.avatarUrl!,
                            fit: BoxFit.cover,
                            loadingBuilder: (context, child, loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                  strokeWidth: 2,
                                ),
                              );
                            },
                            errorBuilder: (_, __, ___) => const Icon(
                              Icons.person,
                              color: Colors.grey,
                              size: 28,
                            ),
                          )
                        : const Icon(Icons.person,
                            color: Colors.grey, size: 28),
                  ),
                ),
                const SizedBox(height: 6),
                Flexible(
                  child: Text(
                    barber.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white : CutlineColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Flexible(
                  child: Text(
                    barber.isAvailable ? 'Available' : 'Unavailable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected
                          ? Colors.white70
                          : (barber.isAvailable
                              ? Colors.green.shade700
                              : Colors.redAccent),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Flexible(
                  child: Text(
                    '${insight.waitingCount} waiting',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.black54,
                      fontSize: 11,
                    ),
                  ),
                ),
                Flexible(
                  child: Text(
                    'Next serial #${insight.nextSerial}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: isSelected ? Colors.white70 : Colors.black54,
                      fontSize: 11,
                    ),
                  ),
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
          final isSelected = selectedDate.year == date.year &&
              selectedDate.month == date.month &&
              selectedDate.day == date.day;
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
                  color: isDisabled
                      ? Colors.grey.shade300
                      : CutlineColors.primary),
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
  final String buttonLabel;
  final VoidCallback onConfirm;

  const _BookingSummaryCard({
    required this.totalAmount,
    required this.canProceed,
    required this.buttonLabel,
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
            style: CutlineButtons.primary(
                padding: const EdgeInsets.symmetric(vertical: 16)),
            child: Text(
              buttonLabel,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
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
