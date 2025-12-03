import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/working_hours_provider.dart';
import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final auth = context.read<AuthProvider>();
        final provider = WorkingHoursProvider(authProvider: auth);
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<WorkingHoursProvider>();
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          appBar: AppBar(
            title: const Text('Working hours'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                  children: [
                    const Text(
                      'Toggle the days you are open and fine tune the opening & closing slots.',
                      style: TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    if (provider.error != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          provider.error!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ...provider.days.asMap().entries.map((entry) {
                      final index = entry.key;
                      final day = entry.value;
                      return _WorkingDayRow(
                        day: day,
                        onToggle: (value) => provider.updateDay(
                            index, day.copyWith(isOpen: value)),
                        onPickTime: (isOpen) =>
                            _pickTime(provider, index, isOpen),
                      );
                    }),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: provider.isLoading || !provider.hasChanges
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await provider.save();
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(
                                    content: Text('Schedule saved'),
                                    backgroundColor: Colors.green),
                              );
                            },
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18)),
                        backgroundColor: provider.hasChanges
                            ? const Color(0xFF2563EB)
                            : Colors.grey.shade200,
                        foregroundColor:
                            provider.hasChanges ? Colors.white : Colors.black54,
                      ),
                      child: Text(
                        provider.isLoading
                            ? 'Saving...'
                            : provider.hasChanges
                                ? 'Save schedule'
                                : 'No changes',
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  Future<void> _pickTime(
      WorkingHoursProvider provider, int index, bool isOpenTime) async {
    final current = provider.days[index];
    final initial = isOpenTime ? current.openTime : current.closeTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      final updated = current.copyWith(
        openTime: isOpenTime ? picked : current.openTime,
        closeTime: isOpenTime ? current.closeTime : picked,
      );
      provider.updateDay(index, updated);
    }
  }
}

class _WorkingDayRow extends StatelessWidget {
  final OwnerWorkingDay day;
  final ValueChanged<bool> onToggle;
  final ValueChanged<bool> onPickTime;

  const _WorkingDayRow({
    required this.day,
    required this.onToggle,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final bool isClosed = !day.isOpen;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isClosed ? Colors.grey.shade200 : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  day.day,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isClosed ? Colors.black38 : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                if (isClosed)
                  Row(
                    children: const [
                      Icon(Icons.close, color: Colors.redAccent, size: 18),
                      SizedBox(width: 6),
                      Text('Closed', style: TextStyle(color: Colors.black54)),
                    ],
                  )
                else
                  Row(
                    children: [
                      _TimeChip(
                        label: 'Open',
                        value: day.openTime.format(context),
                        onTap: () => onPickTime(true),
                      ),
                      const SizedBox(width: 12),
                      _TimeChip(
                        label: 'Close',
                        value: day.closeTime.format(context),
                        onTap: () => onPickTime(false),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Switch(
            value: day.isOpen,
            onChanged: onToggle,
          )
        ],
      ),
    );
  }
}

class _TimeChip extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _TimeChip(
      {required this.label, required this.value, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11, color: Colors.black54, letterSpacing: 0.6)),
            const SizedBox(height: 4),
            Text(value,
                style:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
