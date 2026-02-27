import 'package:cutline/features/auth/providers/auth_provider.dart';
import 'package:cutline/features/owner/providers/edit_salon_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class OwnerProfileEditScreen extends StatefulWidget {
  const OwnerProfileEditScreen({super.key});

  @override
  State<OwnerProfileEditScreen> createState() => _OwnerProfileEditScreenState();
}

class _OwnerProfileEditScreenState extends State<OwnerProfileEditScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  bool _initialized = false;
  bool _dirty = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _phoneController = TextEditingController();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
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
        if (!_initialized && !provider.isLoading) {
          _nameController.text = provider.ownerName;
          _phoneController.text = provider.phone;
          _emailController.text = provider.email;
          _initialized = true;
          _dirty = false;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Edit owner profile'),
            backgroundColor: Colors.white,
            elevation: 0,
          ),
          backgroundColor: const Color(0xFFF4F6FB),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      _buildField(
                        controller: _nameController,
                        label: 'Full name',
                        icon: Icons.person_outline,
                        isRequired: true,
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: _phoneController,
                        label: 'Phone number',
                        icon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 16),
                      _buildField(
                        controller: _emailController,
                        label: 'Email address',
                        icon: Icons.email_outlined,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: provider.isSaving || !_dirty
                              ? null
                              : () => _submit(provider),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
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
                              : const Text('Save changes'),
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
    required IconData icon,
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
          onChanged: (_) => setState(() => _dirty = true),
          validator: isRequired
              ? (value) =>
                  (value == null || value.trim().isEmpty) ? 'Required' : null
              : null,
          decoration: InputDecoration(
            prefixIcon: Padding(
              padding: const EdgeInsets.only(left: 12, right: 8),
              child: Icon(icon, color: const Color(0xFF2563EB)),
            ),
            prefixIconConstraints:
                const BoxConstraints(minWidth: 40, minHeight: 40),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide: BorderSide(
                  color: const Color(0xFF2563EB).withValues(alpha: 0.18)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(20),
              borderSide:
                  const BorderSide(color: Color(0xFF2563EB), width: 1.3),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _submit(EditSalonProvider provider) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final success = await provider.save(
      salonName: provider.salonName,
      ownerName: _nameController.text.trim(),
      email: _emailController.text.trim(),
      phone: _phoneController.text.trim(),
      address: provider.address,
      mapAddress: provider.mapAddress,
      about: provider.about,
    );
    if (!mounted) return;
    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
      Navigator.maybePop(context);
    } else if (provider.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.error!), backgroundColor: Colors.red),
      );
    }
  }
}
