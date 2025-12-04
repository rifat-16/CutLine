import 'package:flutter/material.dart';

class OwnerMiniStatData {
  final String label;
  final String value;
  final String caption;
  final Color color;

  const OwnerMiniStatData({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
  });
}

class OwnerMiniStatsRow extends StatelessWidget {
  final List<OwnerMiniStatData> stats;

  const OwnerMiniStatsRow({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < stats.length; i++) {
      children.add(Expanded(child: _MiniStatCard(stat: stats[i])));
      if (i != stats.length - 1) {
        children.add(const SizedBox(width: 12));
      }
    }

    return Row(children: children);
  }
}

class _MiniStatCard extends StatelessWidget {
  final OwnerMiniStatData stat;

  const _MiniStatCard({required this.stat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      constraints: const BoxConstraints(minHeight: 110),
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
          Text(
            stat.label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.blueGrey,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
          const SizedBox(height: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: stat.color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stat.caption,
                style: const TextStyle(color: Colors.blueGrey),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
