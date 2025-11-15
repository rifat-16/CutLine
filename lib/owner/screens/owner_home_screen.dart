import 'package:cutline/owner/screens/barbers_screen.dart';
import 'package:cutline/owner/screens/booking_requests_screen.dart';
import 'package:cutline/owner/screens/bookings_screen.dart';
import 'package:cutline/owner/screens/dashboard_screen.dart';
import 'package:cutline/owner/screens/manage_queue_screen.dart';
import 'package:cutline/owner/screens/manage_services_screen.dart';
import 'package:cutline/owner/screens/notifications_screen.dart';
import 'package:cutline/owner/screens/profile_screen.dart';
import 'package:cutline/owner/screens/settings_screen.dart';
import 'package:cutline/owner/screens/working_hours_screen.dart';
import 'package:cutline/owner/utils/constants.dart';
import 'package:cutline/owner/widgets/customer_detail_sheet.dart';
import 'package:cutline/owner/widgets/queue_card.dart';
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
          _MiniStatsRow(
            stats: [
              _MiniStatData(
                label: 'Waiting',
                value: waiting.toString(),
                caption: 'clients',
                color: const Color(0xFFFFB74D),
              ),
              _MiniStatData(
                label: 'Serving',
                value: serving.toString(),
                caption: 'in chairs',
                color: const Color(0xFF2563EB),
              ),
              _MiniStatData(
                label: 'Completed',
                value: completed.toString(),
                caption: 'today',
                color: const Color(0xFF22C55E),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _QuickActionGrid(
            actions: [
              _QuickAction(
                label: 'Booking requests',
                icon: Icons.fact_check_outlined,
                color: const Color(0xFF6366F1),
                badgeCount: pendingRequests,
                onTap: () => _openScreen(const BookingRequestsScreen()),
              ),
              _QuickAction(
                label: 'Queue board',
                icon: Icons.queue_play_next_outlined,
                color: const Color(0xFF0EA5E9),
                onTap: () => _openScreen(const ManageQueueScreen()),
              ),
              _QuickAction(
                label: 'Manage services',
                icon: Icons.design_services_outlined,
                color: const Color(0xFF10B981),
                onTap: () => _openScreen(const ManageServicesScreen()),
              ),
              _QuickAction(
                label: 'Working hours',
                icon: Icons.schedule_outlined,
                color: const Color(0xFFF97316),
                onTap: () => _openScreen(const WorkingHoursScreen()),
              ),
            ],
          ),
          const SizedBox(height: 28),
          _QueueListSection(
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

class _MiniStatsRow extends StatelessWidget {
  final List<_MiniStatData> stats;

  const _MiniStatsRow({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: stats.asMap().entries.map((entry) {
        final index = entry.key;
        final stat = entry.value;
        final isLast = index == stats.length - 1;
        return Expanded(
          child: Container(
            margin: EdgeInsets.only(right: isLast ? 0 : 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: stat.color.withValues(alpha: 0.12)),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x11000000),
                  blurRadius: 18,
                  offset: Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(stat.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, color: Colors.blueGrey)),
                const SizedBox(height: 6),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      stat.value,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: stat.color,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(stat.caption,
                          style: const TextStyle(color: Colors.blueGrey)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _MiniStatData {
  final String label;
  final String value;
  final String caption;
  final Color color;

  const _MiniStatData(
      {required this.label,
      required this.value,
      required this.caption,
      required this.color});
}

class _QuickActionGrid extends StatelessWidget {
  final List<_QuickAction> actions;

  const _QuickActionGrid({required this.actions});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: actions.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 2.3,
      ),
      itemBuilder: (_, index) => _QuickActionCard(action: actions[index]),
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  const _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });
}

class _QuickActionCard extends StatelessWidget {
  final _QuickAction action;

  const _QuickActionCard({required this.action});

  @override
  Widget build(BuildContext context) {
    final hasBadge = (action.badgeCount ?? 0) > 0;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        InkWell(
          onTap: action.onTap,
          borderRadius: BorderRadius.circular(22),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: action.color.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: action.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(action.icon, color: action.color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    action.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasBadge)
          Positioned(
            right: 12,
            top: -6,
            child: _Badge(count: action.badgeCount!),
          ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final int count;

  const _Badge({required this.count});

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFE53935),
        borderRadius: BorderRadius.circular(999),
        boxShadow: const [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Text(
        display,
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _QueueListSection extends StatelessWidget {
  final List<OwnerQueueItem> queue;
  final List<String> filters;
  final String selectedFilter;
  final ValueChanged<String> onFilterChange;
  final void Function(String id, OwnerQueueStatus status) onStatusChange;
  final VoidCallback onViewAll;
  final ValueChanged<OwnerQueueItem>? onOpenCustomer;

  const _QueueListSection({
    required this.queue,
    required this.filters,
    required this.selectedFilter,
    required this.onFilterChange,
    required this.onStatusChange,
    required this.onViewAll,
    this.onOpenCustomer,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Live queue',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
              TextButton(
                onPressed: onViewAll,
                child: const Text('View full board'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: filters
                  .map(
                    (filter) => Padding(
                      padding: const EdgeInsets.only(right: 10),
                      child: ChoiceChip(
                        label: Text(filter),
                        selected: selectedFilter == filter,
                        onSelected: (_) => onFilterChange(
                            selectedFilter == filter ? '' : filter),
                        selectedColor:
                            const Color(0xFF2563EB).withValues(alpha: 0.12),
                        labelPadding:
                            const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: const VisualDensity(horizontal: -3, vertical: -3),
                        labelStyle: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: selectedFilter == filter
                              ? const Color(0xFF2563EB)
                              : Colors.black54,
                        ),
                        backgroundColor: const Color(0xFFF3F4F6),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          if (queue.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                children: const [
                  Icon(Icons.task_alt_outlined, size: 32, color: Colors.green),
                  SizedBox(height: 10),
                  Text('All clear! No customers in this state.'),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: queue.length > 5 ? 5 : queue.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, index) {
                final item = queue[index];
                return OwnerQueueCard(
                  item: item,
                  onStatusChange: (status) => onStatusChange(item.id, status),
                  onTap: onOpenCustomer == null
                      ? null
                      : () => onOpenCustomer!(item),
                );
              },
            ),
        ],
      ),
    );
  }
}
