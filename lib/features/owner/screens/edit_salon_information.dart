import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/edit_salon_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class EditSalonInfoScreen extends StatefulWidget {
  const EditSalonInfoScreen({super.key});

  @override
  State<EditSalonInfoScreen> createState() => _EditSalonInfoScreenState();
}

class _EditSalonInfoScreenState extends State<EditSalonInfoScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _salonNameController;
  late final TextEditingController _emailController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  late final TextEditingController _aboutController;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _salonNameController = TextEditingController();
    _emailController = TextEditingController();
    _phoneController = TextEditingController();
    _addressController = TextEditingController();
    _aboutController = TextEditingController();
  }

  @override
  void dispose() {
    _salonNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _aboutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (context) {
        final auth = context.read<AuthProvider>();
        final provider = EditSalonProvider(authProvider: auth);
        provider.load();
        return provider;
      },
      builder: (context, _) {
        final provider = context.watch<EditSalonProvider>();
        _initializeFromProvider(provider);
        return Scaffold(
          backgroundColor: const Color(0xFFF4F6FB),
          appBar: AppBar(
            title: const Text('Edit Salon Information'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    children: [
                      if (provider.error != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            provider.error!,
                            style: const TextStyle(color: Colors.red),
                          ),
                        ),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                              color: Colors.indigo.withValues(alpha: 0.08)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildField(
                              controller: _salonNameController,
                              label: 'Salon name',
                              icon: Icons.store_mall_directory_outlined,
                            ),
                            const SizedBox(height: 18),
                            _buildField(
                              controller: _phoneController,
                              label: 'Contact number',
                              icon: Icons.phone_outlined,
                              keyboardType: TextInputType.phone,
                            ),
                            const SizedBox(height: 18),
                            _buildField(
                              controller: _emailController,
                              label: 'Email address',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 18),
                            _buildField(
                              controller: _addressController,
                              label: 'Address',
                              icon: Icons.location_on_outlined,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 18),
                            _buildField(
                              controller: _aboutController,
                              label: 'About / description (optional)',
                              maxLines: 3,
                              isRequired: false,
                            ),
                            const SizedBox(height: 26),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: provider.isSaving
                                    ? null
                                    : () => _submit(provider),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF5B21B6),
                                  foregroundColor: Colors.white,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(22),
                                  ),
                                ),
                                child: provider.isSaving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Update info'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600, color: Colors.black87)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          validator: isRequired
              ? (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null
              : null,
          decoration: InputDecoration(
            prefixIcon: icon == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(left: 12, right: 8),
                    child: Icon(icon, color: const Color(0xFF5B21B6)),
                  ),
            prefixIconConstraints: icon == null
                ? null
                : const BoxConstraints(minWidth: 40, minHeight: 40),
            filled: true,
            fillColor: const Color(0xFFF9FAFB),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide: BorderSide(
                  color: const Color(0xFF5B21B6).withValues(alpha: 0.25)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
              borderSide:
                  const BorderSide(color: Color(0xFF5B21B6), width: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  void _initializeFromProvider(EditSalonProvider provider) {
    if (_initialized || provider.isLoading) return;
    _salonNameController.text = provider.salonName;
    _emailController.text = provider.email;
    _phoneController.text = provider.phone;
    _addressController.text = provider.address;
    _aboutController.text = provider.about;
    _initialized = true;
  }

  Future<void> _submit(EditSalonProvider provider) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await provider.save(
      salonName: _salonNameController.text.trim(),
      ownerName: provider.ownerName,
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      about: _aboutController.text.trim(),
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Salon info updated')),
      );
      Navigator.maybePop(context);
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
      );
    }
  }
}
