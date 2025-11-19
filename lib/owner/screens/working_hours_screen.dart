import 'package:cutline/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class WorkingHoursScreen extends StatefulWidget {
  const WorkingHoursScreen({super.key});

  @override
  State<WorkingHoursScreen> createState() => _WorkingHoursScreenState();
}

class _WorkingHoursScreenState extends State<WorkingHoursScreen> {
  late List<OwnerWorkingDay> _days;

  @override
  void initState() {
    super.initState();
    _days = List.of(kOwnerDefaultWorkingDays);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        title: const Text('Working hours'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
        children: [
          const Text(
            'Toggle the days you are open and fine tune the opening & closing slots.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          ..._days.asMap().entries.map((entry) {
            final index = entry.key;
            final day = entry.value;
            return _WorkingDayRow(
              day: day,
              onToggle: (value) => _toggleDay(index, value),
              onPickTime: (isOpen) => _pickTime(index, isOpen),
            );
          }),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18)),
            ),
            child: const Text('Save schedule'),
          ),
        ],
      ),
    );
  }

  void _toggleDay(int index, bool isOpen) {
    setState(() {
      _days[index] = _days[index].copyWith(isOpen: isOpen);
    });
  }

  Future<void> _pickTime(int index, bool isOpenTime) async {
    final current = _days[index];
    final initial = isOpenTime ? current.openTime : current.closeTime;
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      setState(() {
        _days[index] = _days[index].copyWith(
          openTime: isOpenTime ? picked : current.openTime,
          closeTime: isOpenTime ? current.closeTime : picked,
        );
      });
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
