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
import 'package:cutline/shared/widgets/notification_badge_icon.dart';
import 'package:cutline/features/owner/widgets/mini_stats_row.dart';
import 'package:cutline/features/owner/widgets/quick_action_grid.dart';
import 'package:cutline/features/owner/widgets/queue_list_section.dart';
import 'package:cutline/shared/models/salon_verification_status.dart';
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
        if (!provider.hasLoadedSalon) {
          return const Scaffold(
            backgroundColor: Color(0xFFF4F6FB),
            body: SafeArea(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        final queue = provider.queueItems;
        final waiting = _statusCount(queue, OwnerQueueStatus.waiting);
        final serving = _statusCount(queue, OwnerQueueStatus.serving);
        final completed = _statusCount(queue, OwnerQueueStatus.done);
        final filteredQueue = _filteredQueue(queue);
        final pendingRequests = provider.pendingRequests;
        final showVerificationBanner =
            provider.salonDocExists && !provider.isVerified;

        if (showVerificationBanner) {
          return Scaffold(
            backgroundColor: const Color(0xFFF4F6FB),
            body: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: ConstrainedBox(
                      constraints:
                          BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 460),
                            child: _VerificationBlockingView(
                              status: provider.verificationStatus,
                              reviewNote: provider.reviewNote,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          );
        }

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
                      onTap: () async {
                        await _guardVerification(
                          provider,
                          onAllowed: () async =>
                              _openScreen(const BookingRequestsScreen()),
                        );
                      },
                    ),
                    OwnerQuickAction(
                      label: 'Queue board',
                      icon: Icons.queue_play_next_outlined,
                      color: const Color(0xFF0EA5E9),
                      onTap: () async {
                        await _guardVerification(
                          provider,
                          onAllowed: () async =>
                              _openScreen(const ManageQueueScreen()),
                        );
                      },
                    ),
                    OwnerQuickAction(
                      label: 'Manage services',
                      icon: Icons.design_services_outlined,
                      color: const Color(0xFF10B981),
                      onTap: () async {
                        await _guardVerification(
                          provider,
                          onAllowed: () async =>
                              _openScreen(const ManageServicesScreen()),
                        );
                      },
                    ),
                    OwnerQuickAction(
                      label: 'Working hours',
                      icon: Icons.schedule_outlined,
                      color: const Color(0xFFF97316),
                      onTap: () async {
                        await _guardVerification(
                          provider,
                          onAllowed: () async =>
                              _openScreen(const WorkingHoursScreen()),
                        );
                      },
                    ),
                    OwnerQuickAction(
                      label: 'Barbers',
                      icon: Icons.people_outline,
                      color: const Color(0xFF2563EB),
                      onTap: () async {
                        await _guardVerification(
                          provider,
                          onAllowed: () async =>
                              _openScreen(const OwnerBarbersScreen()),
                        );
                      },
                    ),
                    OwnerQuickAction(
                      label: 'Dashboard',
                      icon: Icons.dashboard_customize_outlined,
                      color: const Color(0xFF2563EB),
                      onTap: () async {
                        await _guardVerification(
                          provider,
                          onAllowed: () async =>
                              _openScreen(const OwnerDashboardScreen()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                // Only show error if it's a real error, not just empty data
                if (provider.error != null && provider.error!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.red.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline,
                              color: Colors.red.shade700, size: 20),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              provider.error!,
                              style: TextStyle(
                                  color: Colors.red.shade700, fontSize: 13),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Show setup prompt if salon not set up yet
                if (provider.error == null &&
                    provider.salonName == null &&
                    !provider.isLoading)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, color: Colors.blue.shade700),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Setup your salon',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Complete your salon profile to start receiving bookings',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.blue.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                OwnerQueueListSection(
                  queue: filteredQueue,
                  selectedFilter: _queueFilter,
                  filters: _queueFilters,
                  onFilterChange: (value) {
                    setState(() => _queueFilter = value);
                  },
                  onStatusChange: (id, status) => _guardVerification(
                    provider,
                    onAllowed: () => _handleStatusChange(context, id, status),
                  ),
                  onViewAll: () async {
                    await _guardVerification(
                      provider,
                      onAllowed: () async =>
                          _openScreen(const ManageQueueScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          bottomNavigationBar: _buildBottomNavigation(provider),
        );
      },
    );
  }

  PreferredSizeWidget _buildAppBar(
      BuildContext context, OwnerHomeProvider provider) {
    final userId = context.read<AuthProvider>().currentUser?.uid ?? '';
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
              child: Builder(
                builder: (context) {
                  // Prioritize salon photoUrl, fallback to user profile photo
                  final salonPhotoUrl = provider.photoUrl;
                  final userPhotoUrl =
                      context.watch<AuthProvider>().profile?.photoUrl;
                  final photoUrl = salonPhotoUrl?.isNotEmpty == true
                      ? salonPhotoUrl
                      : (userPhotoUrl?.isNotEmpty == true
                          ? userPhotoUrl
                          : null);

                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: const Color(0xFF2563EB),
                    backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                        ? NetworkImage(photoUrl)
                        : null,
                    child: photoUrl == null || photoUrl.isEmpty
                        ? const Icon(Icons.person,
                            color: Colors.white, size: 28)
                        : null,
                  );
                },
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
                      Flexible(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: _buildAvailabilityToggle(provider),
                          ),
                        ),
                      ),
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
        NotificationBadgeIcon(
          userId: userId,
          icon: Icons.notifications_none_rounded,
          onTap: () => _openScreen(const OwnerNotificationsScreen()),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  Widget _buildBottomNavigation(OwnerHomeProvider provider) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: const Color(0xFF2563EB),
      unselectedItemColor: Colors.blueGrey.shade400,
      onTap: (index) => _handleNavTap(provider, index),
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
    final List<OwnerQueueItem> filtered = status == null
        ? List.of(queue)
        : queue.where((item) => item.status == status).toList();

    filtered.sort(_compareQueueItems);
    return filtered;
  }

  int _compareQueueItems(OwnerQueueItem a, OwnerQueueItem b) {
    final DateTime? aDt = a.scheduledAt;
    final DateTime? bDt = b.scheduledAt;

    // Keep scheduled items above unscheduled ones.
    if (aDt == null && bDt != null) return 1;
    if (aDt != null && bDt == null) return -1;

    if (aDt != null && bDt != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final aDay = DateTime(aDt.year, aDt.month, aDt.day);
      final bDay = DateTime(bDt.year, bDt.month, bDt.day);

      final aIsPast = aDay.isBefore(today);
      final bIsPast = bDay.isBefore(today);
      if (aIsPast != bIsPast) return aIsPast ? 1 : -1;

      final dayCompare = aDay.compareTo(bDay);
      if (dayCompare != 0) return dayCompare;

      final timeCompare = aDt.compareTo(bDt);
      if (timeCompare != 0) return timeCompare;
    }

    final waitCompare = a.waitMinutes.compareTo(b.waitMinutes);
    if (waitCompare != 0) return waitCompare;

    return a.customerName.compareTo(b.customerName);
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

  Future<void> _handleNavTap(OwnerHomeProvider provider, int index) async {
    switch (index) {
      case 1:
        await _guardVerification(
          provider,
          onAllowed: () async {
            setState(() => _selectedIndex = index);
            _openScreen(const ManageQueueScreen());
          },
        );
        break;
      case 2:
        await _guardVerification(
          provider,
          onAllowed: () async {
            setState(() => _selectedIndex = index);
            _openScreen(const BookingsScreen());
          },
        );
        break;
      case 3:
        setState(() => _selectedIndex = index);
        _openScreen(const OwnerChatsScreen());
        break;
      case 4:
        setState(() => _selectedIndex = index);
        _openScreen(const OwnerSettingsScreen());
        break;
      default:
        setState(() => _selectedIndex = index);
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
          onChanged: provider.isUpdatingStatus || !provider.isVerified
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

  Future<void> _guardVerification(
    OwnerHomeProvider provider, {
    required Future<void> Function() onAllowed,
  }) async {
    if (provider.isVerified) {
      await onAllowed();
      return;
    }

    final message = provider.verificationStatus ==
            SalonVerificationStatus.rejected
        ? 'Your salon verification was rejected. Please review the note and try again.'
        : 'Your salon is under verification. You will get full access after approval.';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}

class _VerificationBlockingView extends StatelessWidget {
  const _VerificationBlockingView({
    required this.status,
    this.reviewNote,
  });

  final SalonVerificationStatus status;
  final String? reviewNote;

  @override
  Widget build(BuildContext context) {
    final isRejected = status == SalonVerificationStatus.rejected;
    final headline =
        isRejected ? 'Verification rejected' : 'Verification pending';
    final subhead = isRejected
        ? 'Your salon setup needs changes before approval.'
        : 'We are reviewing your salon setup. Full access unlocks after approval.';
    final note = isRejected
        ? (reviewNote != null && reviewNote!.trim().isNotEmpty
            ? reviewNote!.trim()
            : 'No note was added. Please update your salon details and resubmit.')
        : null;

    final accent =
        isRejected ? const Color(0xFFEF4444) : const Color(0xFFF59E0B);
    final accentSoft = accent.withValues(alpha: 0.12);

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accentSoft,
            const Color(0xFFF4F6FB),
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: accent.withValues(alpha: 0.18)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 22,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: accentSoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      isRejected ? Icons.cancel_outlined : Icons.hourglass_top,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          headline,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          subhead,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.25,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (note != null) ...[
                const SizedBox(height: 14),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: accentSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    note,
                    style: const TextStyle(
                      fontSize: 13,
                      height: 1.25,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF9FAFB),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isRejected ? 'What to do next' : 'What happens next',
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _NextStepRow(
                      accent: accent,
                      text: isRejected
                          ? 'Update your salon details and photos.'
                          : 'We review your salon information.',
                    ),
                    const SizedBox(height: 8),
                    _NextStepRow(
                      accent: accent,
                      text: isRejected
                          ? 'We will review again after you resubmit.'
                          : 'After approval, your dashboard unlocks.',
                    ),
                    const SizedBox(height: 8),
                    _NextStepRow(
                      accent: accent,
                      text: isRejected
                          ? 'Customers will see your salon after approval.'
                          : 'Customers can see your salon after approval.',
                    ),
                    if (!isRejected) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(999),
                        child: LinearProgressIndicator(
                          value: null,
                          minHeight: 6,
                          backgroundColor: const Color(0xFFE5E7EB),
                          color: accent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextStepRow extends StatelessWidget {
  const _NextStepRow({required this.accent, required this.text});

  final Color accent;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(Icons.check, size: 14, color: accent),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.25,
              color: Colors.black87,
            ),
          ),
        ),
      ],
    );
  }
}
