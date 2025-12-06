import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/owner_home_provider.dart';
import 'package:cutline/features/owner/screens/barbers_screen.dart';
import 'package:cutline/features/owner/screens/booking_requests_screen.dart';
import 'package:cutline/features/owner/screens/bookings_screen.dart';
import 'package:cutline/features/owner/screens/dashboard_screen.dart';
import 'package:cutline/features/owner/screens/manage_queue_screen.dart';
import 'package:cutline/features/owner/screens/manage_services_screen.dart';
import 'package:cutline/features/owner/screens/notifications_screen.dart';
import 'package:cutline/features/owner/screens/owner_chats_screen.dart';
import 'package:cutline/features/owner/screens/owner_profile_screen.dart';
import 'package:cutline/features/owner/screens/settings_screen.dart';
import 'package:cutline/features/owner/screens/working_hours_screen.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/customer_detail_sheet.dart';
import 'package:cutline/features/owner/widgets/mini_stats_row.dart';
import 'package:cutline/features/owner/widgets/quick_action_grid.dart';
import 'package:cutline/features/owner/widgets/queue_list_section.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OwnerHomeScreen extends StatefulWidget {
  const OwnerHomeScreen({super.key});

  @override
  State<OwnerHomeScreen> createState() => _OwnerHomeScreenState();
}

class _OwnerHomeScreenState extends State<OwnerHomeScreen> {
  int _selectedIndex = 0;
  String _queueFilter = 'Waiting';

  static const List<String> _queueFilters = ['Waiting', 'Serving', 'Completed'];

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final auth = context.read<AuthProvider>();
        final provider = OwnerHomeProvider(authProvider: auth);
        provider.fetchAll();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<OwnerHomeProvider>();
        final queue = provider.queueItems;
        final waiting = _statusCount(queue, OwnerQueueStatus.waiting);
        final serving = _statusCount(queue, OwnerQueueStatus.serving);
        final completed = _statusCount(queue, OwnerQueueStatus.done);
        final filteredQueue = _filteredQueue(queue);
        final pendingRequests = provider.pendingRequests;

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          appBar: _buildAppBar(context, provider),
          body: RefreshIndicator(
            onRefresh: () => provider.fetchAll(),
            child: ListView(
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
                    OwnerQuickAction(
                      label: 'Barbers',
                      icon: Icons.people_outline,
                      color: const Color(0xFF2563EB),
                      onTap: () => _openScreen(const OwnerBarbersScreen()),
                    ),
                    OwnerQuickAction(
                      label: 'Dashboard',
                      icon: Icons.dashboard_customize_outlined,
                      color: const Color(0xFF2563EB),
                      onTap: () => _openScreen(const OwnerDashboardScreen()),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                OwnerQueueListSection(
                  queue: filteredQueue,
                  selectedFilter: _queueFilter,
                  filters: _queueFilters,
                  onFilterChange: (value) {
                    setState(() => _queueFilter = value);
                  },
                  onStatusChange: (id, status) =>
                      _handleStatusChange(context, id, status),
                  onViewAll: () => _openScreen(const ManageQueueScreen()),
                  onOpenCustomer: (item) => _openCustomerDetails(context, item),
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNavigation(),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, OwnerHomeProvider provider) {
    return AppBar(
      elevation: 0,
      backgroundColor: Colors.white,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _openScreen(const OwnerProfileScreen()),
              child: CircleAvatar(
                radius: 18,
                backgroundColor: const Color(0xFF2563EB),
                child: const Icon(Icons.person, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          provider.salonName ?? 'Salon name',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontSize: 24),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildAvailabilityToggle(provider),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Owner dashboard',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Colors.blueGrey),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        IconButton(
          onPressed: () => _openScreen(const OwnerNotificationsScreen()),
          icon: const Icon(Icons.notifications_none_rounded),
        ),
        const SizedBox(width: 8),
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
            icon: Icon(Icons.event_note_outlined), label: 'Bookings'),
        BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline), label: 'Chats'),
        BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined), label: 'Settings'),
      ],
    );
  }

  List<OwnerQueueItem> _filteredQueue(List<OwnerQueueItem> queue) {
    final OwnerQueueStatus? status = _statusFromFilter(_queueFilter);
    final List<OwnerQueueItem> sorted = List.of(queue)
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

  int _statusCount(List<OwnerQueueItem> queue, OwnerQueueStatus status) {
    return queue.where((element) => element.status == status).length;
  }

  void _handleNavTap(int index) {
    setState(() => _selectedIndex = index);
    switch (index) {
      case 1:
        _openScreen(const ManageQueueScreen());
        break;
      case 2:
        _openScreen(const BookingsScreen());
        break;
      case 3:
        _openScreen(const OwnerChatsScreen());
        break;
      case 4:
        _openScreen(const OwnerSettingsScreen());
        break;
      default:
        break;
    }
  }

  Future<void> _handleStatusChange(
      BuildContext context, String id, OwnerQueueStatus status) async {
    final provider = context.read<OwnerHomeProvider>();
    await provider.updateQueueStatus(id, status);
  }

  void _openScreen(Widget screen) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
  }

  void _openCustomerDetails(BuildContext ctx, OwnerQueueItem item) {
    showCustomerDetailSheet(
      context: ctx,
      item: item,
      onStatusChange: (status) => _handleStatusChange(ctx, item.id, status),
    );
  }

  Widget _buildAvailabilityToggle(OwnerHomeProvider provider) {
    final statusColor = provider.isOpen ? const Color(0xFF22C55E) : Colors.red;
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          provider.isOpen ? 'Open' : 'Closed',
          style: TextStyle(
            color: statusColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(width: 8),
        Switch.adaptive(
          value: provider.isOpen,
          activeColor: const Color(0xFF2563EB),
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          onChanged: provider.isUpdatingStatus
              ? null
              : (value) => provider.setSalonOpen(value),
        ),
        if (provider.isUpdatingStatus) ...[
          const SizedBox(width: 6),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ],
      ],
    );
  }
}
