import 'package:cutline/owner/utils/constants.dart';
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
          return _ServiceCard(
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
          return _ComboCard(
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
    final result = await _openServiceEditor();
    if (result != null) {
      setState(() => _services.add(result));
    }
  }

  Future<void> _editService(int index) async {
    final result = await _openServiceEditor(service: _services[index]);
    if (result != null) {
      setState(() => _services[index] = result);
    }
  }

  Future<OwnerServiceInfo?> _openServiceEditor({OwnerServiceInfo? service}) {
    final nameController = TextEditingController(text: service?.name ?? '');
    final priceController =
        TextEditingController(text: service?.price.toString() ?? '');
    final durationController =
        TextEditingController(text: service?.durationMinutes.toString() ?? '');

    return showModalBottomSheet<OwnerServiceInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                service == null ? 'Add new service' : 'Edit service',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Service name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '৳ Price',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: durationController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Duration (min)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SheetActionButton(
                label: service == null ? 'Add service' : 'Save changes',
                gradient: const LinearGradient(
                  colors: [Color(0xFFEEE9FF), Color(0xFFDCCBFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                textColor: const Color(0xFF5E34D2),
                onTap: () {
                  final price = int.tryParse(priceController.text) ?? 0;
                  final duration = int.tryParse(durationController.text) ?? 0;
                  if (nameController.text.trim().isEmpty ||
                      price <= 0 ||
                      duration <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Please enter valid name, price and duration')));
                    return;
                  }
                  Navigator.pop(
                    context,
                    service?.copyWith(
                          name: nameController.text.trim(),
                          price: price,
                          durationMinutes: duration,
                        ) ??
                        OwnerServiceInfo(
                            name: nameController.text.trim(),
                            price: price,
                            durationMinutes: duration),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
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
    final result = await _openComboEditor();
    if (result != null) {
      setState(() => _combos.add(result));
    }
  }

  Future<void> _editCombo(int index) async {
    final result = await _openComboEditor(combo: _combos[index]);
    if (result != null) {
      setState(() => _combos[index] = result);
    }
  }

  Future<OwnerComboInfo?> _openComboEditor({OwnerComboInfo? combo}) {
    final nameController = TextEditingController(text: combo?.name ?? '');
    final servicesController =
        TextEditingController(text: combo?.services ?? '');
    final highlightController =
        TextEditingController(text: combo?.highlight ?? '');
    final priceController =
        TextEditingController(text: combo?.price.toString() ?? '');
    final emojiController =
        TextEditingController(text: combo?.emoji ?? '✨');

    return showModalBottomSheet<OwnerComboInfo>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        final bottom = MediaQuery.of(context).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, bottom + 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                combo == null ? 'Add combo offer' : 'Edit combo offer',
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Combo name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: servicesController,
                decoration: const InputDecoration(
                  labelText: 'Included services',
                  hintText: 'e.g. Haircut + Beard + Facial',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: highlightController,
                decoration: const InputDecoration(
                  labelText: 'Offer highlight',
                  hintText: 'e.g. Save 20% this week',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: priceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: '৳ Price',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: emojiController,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Emoji',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _SheetActionButton(
                label: combo == null ? 'Add combo' : 'Save changes',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFD0A8), Color(0xFFFF9EB0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                textColor: const Color(0xFFB7313F),
                onTap: () {
                  final price = int.tryParse(priceController.text) ?? 0;
                  if (nameController.text.trim().isEmpty ||
                      servicesController.text.trim().isEmpty ||
                      highlightController.text.trim().isEmpty ||
                      price <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            'Please fill name, services, highlight and a valid price')));
                    return;
                  }
                  Navigator.pop(
                    context,
                    combo?.copyWith(
                          name: nameController.text.trim(),
                          services: servicesController.text.trim(),
                          highlight: highlightController.text.trim(),
                          price: price,
                          emoji: emojiController.text.trim().isEmpty
                              ? '✨'
                              : emojiController.text.trim(),
                        ) ??
                        OwnerComboInfo(
                          name: nameController.text.trim(),
                          services: servicesController.text.trim(),
                          highlight: highlightController.text.trim(),
                          price: price,
                          emoji: emojiController.text.trim().isEmpty
                              ? '✨'
                              : emojiController.text.trim(),
                        ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final OwnerServiceInfo service;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ServiceCard({
    required this.service,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 48,
            width: 48,
            decoration: const BoxDecoration(
              color: Color(0xFFE8F0FF),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.content_cut, color: Color(0xFF2A6DEA)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        service.name,
                        style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF0F4FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '৳${service.price}',
                        style: const TextStyle(
                            color: Color(0xFF2A6DEA),
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Duration: ${service.durationMinutes} min',
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    TextButton.icon(
                      onPressed: onEdit,
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2C4C8E),
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComboCard extends StatelessWidget {
  final OwnerComboInfo combo;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ComboCard({
    required this.combo,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFFFFA958), Color(0xFFFF5B7E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3FFF6B6B),
            blurRadius: 24,
            offset: Offset(0, 16),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                combo.emoji,
                style: const TextStyle(fontSize: 26),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      combo.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      combo.services,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '৳${combo.price}',
                  style: const TextStyle(
                    color: Color(0xFFFF5B7E),
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            combo.highlight,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton(
                onPressed: onEdit,
                style: ElevatedButton.styleFrom(
                  elevation: 0,
                  backgroundColor: Colors.white,
                  foregroundColor: const Color(0xFFFF5B7E),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                child: const Text('Edit combo'),
              ),
              const SizedBox(width: 10),
              TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline,
                  color: Colors.white,
                  size: 18,
                ),
                label: const Text(
                  'Remove',
                  style: TextStyle(color: Colors.white),
                ),
                style: TextButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SheetActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final Gradient gradient;
  final Color textColor;

  const _SheetActionButton({
    required this.label,
    required this.onTap,
    required this.gradient,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A1F1F1F),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
