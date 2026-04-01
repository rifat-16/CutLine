import 'package:flutter/material.dart';

import 'package:cutline/features/admin/models/admin_models.dart';
import 'package:cutline/features/admin/services/admin_action_service.dart';
import 'package:cutline/features/admin/services/admin_service.dart';

class SupportInboxTab extends StatefulWidget {
  const SupportInboxTab({
    super.key,
    required this.adminUid,
  });

  final String adminUid;

  @override
  State<SupportInboxTab> createState() => _SupportInboxTabState();
}

class _SupportInboxTabState extends State<SupportInboxTab> {
  final AdminService _service = AdminService();
  final AdminActionService _actionService = AdminActionService();
  String _status = 'open';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final item in const [
                'open',
                'in_progress',
                'resolved',
                'closed',
                'all'
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(item),
                    selected: _status == item,
                    onSelected: (_) => setState(() => _status = item),
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: StreamBuilder<List<AdminSupportRequest>>(
            stream: _service.watchSupportRequests(status: _status),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              final requests = snapshot.data ?? const <AdminSupportRequest>[];
              if (requests.isEmpty) {
                return const Center(child: Text('No support requests found.'));
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: requests.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final item = requests[index];
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.subject.isEmpty
                                          ? 'Untitled request'
                                          : item.subject,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      item.ownerEmail.isEmpty
                                          ? item.contact
                                          : '${item.ownerEmail} • ${item.contact}',
                                      style: const TextStyle(
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _StatusBadge(label: item.status),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.message,
                            style: const TextStyle(
                              height: 1.45,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              _MetaPill(
                                  label: 'Category', value: item.category),
                              _MetaPill(
                                label: 'Created',
                                value: _formatDateTime(item.createdAt),
                              ),
                              if (item.assignedAdminUid.isNotEmpty)
                                _MetaPill(
                                  label: 'Assigned',
                                  value: item.assignedAdminUid,
                                ),
                            ],
                          ),
                          if (item.adminNote.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                'Admin note: ${item.adminNote}',
                                style: const TextStyle(
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ],
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _assignToMe(item),
                                  child: const Text('Assign To Me'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed: () => _openUpdateSheet(item),
                                  child: const Text('Update'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _assignToMe(AdminSupportRequest request) async {
    try {
      await _actionService.updateSupportRequest(
        requestId: request.id,
        status: request.status,
        adminNote: request.adminNote,
        assignedAdminUid: widget.adminUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support request assigned to you.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to assign request: $e')),
      );
    }
  }

  Future<void> _openUpdateSheet(AdminSupportRequest request) async {
    final noteController = TextEditingController(text: request.adminNote);
    String selectedStatus = request.status;
    final result = await showModalBottomSheet<_SupportUpdateFormResult>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Update Support Request',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    initialValue: selectedStatus,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('open')),
                      DropdownMenuItem(
                        value: 'in_progress',
                        child: Text('in_progress'),
                      ),
                      DropdownMenuItem(
                          value: 'resolved', child: Text('resolved')),
                      DropdownMenuItem(value: 'closed', child: Text('closed')),
                    ],
                    onChanged: (value) {
                      if (value == null) return;
                      setModalState(() => selectedStatus = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Admin note',
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).pop(
                          _SupportUpdateFormResult(
                            status: selectedStatus,
                            note: noteController.text.trim(),
                          ),
                        );
                      },
                      child: const Text('Save'),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
    if (!mounted || result == null) return;
    try {
      await _actionService.updateSupportRequest(
        requestId: request.id,
        status: result.status,
        adminNote: result.note,
        assignedAdminUid: request.assignedAdminUid.isNotEmpty
            ? request.assignedAdminUid
            : widget.adminUid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Support request updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update request: $e')),
      );
    }
  }
}

class _SupportUpdateFormResult {
  const _SupportUpdateFormResult({
    required this.status,
    required this.note,
  });

  final String status;
  final String note;
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final bg = switch (label) {
      'resolved' => const Color(0xFFDCFCE7),
      'closed' => const Color(0xFFE2E8F0),
      'in_progress' => const Color(0xFFDBEAFE),
      _ => const Color(0xFFFEF3C7),
    };
    final fg = switch (label) {
      'resolved' => const Color(0xFF166534),
      'closed' => const Color(0xFF334155),
      'in_progress' => const Color(0xFF1D4ED8),
      _ => const Color(0xFF854D0E),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: fg,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE7EEEB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: ${value.isEmpty ? 'n/a' : value}',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
    );
  }
}

String _formatDateTime(DateTime? value) {
  if (value == null) return 'Unknown';
  final mm = value.month.toString().padLeft(2, '0');
  final dd = value.day.toString().padLeft(2, '0');
  final hh = value.hour.toString().padLeft(2, '0');
  final min = value.minute.toString().padLeft(2, '0');
  return '${value.year}-$mm-$dd $hh:$min';
}
