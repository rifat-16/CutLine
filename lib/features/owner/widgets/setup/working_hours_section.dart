import 'package:flutter/material.dart';

class WorkingHoursSection extends StatelessWidget {
  final Map<String, Map<String, dynamic>> workingHours;
  final void Function(String day, bool open) onToggleOpen;
  final Future<void> Function(String day, bool isOpenTime) onPickTime;

  const WorkingHoursSection({
    super.key,
    required this.workingHours,
    required this.onToggleOpen,
    required this.onPickTime,
  });

  @override
  Widget build(BuildContext context) {
    final entries = workingHours.entries.toList();
    return Column(
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: entries
              .map((entry) => _DayChip(
                    day: entry.key,
                    isOpen: entry.value['open'] as bool,
                  ))
              .toList(),
        ),
        const SizedBox(height: 16),
        ...entries.map((entry) {
          final day = entry.key;
          final data = entry.value;
          final isOpen = data['open'] as bool;
          final openTime = data['openTime'] as TimeOfDay;
          final closeTime = data['closeTime'] as TimeOfDay;

          return AnimatedContainer(
            key: ValueKey(day),
            duration: const Duration(milliseconds: 250),
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: isOpen
                  ? const LinearGradient(
                      colors: [Color(0xFFE8F7EE), Color(0xFFF4FBF7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isOpen ? null : Colors.grey.shade100,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isOpen
                    ? Colors.green.withValues(alpha: 0.2)
                    : Colors.grey.withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(day,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16)),
                    const Spacer(),
                    _StatusBadge(isOpen: isOpen),
                    const SizedBox(width: 10),
                    Switch(
                      value: isOpen,
                      onChanged: (value) => onToggleOpen(day, value),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: isOpen
                      ? Row(
                          key: ValueKey('$day-open'),
                          children: [
                            Expanded(
                              child: _TimePickerTile(
                                label: 'Opens',
                                time: openTime,
                                onPick: () => onPickTime(day, true),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _TimePickerTile(
                                label: 'Closes',
                                time: closeTime,
                                onPick: () => onPickTime(day, false),
                              ),
                            ),
                          ],
                        )
                      : Padding(
                          key: ValueKey('$day-closed'),
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            'Marked as closed',
                            style: TextStyle(
                                color: Colors.grey.shade500,
                                fontStyle: FontStyle.italic),
                          ),
                        ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _DayChip extends StatelessWidget {
  final String day;
  final bool isOpen;

  const _DayChip({required this.day, required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: isOpen ? Colors.green.withValues(alpha: 0.15) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOpen ? Icons.check_circle : Icons.pause_circle_filled,
            size: 16,
            color: isOpen ? Colors.green : Colors.grey,
          ),
          const SizedBox(width: 6),
          Text(
            day.substring(0, 3),
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: isOpen ? Colors.green.shade900 : Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final bool isOpen;

  const _StatusBadge({required this.isOpen});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isOpen
            ? Colors.green.withValues(alpha: 0.15)
            : Colors.red.withValues(alpha: 0.12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isOpen ? Icons.check : Icons.close,
              size: 14, color: isOpen ? Colors.green : Colors.redAccent),
          const SizedBox(width: 4),
          Text(
            isOpen ? 'Open' : 'Closed',
            style: TextStyle(
              color: isOpen ? Colors.green.shade900 : Colors.redAccent,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _TimePickerTile extends StatelessWidget {
  final String label;
  final TimeOfDay time;
  final VoidCallback onPick;

  const _TimePickerTile({
    required this.label,
    required this.time,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final formattedHour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final formattedMinute = time.minute.toString().padLeft(2, '0');
    final suffix = time.period == DayPeriod.am ? 'AM' : 'PM';

    return InkWell(
      onTap: onPick,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$formattedHour:$formattedMinute $suffix',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Spacer(),
            const Icon(Icons.chevron_right, color: Colors.black38),
          ],
        ),
      ),
    );
  }
}
