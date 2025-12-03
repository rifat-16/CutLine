import 'package:cutline/features/owner/utils/constants.dart';
import 'package:flutter/material.dart';

class ServiceInputFieldList extends StatefulWidget {
  final List<OwnerServiceInfo> initialServices;
  final ValueChanged<List<OwnerServiceInfo>>? onChanged;

  const ServiceInputFieldList({
    super.key,
    required this.initialServices,
    this.onChanged,
  });

  @override
  State<ServiceInputFieldList> createState() => _ServiceInputFieldListState();
}

class _ServiceInputFieldListState extends State<ServiceInputFieldList> {
  late List<_ServiceFieldData> _services;

  @override
  void initState() {
    super.initState();
    _services = widget.initialServices.isNotEmpty
        ? widget.initialServices
            .map((service) => _ServiceFieldData(
                  nameController: TextEditingController(text: service.name),
                  priceController:
                      TextEditingController(text: service.price.toString()),
                  durationController: TextEditingController(
                      text: service.durationMinutes.toString()),
                ))
            .toList()
        : [
            _ServiceFieldData(
              nameController: TextEditingController(),
              priceController: TextEditingController(),
              durationController: TextEditingController(),
            )
          ];
    for (final field in _services) {
      _attachListeners(field);
    }
    // Delay emission to avoid notifying listeners during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => _emitServices());
  }

  @override
  void dispose() {
    for (final field in _services) {
      field.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ..._services.asMap().entries.map((entry) {
          final index = entry.key;
          final field = entry.value;
          return _ServiceCard(
            nameController: field.nameController,
            priceController: field.priceController,
            durationController: field.durationController,
            onRemove: () => _removeService(index),
          );
        }),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: _addService,
            icon: const Icon(Icons.add),
            label: const Text('Add Service'),
          ),
        ),
      ],
    );
  }

  void _addService() {
    setState(() {
      final field = _ServiceFieldData(
        nameController: TextEditingController(),
        priceController: TextEditingController(),
        durationController: TextEditingController(),
      );
      _attachListeners(field);
      _services.add(field);
    });
    _emitServices();
  }

  void _removeService(int index) {
    setState(() {
      final field = _services.removeAt(index);
      field.dispose();
    });
    _emitServices();
  }

  void _attachListeners(_ServiceFieldData field) {
    field.nameController.addListener(_emitServices);
    field.priceController.addListener(_emitServices);
    field.durationController.addListener(_emitServices);
  }

  void _emitServices() {
    if (widget.onChanged == null) return;
    widget.onChanged!.call(_collectServices());
  }

  List<OwnerServiceInfo> _collectServices() {
    return _services
        .map((field) {
          final name = field.nameController.text.trim();
          if (name.isEmpty) return null;
          final price = int.tryParse(field.priceController.text.trim()) ?? 0;
          final duration =
              int.tryParse(field.durationController.text.trim()) ?? 0;
          return OwnerServiceInfo(
            name: name,
            price: price,
            durationMinutes: duration,
          );
        })
        .whereType<OwnerServiceInfo>()
        .toList();
  }
}

class _ServiceCard extends StatelessWidget {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController durationController;
  final VoidCallback onRemove;

  const _ServiceCard({
    required this.nameController,
    required this.priceController,
    required this.durationController,
    required this.onRemove,
  });

  InputDecoration get _fieldDecoration => const InputDecoration(
        filled: true,
        fillColor: Color(0xFFF3F4F6),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          borderSide: BorderSide.none,
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, 8))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: nameController,
                  decoration: _fieldDecoration.copyWith(
                      labelText: 'Service name',
                      prefixIcon: const Icon(Icons.content_cut)),
                ),
              ),
              IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline,
                      color: Colors.redAccent)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration.copyWith(
                      labelText: '৳ Price',
                      prefixIcon: const Icon(Icons.attach_money)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration.copyWith(
                      labelText: 'Duration (min)',
                      prefixIcon: const Icon(Icons.timer_outlined)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ServiceFieldData {
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController durationController;

  _ServiceFieldData({
    required this.nameController,
    required this.priceController,
    required this.durationController,
  });

  void dispose() {
    nameController.dispose();
    priceController.dispose();
    durationController.dispose();
  }
}
