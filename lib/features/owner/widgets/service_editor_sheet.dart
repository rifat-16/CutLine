import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/sheet_action_button.dart';
import 'package:flutter/material.dart';

Future<OwnerServiceInfo?> showOwnerServiceEditorSheet({
  required BuildContext context,
  OwnerServiceInfo? initial,
}) {
  final nameController = TextEditingController(text: initial?.name ?? '');
  final priceController =
      TextEditingController(text: initial?.price.toString() ?? '');
  final durationController =
      TextEditingController(text: initial?.durationMinutes.toString() ?? '');

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
              initial == null ? 'Add new service' : 'Edit service',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
            SheetActionButton(
              label: initial == null ? 'Add service' : 'Save changes',
              gradient: const LinearGradient(
                colors: [Color(0xFFEEE9FF), Color(0xFFDCCBFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              textColor: const Color(0xFF5E34D2),
              onTap: () {
                final price = int.tryParse(priceController.text) ?? 0;
                final duration = int.tryParse(durationController.text) ?? 0;
                if (nameController.text.trim().isEmpty || price <= 0 || duration <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content:
                          Text('Please enter valid name, price and duration'),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  initial?.copyWith(
                        name: nameController.text.trim(),
                        price: price,
                        durationMinutes: duration,
                      ) ??
                      OwnerServiceInfo(
                        name: nameController.text.trim(),
                        price: price,
                        durationMinutes: duration,
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
