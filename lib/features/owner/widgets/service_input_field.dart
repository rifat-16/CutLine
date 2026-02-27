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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFEFF5FF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFD5E3FE)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.tips_and_updates_outlined,
                size: 18,
                color: Color(0xFF2F65D9),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Add 3-6 core services first. You can edit anytime later.',
                  style: TextStyle(
                    color: Color(0xFF30446B),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        ..._services.asMap().entries.map((entry) {
          final index = entry.key;
          final field = entry.value;
          return _ServiceCard(
            index: index + 1,
            nameController: field.nameController,
            priceController: field.priceController,
            durationController: field.durationController,
            canRemove: _services.length > 1,
            onRemove: () => _removeService(index),
          );
        }),
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _addService,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2F65D9),
              backgroundColor: const Color(0xFFF0F5FF),
              side: const BorderSide(color: Color(0xFFBDD0FB)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            icon: const Icon(Icons.add_rounded),
            label: const Text(
              'Add Another Service',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
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
    if (_services.length == 1) {
      setState(() {
        _services.first.nameController.clear();
        _services.first.priceController.clear();
        _services.first.durationController.clear();
      });
      _emitServices();
      return;
    }

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
  final int index;
  final TextEditingController nameController;
  final TextEditingController priceController;
  final TextEditingController durationController;
  final bool canRemove;
  final VoidCallback onRemove;

  const _ServiceCard({
    required this.index,
    required this.nameController,
    required this.priceController,
    required this.durationController,
    required this.canRemove,
    required this.onRemove,
  });

  InputDecoration _fieldDecoration({
    required String hintText,
    Widget? prefixIcon,
  }) {
    return InputDecoration(
      hintText: hintText,
      hintStyle: const TextStyle(
        color: Color(0xFF6D7486),
        fontWeight: FontWeight.w500,
      ),
      prefixIcon: prefixIcon,
      isDense: true,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD7DFEF)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFD7DFEF)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(
          color: Color(0xFF2F65D9),
          width: 1.5,
        ),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD9E4FD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8EFFE),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'Service $index',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF30446B),
                  ),
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: canRemove ? onRemove : null,
                style: IconButton.styleFrom(
                  backgroundColor: canRemove
                      ? const Color(0xFFFFEEF0)
                      : const Color(0xFFF2F3F7),
                  foregroundColor: canRemove
                      ? const Color(0xFFE34C5E)
                      : const Color(0xFFB6BBC8),
                ),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: nameController,
            decoration: _fieldDecoration(
              hintText: 'Service name',
              prefixIcon: const Icon(Icons.content_cut_rounded, size: 20),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: priceController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration(
                    hintText: 'Price (৳)',
                    prefixIcon: const Icon(Icons.payments_outlined, size: 20),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: durationController,
                  keyboardType: TextInputType.number,
                  decoration: _fieldDecoration(
                    hintText: 'Minutes',
                    prefixIcon: const Icon(Icons.timer_outlined, size: 20),
                  ),
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
