import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/manage_services_provider.dart';
import 'package:cutline/features/owner/widgets/combo_card.dart';
import 'package:cutline/features/owner/widgets/combo_editor_sheet.dart';
import 'package:cutline/features/owner/widgets/service_card.dart';
import 'package:cutline/features/owner/widgets/service_editor_sheet.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({super.key});

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(_onTabChange);
  }

  void _onTabChange() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChange)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final auth = context.read<AuthProvider>();
        final provider = ManageServicesProvider(authProvider: auth);
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<ManageServicesProvider>();
        final isServiceTab = _tabController.index == 0;
        final Color fabColor =
            isServiceTab ? const Color(0xFF2A6DEA) : const Color(0xFFFF7A45);
        final IconData fabIcon =
            isServiceTab ? Icons.add_rounded : Icons.auto_awesome_rounded;
        final String fabLabel =
            isServiceTab ? 'Add Service' : 'Add Combo Offer';

        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          appBar: AppBar(
            title: const Text('Manage services'),
            backgroundColor: Colors.white,
            elevation: 0,
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                alignment: Alignment.centerLeft,
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  indicatorColor: const Color(0xFF2A6DEA),
                  indicatorWeight: 3,
                  labelColor: const Color(0xFF2A6DEA),
                  unselectedLabelColor: Colors.black45,
                  labelStyle: const TextStyle(fontWeight: FontWeight.w600),
                  tabs: const [
                    Tab(text: 'All Services'),
                    Tab(text: 'Combo Offers'),
                  ],
                ),
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: isServiceTab
                ? () => _addService(provider)
                : () => _addCombo(provider),
            backgroundColor: fabColor,
            foregroundColor: Colors.white,
            icon: Icon(fabIcon),
            label: Text(fabLabel),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            extendedPadding:
                const EdgeInsets.symmetric(horizontal: 22, vertical: 0),
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildServicesTab(provider),
                    _buildComboTab(provider),
                  ],
                ),
        );
      },
    );
  }

  Widget _buildServicesTab(ManageServicesProvider provider) {
    final services = provider.services;
    return RefreshIndicator(
      onRefresh: () => provider.load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          const Text(
            'Update your menu, pricing and duration to keep the queue precise.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          if (provider.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(provider.error!,
                  style: const TextStyle(color: Colors.red)),
            ),
          if (services.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'No services yet. Add your first service to get started.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ...services.asMap().entries.map((entry) {
            final index = entry.key;
            final service = entry.value;
            return OwnerServiceCard(
              service: service,
              onEdit: () => _editService(provider, index),
              onDelete: () => _confirmDelete(provider, index),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildComboTab(ManageServicesProvider provider) {
    final combos = provider.combos;
    return RefreshIndicator(
      onRefresh: () => provider.load(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
        children: [
          const Text(
            'Bundle hero services into high-converting combo offers.',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 16),
          if (provider.error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(provider.error!,
                  style: const TextStyle(color: Colors.red)),
            ),
          if (combos.isEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'No combo offers yet. Add one to promote upsells.',
                style: TextStyle(color: Colors.black54),
              ),
            ),
          ...combos.asMap().entries.map((entry) {
            final index = entry.key;
            final combo = entry.value;
            return OwnerComboCard(
              combo: combo,
              onEdit: () => _editCombo(provider, index),
              onDelete: () => _confirmComboDelete(provider, index),
            );
          }),
        ],
      ),
    );
  }

  Future<void> _addService(ManageServicesProvider provider) async {
    final result = await showOwnerServiceEditorSheet(context: context);
    if (result != null) {
      provider.addService(result);
      await provider.save();
    }
  }

  Future<void> _editService(ManageServicesProvider provider, int index) async {
    final result = await showOwnerServiceEditorSheet(
      context: context,
      initial: provider.services[index],
    );
    if (result != null) {
      provider.updateService(index, result);
      await provider.save();
    }
  }

  Future<void> _confirmDelete(
      ManageServicesProvider provider, int index) async {
    final service = provider.services[index];
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove service?'),
        content: Text(
            '“${service.name}” will be removed from your service list. Proceed?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      provider.removeService(index);
      await provider.save();
    }
  }

  Future<void> _addCombo(ManageServicesProvider provider) async {
    final result = await showOwnerComboEditorSheet(context: context);
    if (result != null) {
      provider.addCombo(result);
      await provider.save();
    }
  }

  Future<void> _editCombo(ManageServicesProvider provider, int index) async {
    final result = await showOwnerComboEditorSheet(
      context: context,
      initial: provider.combos[index],
    );
    if (result != null) {
      provider.updateCombo(index, result);
      await provider.save();
    }
  }

  Future<void> _confirmComboDelete(
      ManageServicesProvider provider, int index) async {
    final combo = provider.combos[index];
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove combo?'),
        content: Text(
            '“${combo.name}” will be removed from your combo list. Proceed?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (shouldDelete == true) {
      provider.removeCombo(index);
      await provider.save();
    }
  }
}
