import 'package:flutter/material.dart';
import '../../widgets/empty_state.dart';

class ManageQueueScreen extends StatelessWidget {
  const ManageQueueScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Queue'),
      ),
      body: const EmptyState(
        icon: Icons.queue_outlined,
        title: 'Queue Management',
        message: 'Select a barber to view their queue',
      ),
    );
  }
}
