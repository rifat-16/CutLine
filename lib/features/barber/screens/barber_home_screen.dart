import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/barber/providers/barber_home_provider.dart';
import 'package:cutline/shared/widgets/notification_badge_icon.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import 'barber_notification_screen.dart';
import 'barber_profile_screen.dart';

class BarberHomeScreen extends StatefulWidget {
  const BarberHomeScreen({super.key});

  @override
  State<BarberHomeScreen> createState() => _BarberHomeScreenState();
}

class _BarberHomeScreenState extends State<BarberHomeScreen> {
  BarberQueueStatus? _selectedStatus = BarberQueueStatus.waiting;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final provider =
            BarberHomeProvider(authProvider: context.read<AuthProvider>());
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<BarberHomeProvider>();
        final queue = _filteredQueue(provider.queue);

        return Scaffold(
          appBar: _buildAppBar(context, provider),
          body: RefreshIndicator(
            onRefresh: () => provider.load(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                if (!provider.isSalonOpen)
                  Container(
                    padding: const EdgeInsets.all(14),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Icon(Icons.info_outline, color: Colors.red),
                        SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'The salon is currently closed. Please ask the owner to open the salon to start serving customers.',
                            style: TextStyle(color: Colors.red, fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                const Text(
                  "Today's queue",
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                _buildQueueTabs(),
                const SizedBox(height: 16),
                if (provider.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      provider.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                if (!provider.isSalonOpen)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.lock_outline,
                            size: 40, color: Colors.black54),
                        SizedBox(height: 10),
                        Text(
                          "Salon is closed. Queue will appear when the owner opens the salon.",
                          style: TextStyle(fontSize: 15, color: Colors.black54),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  )
                else if (provider.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 40),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (queue.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                    ),
                    child: Column(
                      children: const [
                        Icon(Icons.inbox_outlined,
                            size: 40, color: Colors.black54),
                        SizedBox(height: 10),
                        Text(
                          "No customers in this queue.",
                          style: TextStyle(fontSize: 15, color: Colors.black54),
                        ),
                      ],
                    ),
                  )
                else
                  ...queue.asMap().entries.map(
                    (entry) {
                      final item = entry.value;
                      final isCurrentTurn =
                          item.status == BarberQueueStatus.waiting &&
                              entry.key == 0;
                      return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _QueueCard(
                        item: item,
                        onStartServing: isCurrentTurn
                            ? () => provider.updateStatus(
                                  item.id,
                                  BarberQueueStatus.serving,
                                )
                            : null,
                        onCancel: isCurrentTurn
                            ? () => provider.updateStatus(
                                  item.id,
                                  BarberQueueStatus.cancelled,
                                )
                            : null,
                        onMarkDone: item.status == BarberQueueStatus.serving
                            ? () => provider.updateStatus(
                                  item.id,
                                  BarberQueueStatus.done,
                                )
                            : null,
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

  AppBar _buildAppBar(BuildContext context, BarberHomeProvider provider) {
    final userId = context.read<AuthProvider>().currentUser?.uid ?? '';
    final salonName = provider.salonName;
    return AppBar(
      titleSpacing: 0,
      centerTitle: false,
      title: Padding(
        padding: const EdgeInsets.only(left: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              salonName?.isNotEmpty == true ? salonName! : 'Salon',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
      actions: [
        _AvailabilityToggle(provider: provider),
        NotificationBadgeIcon(
          userId: userId,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (context) => const BarberNotificationScreen()),
            );
          },
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: InkWell(
            onTap: () async {
              final updated = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                    builder: (context) => const BarberProfileScreen()),
              );
              if (!mounted) return;
              if (updated == true) {
                context.read<BarberHomeProvider>().load();
              }
            },
            child: CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey,
              backgroundImage: provider.profile?.photoUrl != null &&
                      provider.profile!.photoUrl.isNotEmpty
                  ? NetworkImage(provider.profile!.photoUrl)
                  : null,
              child: provider.profile?.photoUrl == null ||
                      provider.profile!.photoUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.white)
                  : null,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQueueTabs() {
    const tabStatuses = [
      BarberQueueStatus.waiting,
      BarberQueueStatus.serving,
      BarberQueueStatus.done,
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: tabStatuses.map((status) {
          final isSelected = _selectedStatus == status;
          return GestureDetector(
            onTap: () => setState(() => _selectedStatus = status),
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: _queueTab(_statusLabel(status), isSelected),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<BarberQueueItem> _filteredQueue(List<BarberQueueItem> queue) {
    final selected = _selectedStatus;
    final sorted = List.of(queue)
      ..sort((a, b) {
        final aDt = a.scheduledAt;
        final bDt = b.scheduledAt;
        if (aDt != null && bDt != null) return aDt.compareTo(bDt);
        if (aDt != null) return -1;
        if (bDt != null) return 1;
        return a.waitMinutes.compareTo(b.waitMinutes);
      });
    if (selected == null) return sorted;
    return sorted.where((item) => item.status == selected).toList();
  }
}

class _AvailabilityToggle extends StatelessWidget {
  final BarberHomeProvider provider;

  const _AvailabilityToggle({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: provider.isLoading
          ? const SizedBox(
              width: 36,
              height: 36,
              child: Center(
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          : _AvailabilitySwitch(provider: provider),
    );
  }
}

class _AvailabilitySwitch extends StatelessWidget {
  final BarberHomeProvider provider;

  const _AvailabilitySwitch({required this.provider});

  @override
  Widget build(BuildContext context) {
    final isAvailable = provider.isAvailable;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _statusDot(isAvailable),
        const SizedBox(width: 6),
        Text(
          isAvailable ? 'Available' : 'Unavailable',
          style: TextStyle(
            color: isAvailable ? Colors.green : Colors.redAccent,
            fontWeight: FontWeight.w600,
          ),
        ),
        Switch.adaptive(
          value: isAvailable,
          onChanged: provider.isUpdatingAvailability
              ? null
              : (value) => provider.setAvailability(value),
          activeThumbColor: Colors.green,
          activeTrackColor: Colors.green.withValues(alpha: 0.35),
        ),
      ],
    );
  }

  Widget _statusDot(bool isAvailable) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: isAvailable ? Colors.green : Colors.redAccent,
        shape: BoxShape.circle,
      ),
    );
  }
}

Widget _queueTab(String title, bool isSelected) {
  return AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    margin: const EdgeInsets.only(right: 10),
    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
    decoration: BoxDecoration(
      color: isSelected ? Colors.blue : Colors.grey.shade200,
      borderRadius: BorderRadius.circular(25),
    ),
    child: Text(
      title,
      style: TextStyle(
        color: isSelected ? Colors.white : Colors.grey.shade700,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

enum _QueueActionKind { startServing, cancel, markDone }

class _QueueCard extends StatefulWidget {
  final BarberQueueItem item;
  final Future<void> Function()? onStartServing;
  final Future<void> Function()? onMarkDone;
  final Future<void> Function()? onCancel;

  const _QueueCard({
    required this.item,
    this.onStartServing,
    this.onMarkDone,
    this.onCancel,
  });

  @override
  State<_QueueCard> createState() => _QueueCardState();
}

class _QueueCardState extends State<_QueueCard> {
  Timer? _timer;
  int _elapsedMinutes = 0;
  _QueueActionKind? _pendingAction;

  @override
  void initState() {
    super.initState();
    _updateElapsedTime();
    if (widget.item.status == BarberQueueStatus.serving) {
      _startTimer();
    }
  }

  @override
  void didUpdateWidget(_QueueCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.item.status == BarberQueueStatus.serving &&
        oldWidget.item.status != BarberQueueStatus.serving) {
      _startTimer();
    } else if (widget.item.status != BarberQueueStatus.serving) {
      _stopTimer();
    }
    _updateElapsedTime();
  }

  @override
  void dispose() {
    _stopTimer();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _updateElapsedTime();
        });
      }
    });
  }

  void _stopTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _updateElapsedTime() {
    if (widget.item.status == BarberQueueStatus.serving &&
        widget.item.startedAt != null) {
      final now = DateTime.now();
      final elapsed = now.difference(widget.item.startedAt!);
      _elapsedMinutes = elapsed.inMinutes;
    } else {
      _elapsedMinutes = 0;
    }
  }

  Future<void> _runAction(
    _QueueActionKind kind,
    Future<void> Function()? action,
  ) async {
    if (action == null) return;
    if (_pendingAction != null) return;
    setState(() => _pendingAction = kind);
    try {
      await action();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Action failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _pendingAction = null);
      }
    }
  }

  String _getTimeDisplay() {
    if (widget.item.status == BarberQueueStatus.serving) {
      if (_elapsedMinutes <= 0) {
        return "0 min";
      }
      return "$_elapsedMinutes min";
    } else if (widget.item.status == BarberQueueStatus.done) {
      if (widget.item.completedAt != null && widget.item.startedAt != null) {
        final actualMinutes =
            widget.item.completedAt!.difference(widget.item.startedAt!).inMinutes;
        if (actualMinutes <= 0) {
          return "1 min";
        }
        return "$actualMinutes min";
      }
      return "${widget.item.waitMinutes} min";
    } else if (widget.item.status == BarberQueueStatus.cancelled) {
      return "${widget.item.waitMinutes} min";
    } else {
      return "${widget.item.waitMinutes} min";
    }
  }

  Color _getTimeColor() {
    if (widget.item.status == BarberQueueStatus.serving) {
      if (_elapsedMinutes >= widget.item.waitMinutes) {
        return Colors.red;
      }
      return Colors.orange;
    }
    if (widget.item.status == BarberQueueStatus.cancelled) {
      return Colors.grey;
    }
    return Colors.orange;
  }

  @override
  Widget build(BuildContext context) {
    final statusColor = _statusColor(widget.item.status);
    final actions = _buildActions();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.98),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildAvatar(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.item.customerName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _scheduledLabel(),
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(
                _getTimeDisplay(),
                style: TextStyle(color: _getTimeColor(), fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            "${widget.item.service} • ৳${widget.item.price}",
            style: const TextStyle(color: Colors.black54, fontSize: 15),
          ),
          const SizedBox(height: 6),
          Text("Barber: ${widget.item.barberName}",
              style: const TextStyle(color: Colors.black54, fontSize: 14)),
          if (widget.item.note != null && widget.item.note!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.item.note!,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  _statusLabel(widget.item.status),
                  style: TextStyle(
                      color: statusColor, fontWeight: FontWeight.w600),
                ),
              ),
              if (actions.isNotEmpty) ...[
                const Spacer(),
                Row(
                  children: [
                    ...actions,
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActions() {
    if (widget.onStartServing != null && widget.onCancel != null) {
      final isBusy = _pendingAction != null;
      final isCanceling = _pendingAction == _QueueActionKind.cancel;
      final isStarting = _pendingAction == _QueueActionKind.startServing;
      return [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.redAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: const StadiumBorder(),
          ),
          onPressed: isBusy ? null : _confirmCancel,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: isCanceling
                ? Row(
                    key: const ValueKey('cancel-loading'),
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Cancel",
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  )
                : const Text(
                    "Cancel",
                    key: ValueKey('cancel-idle'),
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
          ),
        ),
        const SizedBox(width: 10),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.blueAccent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: const StadiumBorder(),
          ),
          onPressed: isBusy
              ? null
              : () => _runAction(
                    _QueueActionKind.startServing,
                    widget.onStartServing,
                  ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: isStarting
                ? Row(
                    key: const ValueKey('start-loading'),
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Start Serving",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('start-idle'),
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.play_arrow_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Start Serving",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
        ),
      ];
    }
    if (widget.onMarkDone != null) {
      final isBusy = _pendingAction != null;
      final isCompleting = _pendingAction == _QueueActionKind.markDone;
      return [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            elevation: 0,
            backgroundColor: Colors.green.shade600,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: const StadiumBorder(),
          ),
          onPressed: isBusy
              ? null
              : () => _runAction(_QueueActionKind.markDone, widget.onMarkDone),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            switchInCurve: Curves.easeOut,
            switchOutCurve: Curves.easeIn,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween<double>(begin: 0.98, end: 1).animate(animation),
                child: child,
              ),
            ),
            child: isCompleting
                ? Row(
                    key: const ValueKey('done-loading'),
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        "Mark Completed",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  )
                : Row(
                    key: const ValueKey('done-idle'),
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Icon(Icons.check_circle_rounded, size: 20),
                      SizedBox(width: 8),
                      Text(
                        "Mark Completed",
                        style: TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
        ),
      ];
    }
    return [];
  }

  Future<void> _confirmCancel() async {
    if (widget.onCancel == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel booking?'),
        content: const Text(
          'This will remove the customer from the queue. Are you sure?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Yes, cancel',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _runAction(_QueueActionKind.cancel, widget.onCancel);
    }
  }

  Widget _buildAvatar() {
    final avatarUrl = widget.item.customerAvatar;
    final initials = widget.item.customerName.isNotEmpty
        ? widget.item.customerName[0].toUpperCase()
        : '?';
    return CircleAvatar(
      radius: 22,
      backgroundColor: Colors.blue.shade100,
      backgroundImage:
          avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
      child: avatarUrl.isEmpty
          ? Text(
              initials,
              style: const TextStyle(
                color: Colors.blueAccent,
                fontWeight: FontWeight.w700,
              ),
            )
          : null,
    );
  }

  String _scheduledLabel() {
    if (widget.item.scheduledAt != null) {
      return DateFormat('MMM d • h:mm a').format(widget.item.scheduledAt!);
    }
    if (widget.item.slotLabel.isNotEmpty) return widget.item.slotLabel;
    return 'Schedule not set';
  }
}

String _statusLabel(BarberQueueStatus status) {
  switch (status) {
    case BarberQueueStatus.waiting:
      return 'Waiting';
    case BarberQueueStatus.serving:
      return 'Serving';
    case BarberQueueStatus.done:
      return 'Completed';
    case BarberQueueStatus.cancelled:
      return 'Cancelled';
  }
}

Color _statusColor(BarberQueueStatus status) {
  switch (status) {
    case BarberQueueStatus.waiting:
      return Colors.orange;
    case BarberQueueStatus.serving:
      return Colors.blue;
    case BarberQueueStatus.done:
      return Colors.green;
    case BarberQueueStatus.cancelled:
      return Colors.grey;
  }
}
