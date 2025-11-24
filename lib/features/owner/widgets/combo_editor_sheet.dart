import 'package:cutline/features/owner/utils/constants.dart';
import 'package:cutline/features/owner/widgets/sheet_action_button.dart';
import 'package:flutter/material.dart';

Future<OwnerComboInfo?> showOwnerComboEditorSheet({
  required BuildContext context,
  OwnerComboInfo? initial,
}) {
  final nameController = TextEditingController(text: initial?.name ?? '');
  final servicesController =
      TextEditingController(text: initial?.services ?? '');
  final highlightController =
      TextEditingController(text: initial?.highlight ?? '');
  final priceController =
      TextEditingController(text: initial?.price.toString() ?? '');
  final emojiController = TextEditingController(text: initial?.emoji ?? '✨');

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
              initial == null ? 'Add combo offer' : 'Edit combo offer',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
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
            SheetActionButton(
              label: initial == null ? 'Add combo' : 'Save changes',
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Please fill name, services, highlight and a valid price',
                      ),
                    ),
                  );
                  return;
                }
                Navigator.pop(
                  context,
                  initial?.copyWith(
                        name: nameController.text.trim(),
                        services: servicesController.text.trim(),
                        highlight: highlightController.text.trim(),
                        price: price,
                        emoji: _fallbackEmoji(emojiController.text.trim()),
                      ) ??
                      OwnerComboInfo(
                        name: nameController.text.trim(),
                        services: servicesController.text.trim(),
                        highlight: highlightController.text.trim(),
                        price: price,
                        emoji: _fallbackEmoji(emojiController.text.trim()),
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

String _fallbackEmoji(String input) {
  if (input.isEmpty) {
    return '✨';
  }
  final iterator = input.runes.iterator;
  if (iterator.moveNext()) {
    return String.fromCharCode(iterator.current);
  }
  return '✨';
}
