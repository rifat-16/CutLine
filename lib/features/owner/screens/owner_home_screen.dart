import 'package:cutline/features/owner/screens/barbers_screen.dart';
import 'package:cutline/features/owner/screens/booking_requests_screen.dart';
import 'package:cutline/features/owner/screens/bookings_screen.dart';
import 'package:cutline/features/owner/screens/dashboard_screen.dart';
import 'package:cutline/features/owner/screens/manage_queue_screen.dart';
import 'package:cutline/features/owner/screens/manage_services_screen.dart';
import 'package:cutline/features/owner/screens/notifications_screen.dart';
import 'package:cutline/features/owner/screens/profile_screen.dart';
import 'package:cutline/features/owner/screens/settings_screen.dart';
import 'package:cutline/features/owner/screens/working_hours_screen.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/customer_detail_sheet.dart';
import 'package:cutline/features/owner/widgets/mini_stats_row.dart';
import 'package:cutline/features/owner/widgets/quick_action_grid.dart';
import 'package:cutline/features/owner/widgets/queue_list_section.dart';
import 'package:flutter/material.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  final List<OwnerQueueItem> _queueItems = List.of(kOwnerQueueItems);
  int _selectedIndex = 0;
  String _queueFilter = '';

  static const List<String> _queueFilters = [
    'Waiting',
    'Serving',
    'Completed'
  ];

  @override
  Widget build(BuildContext context) {
    final waiting = _statusCount(OwnerQueueStatus.waiting);
    final serving = _statusCount(OwnerQueueStatus.serving);
    final completed = _statusCount(OwnerQueueStatus.done);
    final filteredQueue = _filteredQueue();
    final pendingRequests = kOwnerBookingRequests
        .where((request) => request.status == OwnerBookingRequestStatus.pending)
        .length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: _buildAppBar(context),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 140),
        physics: const BouncingScrollPhysics(),
        children: [
          OwnerMiniStatsRow(
            stats: [
              OwnerMiniStatData(
                label: 'Waiting',
                value: waiting.toString(),
                caption: 'clients',
                color: const Color(0xFFFFB74D),
              ),
              OwnerMiniStatData(
                label: 'Serving',
                value: serving.toString(),
                caption: 'in chairs',
                color: const Color(0xFF2563EB),
              ),
              OwnerMiniStatData(
                label: 'Completed',
                value: completed.toString(),
                caption: 'today',
                color: const Color(0xFF22C55E),
              ),
            ],
          ),
          const SizedBox(height: 24),
          OwnerQuickActionGrid(
            actions: [
              OwnerQuickAction(
                label: 'Booking requests',
                icon: Icons.fact_check_outlined,
                color: const Color(0xFF6366F1),
                badgeCount: pendingRequests,
                onTap: () => _openScreen(const BookingRequestsScreen()),
              ),
              OwnerQuickAction(
                label: 'Queue board',
                icon: Icons.queue_play_next_outlined,
                color: const Color(0xFF0EA5E9),
                onTap: () => _openScreen(const ManageQueueScreen()),
              ),
              OwnerQuickAction(
                label: 'Manage services',
                icon: Icons.design_services_outlined,
                color: const Color(0xFF10B981),
                onTap: () => _openScreen(const ManageServicesScreen()),
              ),
              OwnerQuickAction(
                label: 'Working hours',
                icon: Icons.schedule_outlined,
                color: const Color(0xFFF97316),
                onTap: () => _openScreen(const WorkingHoursScreen()),
              ),
            ],
          ),
          const SizedBox(height: 28),
          OwnerQueueListSection(
            queue: filteredQueue,
            selectedFilter: _queueFilter,
            filters: _queueFilters,
            onFilterChange: (value) {
              setState(() => _queueFilter = value);
            },
            onStatusChange: _handleStatusChange,
            onViewAll: () => _openScreen(const ManageQueueScreen()),
            onOpenCustomer: _openCustomerDetails,
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigation(),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      titleSpacing: 20,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Edge & Fade Studio',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontSize: 20)),
          const SizedBox(height: 2),
          Text('Owner dashboard',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.blueGrey)),
        ],
      ),
      actions: [
        IconButton(
          onPressed: () => _openScreen(const OwnerNotificationsScreen()),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: GestureDetector(
            onTap: () => _openScreen(const OwnerProfileScreen()),
            child: CircleAvatar(
              radius: 20,
              backgroundColor: const Color(0xFF2563EB),
              child: Text(
                _salonInitials(),
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigation() {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF2563EB),
      unselectedItemColor: Colors.blueGrey.shade400,
      onTap: _handleNavTap,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
        BottomNavigationBarItem(
            icon: Icon(Icons.queue_music_outlined), label: 'Queue'),
        BottomNavigationBarItem(
            icon: Icon(Icons.people_outline), label: 'Barbers'),
        BottomNavigationBarItem(
            icon: Icon(Icons.event_note_outlined), label: 'Bookings'),
        BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_customize_outlined), label: 'Dashboard'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined), label: 'Settings'),
      ],
    );
  }

  List<OwnerQueueItem> _filteredQueue() {
    final OwnerQueueStatus? status = _statusFromFilter(_queueFilter);
    final List<OwnerQueueItem> sorted = List.of(_queueItems)
      ..sort((a, b) => a.status.index.compareTo(b.status.index));
    if (status == null) {
      return sorted;
    }
    return sorted.where((item) => item.status == status).toList();
  }

  OwnerQueueStatus? _statusFromFilter(String filter) {
    switch (filter) {
      case 'Waiting':
        return OwnerQueueStatus.waiting;
      case 'Serving':
        return OwnerQueueStatus.serving;
      case 'Completed':
        return OwnerQueueStatus.done;
      default:
        return null;
    }
  }

  int _statusCount(OwnerQueueStatus status) {
    return _queueItems.where((element) => element.status == status).length;
  }

  void _handleNavTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 1:
        _openScreen(const ManageQueueScreen());
        break;
      case 2:
        _openScreen(const OwnerBarbersScreen());
        break;
      case 3:
        _openScreen(const BookingsScreen());
        break;
      case 4:
        _openScreen(const OwnerDashboardScreen());
        break;
      case 5:
        _openScreen(const OwnerSettingsScreen());
        break;
      default:
        break;
    }
  }

  void _handleStatusChange(String id, OwnerQueueStatus status) {
    setState(() {
      final index = _queueItems.indexWhere((item) => item.id == id);
      if (index != -1) {
        _queueItems[index] = _queueItems[index].copyWith(status: status);
      }
    });
  }

  void _openScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  String _salonInitials() {
    final parts = kOwnerSalonName
        .split(' ')
        .where((part) => part.trim().isNotEmpty)
        .toList();
    if (parts.isEmpty) return 'EF';
    return parts.map((e) => e[0]).take(2).join().toUpperCase();
  }

  void _openCustomerDetails(OwnerQueueItem item) {
    showCustomerDetailSheet(
      context: context,
      item: item,
      onStatusChange: (status) => _handleStatusChange(item.id, status),
    );
  }
}

