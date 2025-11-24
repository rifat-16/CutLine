import 'package:flutter/material.dart';

class SalonSetupStep {
  final String label;
  final IconData icon;
  final SalonSetupStepState state;

  const SalonSetupStep({
    required this.label,
    required this.icon,
    required this.state,
  });
}

enum SalonSetupStepState { done, current, pending }

class SalonSetupHero extends StatelessWidget {
  final List<SalonSetupStep> steps;

  const SalonSetupHero({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    final completed = steps.where((step) => step.state == SalonSetupStepState.done).length;
    final inProgress = steps.where((step) => step.state == SalonSetupStepState.current).length;
    final progress = (completed + (inProgress * 0.5)) / steps.length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.3),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.auto_awesome, color: Colors.white),
              ),
              const SizedBox(width: 12),
              Text('Step ${completed + 1} of ${steps.length}',
                  style: const TextStyle(color: Colors.white70)),
              const Spacer(),
              IconButton(
                onPressed: () {},
                icon: const Icon(Icons.help_outline, color: Colors.white),
                tooltip: 'Need help?',
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Let’s make your salon shine',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Complete the essentials so customers can discover you in CutLine.',
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: steps.map((step) => _SetupStepChip(step: step)).toList(),
          ),
        ],
      ),
    );
  }
}

class _SetupStepChip extends StatelessWidget {
  final SalonSetupStep step;

  const _SetupStepChip({required this.step});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;
    IconData iconData;
    switch (step.state) {
      case SalonSetupStepState.done:
        bg = Colors.white;
        fg = Colors.green;
        iconData = Icons.check_circle;
        break;
      case SalonSetupStepState.current:
        bg = Colors.white.withValues(alpha: 0.15);
        fg = Colors.white;
        iconData = step.icon;
        break;
      case SalonSetupStepState.pending:
        bg = Colors.white.withValues(alpha: 0.08);
        fg = Colors.white70;
        iconData = step.icon;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(iconData, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(step.label, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
