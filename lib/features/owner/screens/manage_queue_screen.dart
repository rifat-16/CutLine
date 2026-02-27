import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/manage_queue_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/queue_card.dart';
import 'package:cutline/shared/services/queue_serial_service.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class ManageQueueScreen extends StatefulWidget {
  const ManageQueueScreen({super.key});

  @override
  State<ManageQueueScreen> createState() => _ManageQueueScreenState();
}

class _ManageQueueScreenState extends State<ManageQueueScreen>
    with SingleTickerProviderStateMixin {
  String? _barberFilter;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final auth = context.read<AuthProvider>();
        final provider = ManageQueueProvider(authProvider: auth);
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<ManageQueueProvider>();
        const statuses = [
          OwnerQueueStatus.waiting,
          OwnerQueueStatus.serving,
          OwnerQueueStatus.done,
        ];
        return DefaultTabController(
          length: statuses.length,
          child: Scaffold(
            backgroundColor: const Color(0xFFF4F6FB),
            appBar: AppBar(
              title: const Text('Queue control center'),
              backgroundColor: Colors.white,
              elevation: 0,
              bottom: TabBar(
                isScrollable: true,
                tabs: statuses
                    .map((status) => Tab(text: _statusLabel(status)))
                    .toList(),
              ),
            ),
            floatingActionButton: FloatingActionButton.extended(
              onPressed: provider.isSavingManual
                  ? null
                  : () => _openManualEntrySheet(context, provider),
              icon: provider.isSavingManual
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1_outlined),
              label: Text(
                provider.isSavingManual ? 'Saving...' : 'Manual Add',
              ),
            ),
            body: Column(
              children: [
                if (provider.error != null && provider.error!.isNotEmpty)
                  Container(
                    width: double.infinity,
                    color: Colors.red.shade50,
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                    child: Text(
                      provider.error!,
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 13),
                    ),
                  ),
                _QueueToolbar(
                  barberFilter: _barberFilter,
                  barbers: _availableBarbers(provider.queue),
                  onBarberChanged: (value) => setState(
                      () => _barberFilter = value == 'All' ? null : value),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: provider.isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : TabBarView(
                          children: statuses.map((status) {
                            final entries =
                                _buildQueueEntries(provider.queue, status);
                            if (entries.isEmpty) {
                              return Center(
                                child: Text(
                                  'No ${_statusLabel(status).toLowerCase()} customers.',
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              );
                            }
                            return RefreshIndicator(
                              onRefresh: () => provider.load(),
                              child: ListView.builder(
                                padding:
                                    const EdgeInsets.fromLTRB(20, 12, 20, 80),
                                itemCount: entries.length,
                                itemBuilder: (_, index) {
                                  final entry = entries[index];
                                  if (entry.isHeader) {
                                    return _DateHeader(label: entry.label);
                                  }
                                  final item = entry.item!;
                                  return OwnerQueueCard(
                                    item: item,
                                    onStatusChange: (next) =>
                                        provider.updateStatus(item.id, next),
                                    onTap: item.isManual
                                        ? () => _openManualActionsSheet(
                                              context,
                                              provider,
                                              item,
                                            )
                                        : null,
                                  );
                                },
                              ),
                            );
                          }).toList(),
                        ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<_QueueEntry> _buildQueueEntries(
      List<OwnerQueueItem> queue, OwnerQueueStatus status) {
    Iterable<OwnerQueueItem> filtered =
        queue.where((item) => item.status == status);
    if (_barberFilter != null) {
      filtered = filtered.where((item) => item.barberName == _barberFilter);
    }

    final sorted = filtered.toList()
      ..sort((a, b) => _compareBySchedule(a, b, status));
    if (sorted.isEmpty) return const [];

    final entries = <_QueueEntry>[];
    DateTime? lastDay;
    for (final item in sorted) {
      final scheduledAt = item.scheduledAt;
      final day = scheduledAt == null
          ? null
          : DateTime(scheduledAt.year, scheduledAt.month, scheduledAt.day);
      if (lastDay != day) {
        entries.add(_QueueEntry.header(_dayLabel(day)));
        lastDay = day;
      }
      entries.add(_QueueEntry.item(item));
    }
    return entries;
  }

  int _compareBySchedule(
      OwnerQueueItem a, OwnerQueueItem b, OwnerQueueStatus status) {
    if (status != OwnerQueueStatus.done) {
      final barberCmp = _barberSortKey(a).compareTo(_barberSortKey(b));
      if (barberCmp != 0) return barberCmp;

      final aSerial = a.serialNo ?? 1 << 30;
      final bSerial = b.serialNo ?? 1 << 30;
      if (aSerial != bSerial) return aSerial.compareTo(bSerial);
    }

    final aDt = a.scheduledAt;
    final bDt = b.scheduledAt;

    // Scheduled items first; unscheduled last.
    if (aDt == null && bDt != null) return 1;
    if (aDt != null && bDt == null) return -1;

    // If both scheduled, sort by date+time.
    if (aDt != null && bDt != null) {
      final cmp = status == OwnerQueueStatus.done
          ? bDt.compareTo(aDt)
          : aDt.compareTo(bDt);
      if (cmp != 0) return cmp;
    }

    // Stable fallback: shorter wait first, then name.
    final waitCmp = a.waitMinutes.compareTo(b.waitMinutes);
    if (waitCmp != 0) return waitCmp;
    return a.customerName.compareTo(b.customerName);
  }

  String _barberSortKey(OwnerQueueItem item) {
    final serialKey = item.serialBarberKey?.trim().toLowerCase() ?? '';
    if (serialKey.isNotEmpty) return serialKey;
    return item.barberName.trim().toLowerCase();
  }

  Future<void> _openManualActionsSheet(
    BuildContext context,
    ManageQueueProvider provider,
    OwnerQueueItem item,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('Edit manual entry'),
                  onTap: () async {
                    Navigator.of(sheetContext).pop();
                    await _openManualEntrySheet(context, provider,
                        existing: item);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text(
                    'Delete manual entry',
                    style: TextStyle(color: Colors.red),
                  ),
                  onTap: () async {
                    final shouldDelete = await showDialog<bool>(
                      context: context,
                      builder: (dialogContext) {
                        return AlertDialog(
                          title: const Text('Delete entry?'),
                          content: const Text(
                              'This will remove this manual customer from queue and bookings.'),
                          actions: [
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () =>
                                  Navigator.of(dialogContext).pop(true),
                              child: const Text('Delete'),
                            ),
                          ],
                        );
                      },
                    );
                    if (shouldDelete != true) return;
                    final ok = await provider.deleteManualEntry(item.id);
                    if (!mounted) return;
                    Navigator.of(sheetContext).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          ok
                              ? 'Manual entry deleted.'
                              : (provider.error ?? 'Failed to delete entry.'),
                        ),
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

  Future<void> _openManualEntrySheet(
    BuildContext context,
    ManageQueueProvider provider, {
    OwnerQueueItem? existing,
  }) async {
    await provider.loadCatalog();
    if (!mounted) return;
    if (provider.barbers.isEmpty || provider.services.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add barbers and services first.')),
      );
      return;
    }

    final customerController =
        TextEditingController(text: existing?.customerName ?? '');
    String selectedBarberId =
        _resolveInitialBarberId(existing, provider.barbers);
    String selectedServiceId =
        _resolveInitialServiceId(existing, provider.services);
    final formKey = GlobalKey<FormState>();
    bool isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (sheetContext, setModalState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                16,
                20,
                MediaQuery.of(sheetContext).viewInsets.bottom + 20,
              ),
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      existing == null
                          ? 'Add Manual Customer'
                          : 'Edit Manual Entry',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: customerController,
                      textCapitalization: TextCapitalization.words,
                      decoration: const InputDecoration(
                        labelText: 'Customer name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if ((value ?? '').trim().isEmpty) {
                          return 'Customer name is required.';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedBarberId,
                      decoration: const InputDecoration(
                        labelText: 'Barber',
                        border: OutlineInputBorder(),
                      ),
                      items: provider.barbers
                          .map(
                            (barber) => DropdownMenuItem(
                              value: barber.id,
                              child: Text(barber.name),
                            ),
                          )
                          .toList(),
                      onChanged: isSubmitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setModalState(() => selectedBarberId = value);
                            },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: selectedServiceId,
                      decoration: const InputDecoration(
                        labelText: 'Service',
                        border: OutlineInputBorder(),
                      ),
                      items: provider.services
                          .map(
                            (service) => DropdownMenuItem(
                              value: service.id,
                              child: Text(
                                '${service.name} • ৳${service.price} • ${service.durationMinutes}m',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: isSubmitting
                          ? null
                          : (value) {
                              if (value == null) return;
                              setModalState(() => selectedServiceId = value);
                            },
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: isSubmitting
                            ? null
                            : () async {
                                if (!formKey.currentState!.validate()) return;
                                setModalState(() => isSubmitting = true);
                                final ok = existing == null
                                    ? await provider.createManualByOwner(
                                        customerName: customerController.text,
                                        barberId: selectedBarberId,
                                        serviceId: selectedServiceId,
                                      )
                                    : await provider.updateManualEntry(
                                        entryId: existing.id,
                                        customerName: customerController.text,
                                        barberId: selectedBarberId,
                                        serviceId: selectedServiceId,
                                      );
                                if (!mounted) return;
                                if (ok) {
                                  Navigator.of(sheetContext).pop();
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        existing == null
                                            ? 'Manual customer added.'
                                            : 'Manual entry updated.',
                                      ),
                                    ),
                                  );
                                  return;
                                }
                                setModalState(() => isSubmitting = false);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      provider.error ??
                                          'Could not save manual entry.',
                                    ),
                                  ),
                                );
                              },
                        child: isSubmitting
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    existing == null
                                        ? 'Adding...'
                                        : 'Saving...',
                                  ),
                                ],
                              )
                            : Text(existing == null ? 'Add to Queue' : 'Save'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _resolveInitialBarberId(
    OwnerQueueItem? existing,
    List<QueueBarberOption> barbers,
  ) {
    if (barbers.isEmpty) return '';
    if (existing == null) return barbers.first.id;
    if (existing.barberId.isNotEmpty) {
      final byId = barbers.where((b) => b.id == existing.barberId);
      if (byId.isNotEmpty) return byId.first.id;
    }
    final byName = barbers.where(
      (b) =>
          b.name.toLowerCase().trim() ==
          existing.barberName.toLowerCase().trim(),
    );
    if (byName.isNotEmpty) return byName.first.id;
    return barbers.first.id;
  }

  String _resolveInitialServiceId(
    OwnerQueueItem? existing,
    List<QueueServiceOption> services,
  ) {
    if (services.isEmpty) return '';
    if (existing == null) return services.first.id;
    if (existing.serviceId.isNotEmpty) {
      final byId = services.where((s) => s.id == existing.serviceId);
      if (byId.isNotEmpty) return byId.first.id;
    }
    final byName = services.where(
      (s) =>
          s.name.toLowerCase().trim() == existing.service.toLowerCase().trim(),
    );
    if (byName.isNotEmpty) return byName.first.id;
    return services.first.id;
  }

  String _dayLabel(DateTime? day) {
    if (day == null) return 'Unscheduled';
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final diffDays = day.difference(today).inDays;
    if (diffDays == 0) return 'Today';
    if (diffDays == 1) return 'Tomorrow';
    if (diffDays == -1) return 'Yesterday';
    return DateFormat('EEE, d MMM').format(day);
  }

  List<String> _availableBarbers(List<OwnerQueueItem> queue) {
    final barbers = queue.map((item) => item.barberName).toSet().toList()
      ..sort();
    return ['All', ...barbers];
  }

  String _statusLabel(OwnerQueueStatus status) {
    switch (status) {
      case OwnerQueueStatus.waiting:
        return 'Waiting';
      case OwnerQueueStatus.arrived:
        return 'Arrived';
      case OwnerQueueStatus.serving:
        return 'Serving';
      case OwnerQueueStatus.done:
        return 'Completed';
      case OwnerQueueStatus.noShow:
        return 'No Show';
    }
  }
}

class _QueueEntry {
  final bool isHeader;
  final String label;
  final OwnerQueueItem? item;

  const _QueueEntry._({
    required this.isHeader,
    required this.label,
    required this.item,
  });

  factory _QueueEntry.header(String label) =>
      _QueueEntry._(isHeader: true, label: label, item: null);

  factory _QueueEntry.item(OwnerQueueItem item) =>
      _QueueEntry._(isHeader: false, label: '', item: item);
}

class _DateHeader extends StatelessWidget {
  final String label;

  const _DateHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: Colors.black54,
        ),
      ),
    );
  }
}

class _QueueToolbar extends StatelessWidget {
  final String? barberFilter;
  final List<String> barbers;
  final ValueChanged<String?> onBarberChanged;

  const _QueueToolbar({
    required this.barberFilter,
    required this.barbers,
    required this.onBarberChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
      child: Row(
        children: [
          const Text('Filter barber',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          const SizedBox(width: 12),
          Expanded(
            child: InputDecorator(
              decoration: InputDecoration(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: barberFilter ?? 'All',
                  isExpanded: true,
                  items: barbers
                      .map((barber) => DropdownMenuItem(
                            value: barber,
                            child: Text(barber),
                          ))
                      .toList(),
                  onChanged: onBarberChanged,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
