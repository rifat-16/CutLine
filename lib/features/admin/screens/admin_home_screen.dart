import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:cutline/features/admin/providers/admin_auth_provider.dart';
import 'package:cutline/features/admin/screens/admin_dashboard_tab.dart';
import 'package:cutline/features/admin/screens/directory_tab.dart';
import 'package:cutline/features/admin/screens/pending_salons_tab.dart';
import 'package:cutline/features/admin/screens/platform_fee_payments_tab.dart';

class AdminHomeScreen extends StatefulWidget {
  const AdminHomeScreen({super.key});

  @override
  State<AdminHomeScreen> createState() => _AdminHomeScreenState();
}

class _AdminHomeScreenState extends State<AdminHomeScreen> {
  int _index = 0;

  static const _titles = [
    'Overview',
    'Payments',
    'Pending Salons',
    'All Salons',
  ];

  static const _subtitles = [
    'Track verification, restrictions, and platform dues.',
    'Approve or reject owner platform fee submissions.',
    'Approve or reject new salon registrations.',
    'Monitor every salon and open its finance status.',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final pages = [
      AdminDashboardTab(onNavigate: _onNavigate),
      const PlatformFeePaymentsTab(),
      const PendingSalonsTab(),
      const DirectoryTab(),
    ];

    return Scaffold(
      extendBody: true,
      appBar: AppBar(
        toolbarHeight: 82,
        titleSpacing: 18,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_titles[_index]),
            const SizedBox(height: 4),
            Text(
              _subtitles[_index],
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF60716B),
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.96),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFDDE6E0)),
              ),
              child: IconButton(
                tooltip: 'Sign out',
                onPressed: () => context.read<AdminAuthProvider>().signOut(),
                icon: const Icon(Icons.logout_rounded),
              ),
            ),
          ),
        ],
      ),
      body: IndexedStack(
        index: _index,
        children: pages,
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 0, 16, 14),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.96),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: const Color(0xFFDDE6E0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x160B1F19),
                blurRadius: 28,
                offset: Offset(0, 12),
              ),
            ],
          ),
          child: NavigationBar(
            selectedIndex: _index,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.dashboard_outlined),
                selectedIcon: Icon(Icons.dashboard_rounded),
                label: 'Dashboard',
              ),
              NavigationDestination(
                icon: Icon(Icons.payments_outlined),
                selectedIcon: Icon(Icons.payments_rounded),
                label: 'Payments',
              ),
              NavigationDestination(
                icon: Icon(Icons.fact_check_outlined),
                selectedIcon: Icon(Icons.fact_check_rounded),
                label: 'Pending',
              ),
              NavigationDestination(
                icon: Icon(Icons.storefront_outlined),
                selectedIcon: Icon(Icons.storefront_rounded),
                label: 'Salons',
              ),
            ],
            onDestinationSelected: (value) => setState(() => _index = value),
          ),
        ),
      ),
    );
  }

  void _onNavigate(int index) {
    setState(() => _index = index);
  }
}
