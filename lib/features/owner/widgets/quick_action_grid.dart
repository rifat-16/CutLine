import 'package:flutter/material.dart';

class OwnerQuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final int? badgeCount;

  const OwnerQuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.badgeCount,
  });
}

class OwnerQuickActionGrid extends StatelessWidget {
  final List<OwnerQuickAction> actions;

  const OwnerQuickActionGrid({super.key, required this.actions});

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
      itemBuilder: (_, index) => _OwnerQuickActionCard(action: actions[index]),
    );
  }
}

class _OwnerQuickActionCard extends StatelessWidget {
  final OwnerQuickAction action;

  const _OwnerQuickActionCard({required this.action});

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
              border:
                  Border.all(color: action.color.withValues(alpha: 0.18)),
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
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
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
            child: _OwnerActionBadge(count: action.badgeCount!),
          ),
      ],
    );
  }
}

class _OwnerActionBadge extends StatelessWidget {
  final int count;

  const _OwnerActionBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final display = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.redAccent,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 10,
            offset: Offset(0, 2),
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
