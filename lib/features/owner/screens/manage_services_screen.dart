import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/combo_card.dart';
import 'package:cutline/features/owner/widgets/combo_editor_sheet.dart';
import 'package:cutline/features/owner/widgets/service_card.dart';
import 'package:cutline/features/owner/widgets/service_editor_sheet.dart';
import 'package:flutter/material.dart';

class ManageServicesScreen extends StatefulWidget {
  const ManageServicesScreen({super.key});

  @override
  State<ManageServicesScreen> createState() => _ManageServicesScreenState();
}

class _ManageServicesScreenState extends State<ManageServicesScreen>
    with SingleTickerProviderStateMixin {
  late List<OwnerServiceInfo> _services;
  late List<OwnerComboInfo> _combos;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _services = List.of(kOwnerDefaultServices);
    _combos = List.of(kOwnerDefaultCombos);
    _tabController = TabController(length: 2, vsync: this)..addListener(_onTabChange);
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
        onPressed: isServiceTab ? _addService : _addCombo,
        backgroundColor: fabColor,
        foregroundColor: Colors.white,
        icon: Icon(fabIcon),
        label: Text(fabLabel),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        extendedPadding:
            const EdgeInsets.symmetric(horizontal: 22, vertical: 0),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildServicesTab(),
          _buildComboTab(),
        ],
      ),
    );
  }

  Widget _buildServicesTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        const Text(
          'Update your menu, pricing and duration to keep the queue precise.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        if (_services.isEmpty)
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
        ..._services.asMap().entries.map((entry) {
          final index = entry.key;
          final service = entry.value;
          return OwnerServiceCard(
            service: service,
            onEdit: () => _editService(index),
            onDelete: () => _confirmDelete(index),
          );
        }),
      ],
    );
  }

  Widget _buildComboTab() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      children: [
        const Text(
          'Bundle hero services into high-converting combo offers.',
          style: TextStyle(color: Colors.black54),
        ),
        const SizedBox(height: 16),
        if (_combos.isEmpty)
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
        ..._combos.asMap().entries.map((entry) {
          final index = entry.key;
          final combo = entry.value;
          return OwnerComboCard(
            combo: combo,
            onEdit: () => _editCombo(index),
            onDelete: () => _confirmComboDelete(index),
          );
        }),
      ],
    );
  }

  void _deleteService(int index) {
    setState(() => _services.removeAt(index));
  }

  Future<void> _confirmDelete(int index) async {
    final service = _services[index];
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
      _deleteService(index);
    }
  }

  Future<void> _addService() async {
    final result = await showOwnerServiceEditorSheet(context: context);
    if (result != null) {
      setState(() => _services.add(result));
    }
  }

  Future<void> _editService(int index) async {
    final result = await showOwnerServiceEditorSheet(
      context: context,
      initial: _services[index],
    );
    if (result != null) {
      setState(() => _services[index] = result);
    }
  }

  void _deleteCombo(int index) {
    setState(() => _combos.removeAt(index));
  }

  Future<void> _confirmComboDelete(int index) async {
    final combo = _combos[index];
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove combo offer?'),
        content: Text(
            '“${combo.name}” will no longer be visible to customers. Remove it?'),
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
      _deleteCombo(index);
    }
  }

  Future<void> _addCombo() async {
    final result = await showOwnerComboEditorSheet(context: context);
    if (result != null) {
      setState(() => _combos.add(result));
    }
  }

  Future<void> _editCombo(int index) async {
    final result = await showOwnerComboEditorSheet(
      context: context,
      initial: _combos[index],
    );
    if (result != null) {
      setState(() => _combos[index] = result);
    }
  }
}
